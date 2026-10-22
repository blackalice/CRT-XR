shader_type spatial;
// Unbranded game boxes with original abstract cover art: no titles or logos.
// Vertex colour: r = art seed, g = kind (0 cardboard carton, 1 plastic clamshell).
// Colours are muted so the stack sits back in the dim room.
// Flat: the art hash amplifies even the tiny error of interpolating a constant,
// which otherwise flips palette colours from pixel to pixel.
varying flat float face;
varying flat float seed;
varying flat float kind;

float hash(float n) { return fract(sin(n * 91.345) * 47453.5453); }
// Antialiasing width per axis: a face seen at a shallow angle is far more
// compressed in one direction, and a shared width would smear it into bars.
float rect(vec2 uv, vec4 bounds, vec2 aa) {
	vec2 inside = smoothstep(bounds.xy - aa, bounds.xy + aa, uv) * (1.0 - smoothstep(bounds.zw - aa, bounds.zw + aa, uv));
	return inside.x * inside.y;
}
vec3 palette(float n) {
	vec3 colours[6] = vec3[](vec3(0.75, 0.22, 0.18), vec3(0.18, 0.42, 0.70), vec3(0.85, 0.62, 0.18), vec3(0.22, 0.55, 0.35), vec3(0.50, 0.25, 0.62), vec3(0.15, 0.60, 0.65));
	return colours[int(hash(n) * 5.99)];
}

vec3 cover_art(vec2 uv, vec2 aa) {
	vec3 primary = palette(seed * 7.0);
	vec3 secondary = palette(seed * 13.0 + 1.0);
	// Broad shapes only, which survive the shallow view of a box lying flat:
	// a sky-to-ground gradient, a large sun or planet disc and one diagonal band.
	vec3 art = mix(secondary * 0.5, primary, uv.y);
	vec2 centre = vec2(0.3 + hash(seed * 3.0) * 0.4, 0.55);
	float disc = 1.0 - smoothstep(0.24 - aa.y, 0.24 + aa.y, length((uv - centre) * vec2(1.0, 0.75)));
	art = mix(art, mix(primary, vec3(0.95, 0.85, 0.6), 0.5), disc * 0.8);
	float diagonal = uv.x * 0.6 + uv.y - 0.95 - hash(seed * 5.0) * 0.2;
	float band_aa = aa.x * 0.6 + aa.y;
	float band = smoothstep(-band_aa, band_aa, diagonal) * (1.0 - smoothstep(0.12 - band_aa, 0.12 + band_aa, diagonal));
	art = mix(art, secondary, band * 0.7);
	// A blocky title area near the top edge: shapes that read as lettering.
	float title = 0.0;
	for (int i = 0; i < 6; i++) {
		float x = 0.12 + float(i) * 0.12;
		float h = 0.08 + hash(seed * 17.0 + float(i)) * 0.06;
		title = max(title, rect(uv, vec4(x, 0.08, x + 0.09, 0.08 + h), aa));
	}
	// Small lettering blocks give way to a plain strip once they are sub-pixel.
	float legible = 1.0 - smoothstep(0.03, 0.08, aa.y);
	art = mix(art, vec3(0.92, 0.9, 0.82), mix(rect(uv, vec4(0.12, 0.08, 0.81, 0.17), aa) * 0.5, title, legible) * 0.85);
	return art;
}

void vertex() {
	face = UV2.x;
	seed = COLOR.r;
	kind = COLOR.g;
}

void fragment() {
	vec2 aa = fwidth(UV) * 0.75;
	vec3 albedo;
	float roughness;
	if (kind > 0.5) {
		// Clamshell: black plastic; the printed insert shows through the clear top.
		albedo = vec3(0.018);
		roughness = 0.35;
		if (face > 3.5 && face < 4.5) {
			float insert = rect(UV, vec4(0.06, 0.04, 0.94, 0.96), aa);
			albedo = mix(albedo, cover_art((UV - vec2(0.06, 0.04)) / vec2(0.88, 0.92), aa), insert);
			roughness = 0.22;
		}
	} else {
		// Cardboard carton: printed art with the period grey band along one edge.
		vec3 spine = palette(seed * 7.0) * 0.6;
		albedo = spine;
		roughness = 0.75;
		if (face > 3.5 && face < 4.5) {
			albedo = cover_art(UV, aa);
			float band = rect(UV, vec4(-0.1, 0.86, 1.1, 1.1), aa);
			albedo = mix(albedo, vec3(0.42, 0.42, 0.44), band);
			albedo = mix(albedo, palette(seed * 13.0 + 1.0), rect(UV, vec4(-0.1, 0.9, 1.1, 0.93), aa));
		}
	}
	// Muted print: keep the stack from pulling focus from the screen.
	float luminance = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(albedo, vec3(luminance), 0.3) * 0.75;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
}
