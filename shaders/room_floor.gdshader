shader_type spatial;
// Floor styles, chosen in Room settings. At 2-3 m a carpet's pile is far below
// a pixel, so each style adds what reads at that distance: pattern, patches or
// board structure. The branch follows a uniform, and each style reads only the
// textures it needs (floorboards read none).
const int CONFETTI = 0;
const int WOOL = 1;
const int FLOORBOARDS = 2;
uniform int style = 0; // CONFETTI
uniform float fade_begin = 4.5;
uniform float fade_end = 9.0;
uniform float brightness = 1.15;
uniform sampler2D carpet_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carpet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carpet_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D contact_ao : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 contact_rect = vec4(-3.0,-2.5,6.0,5.0);
uniform bool contact_enabled = false;
varying vec3 world_position;
varying vec2 floor_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return value_noise(p) * 0.6 + value_noise(p * 2.13 + 7.1) * 0.3 + value_noise(p * 4.7 + 3.3) * 0.1;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	floor_position = VERTEX.xz;
}

void fragment() {
	// A half-metre tile keeps the short pile believable; mipmaps suppress shimmer.
	vec2 carpet_uv = floor_position / 0.5;
	float footprint = max(length(dFdx(carpet_uv)), length(dFdy(carpet_uv)));
	float near = 1.0 - smoothstep(0.012, 0.06, footprint);
	vec3 colour;
	float roughness = 1.0;
	float specular = 0.12;
	if (style == WOOL) {
		// Keep the photo's own variation, then add what reads at metres:
		// pile-direction patches, mottled dye and a worn path in front of the table.
		float tone = dot(texture(carpet_colour, carpet_uv).rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.14;
		float patches = fbm(floor_position * 1.4);
		float mottling = fbm(floor_position * 5.0 + 11.0);
		float wear = exp(-pow((floor_position.y - 1.05) / 0.45, 2.0)) * (1.0 - smoothstep(0.3, 1.2, abs(floor_position.x)));
		colour = vec3(0.34, 0.30, 0.25) * mix(0.85, 1.15, clamp(tone, 0.0, 2.0) * 0.5);
		colour *= mix(0.80, 1.18, patches) * mix(0.93, 1.06, mottling);
		colour = mix(colour, colour * vec3(1.10, 1.07, 1.02), wear * 0.6);
		roughness = mix(0.86, 1.0, texture(carpet_roughness, carpet_uv).r);
		NORMAL_MAP = texture(carpet_normal, carpet_uv).rgb;
		// Pile normals soften with distance but never vanish entirely.
		NORMAL_MAP_DEPTH = mix(0.18, 0.35, near);
	} else if (style == FLOORBOARDS) {
		// 14 cm boards, staggered joints, per-board tone and stretched grain.
		vec2 board = vec2(floor_position.x / 1.2, floor_position.y / 0.14);
		float row = floor(board.y);
		board.x += hash(vec2(row, 2.0)) * 3.0;
		vec2 id = vec2(floor(board.x), row);
		vec2 f = fract(board);
		float seam = smoothstep(0.0, 0.035, f.y) * smoothstep(1.0, 0.965, f.y);
		seam *= smoothstep(0.0, 0.006, f.x) * smoothstep(1.0, 0.994, f.x);
		float grain = fbm(vec2(floor_position.x * 3.0, (floor_position.y + row) * 60.0) + id * 13.0);
		colour = mix(vec3(0.30, 0.17, 0.09), vec3(0.42, 0.26, 0.14), hash(id));
		colour *= mix(0.82, 1.12, grain) * mix(0.45, 1.0, seam);
		roughness = mix(0.45, 0.70, grain);
		specular = 0.35;
	} else {
		// 90s confetti carpet: dark navy pile with scattered coloured squiggles and dots.
		vec2 cell = floor_position * 9.0;
		vec2 id = floor(cell);
		vec2 f = fract(cell) - 0.5;
		float pick = hash(id);
		vec2 offset = (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.5;
		float angle = hash(id + 1.3) * 6.2832;
		vec2 q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * (f - offset);
		float squiggle = (1.0 - smoothstep(0.035, 0.06, abs(q.y - 0.09 * sin(q.x * 14.0)))) * (1.0 - smoothstep(0.18, 0.22, abs(q.x)));
		float spot = 1.0 - smoothstep(0.05, 0.08, length(f - offset));
		float mark = pick < 0.45 ? squiggle : (pick < 0.75 ? spot : 0.0);
		vec3 palette[4] = vec3[](vec3(0.85, 0.25, 0.55), vec3(0.15, 0.75, 0.80), vec3(0.95, 0.75, 0.20), vec3(0.45, 0.30, 0.85));
		vec3 ink = palette[int(hash(id + 5.0) * 3.99)];
		// Marks blend into the base once they shrink below a pixel: no shimmer at distance.
		float resolve = 1.0 - smoothstep(0.08, 0.25, max(length(dFdx(cell)), length(dFdy(cell))));
		vec3 pile = vec3(0.045, 0.05, 0.085) * (0.9 + texture(carpet_colour, carpet_uv).b);
		colour = mix(pile, ink * 0.55, mark * mix(0.35, 1.0, resolve));
		colour *= mix(0.9, 1.1, fbm(floor_position * 1.5));
	}
	float patch = 1.0 - smoothstep(0.48, 0.98, length((UV - 0.5) * 2.0));
	float visibility = 1.0 - smoothstep(fade_begin, fade_end, distance(CAMERA_POSITION_WORLD, world_position));
	ALBEDO = colour * visibility * patch * brightness;
	ROUGHNESS = roughness;
	SPECULAR = specular * visibility * patch;
	float contact = texture(contact_ao, (floor_position - contact_rect.xy) / contact_rect.zw).r;
	// Native AO does not affect Compatibility direct lights.
	ALBEDO *= contact_enabled ? mix(1.0, contact, 0.9) : 1.0;
	AO = 1.0;
}
