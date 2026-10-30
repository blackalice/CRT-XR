shader_type canvas_item;
render_mode unshaded;
// The menu's backdrop, drawn the way a 90s console BIOS drew its own: on a
// 2×2-pixel grid (480×360 across the 960×720 menu), in 15-bit colour with
// ordered dithering. A dark sky, the lit limb of a planet in the lower right,
// a small moon and stars that drift a pixel at a time. Black stays black, so
// glasses see through it.
uniform vec2 panel_size = vec2(888.0, 664.0);
uniform vec2 moon_at = vec2(0.47, 0.075);
// 0 holds the stars still (Reduce animation).
uniform float motion = 1.0;
uniform vec4 frame_colour : source_color = vec4(0.22, 0.35, 0.63, 1.0);

const float CELL = 2.0;
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float threshold(vec2 cell) {
	int i = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	return (BAYER[i] + 0.5) / 16.0;
}

// 15-bit colour: five bits a channel.
vec3 q5(vec3 c) { return floor(c * 31.0 + 0.5) / 31.0; }

// Picks a step of a ramp, dithering between neighbours by the Bayer matrix.
float step_of(float f, float steps, vec2 cell) {
	f = clamp(f, 0.0, steps - 1.0);
	float base = floor(f);
	return min(base + (f - base > threshold(cell) ? 1.0 : 0.0), steps - 1.0);
}

vec3 sky(float i) {
	if (i < 0.5) return vec3(0.0, 0.0, 0.016);
	if (i < 1.5) return vec3(0.0, 0.016, 0.063);
	if (i < 2.5) return vec3(0.0, 0.031, 0.094);
	return vec3(0.016, 0.063, 0.173);
}

vec3 sea(float i) {
	if (i < 0.5) return vec3(0.0, 0.031, 0.094);
	if (i < 1.5) return vec3(0.024, 0.094, 0.282);
	if (i < 2.5) return vec3(0.047, 0.220, 0.565);
	if (i < 3.5) return vec3(0.125, 0.408, 0.784);
	if (i < 4.5) return vec3(0.345, 0.659, 0.910);
	if (i < 5.5) return vec3(0.784, 0.878, 0.973);
	return vec3(0.941, 0.973, 0.973);
}

vec3 grey(float i) {
	if (i < 0.5) return vec3(0.063, 0.078, 0.125);
	if (i < 1.5) return vec3(0.220, 0.243, 0.314);
	if (i < 2.5) return vec3(0.439, 0.471, 0.541);
	if (i < 3.5) return vec3(0.690, 0.714, 0.769);
	return vec3(0.878, 0.894, 0.925);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p), s = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

float clouds(vec2 p) { return 0.55 * noise(p) + 0.3 * noise(p * 2.1) + 0.15 * noise(p * 4.3); }

void fragment() {
	vec2 grid = floor(panel_size / CELL);
	vec2 cell = floor(UV * panel_size / CELL);
	// A one-cell frame all round. (A dark bevel edge vanished against the black.)
	if (cell.x < 1.0 || cell.y < 1.0 || cell.x >= grid.x - 1.0 || cell.y >= grid.y - 1.0) { COLOR = frame_colour; }
	else {
		vec2 at = (cell + 0.5) / grid;
		vec2 d = vec2((at.x - 0.42) * 1.3, at.y - 0.3);
		vec3 colour = sky(step_of((1.0 - length(d) * 1.5) * 3.0, 4.0, cell));
		bool hidden = false;
		// The planet: a great disc whose upper-left limb catches the light.
		vec2 centre = vec2(grid.x * 0.9, grid.y * 1.36);
		float radius = grid.y * 0.74;
		vec2 p = (cell - centre) / radius;
		float r2 = dot(p, p);
		float lit_side = -0.55 * p.x - 0.75 * p.y;
		if (r2 < 1.0) {
			hidden = true;
			float z = sqrt(1.0 - r2);
			float light = max(0.0, lit_side + 0.37 * z) * 0.62;
			float f = light * 4.2;
			float n = clouds(vec2(p.x / (z + 0.5) * 4.0 + 7.0, p.y / (z + 0.5) * 6.0 + 3.0));
			if (n > 0.56 && light > 0.04) f += (n - 0.56) * 18.0 * min(1.0, light * 3.0);
			colour = (r2 > 0.985 && light > 0.12) ? vec3(0.282, 0.565, 0.753) : sea(step_of(f, 7.0, cell));
		} else if (r2 < 1.05 && lit_side > 0.1 && threshold(cell) < (1.05 - r2) * 14.0) {
			hidden = true;
			colour = vec3(0.031, 0.110, 0.282);
		}
		// The moon, lit from the right, with a few craters.
		float moon_r = 11.0;
		vec2 m = (cell - moon_at * grid) / moon_r;
		float m2 = dot(m, m);
		if (m2 < 1.0) {
			hidden = true;
			float mz = sqrt(1.0 - m2);
			float f = (0.62 * m.x - 0.25 * m.y + 0.74 * mz) * 4.2 * 0.8;
			if (length(m - vec2(-0.3, -0.2)) < 0.25 || length(m - vec2(0.35, 0.3)) < 0.2 ||
				length(m - vec2(0.1, -0.5)) < 0.15 || length(m - vec2(-0.25, 0.45)) < 0.18) f -= 0.9;
			colour = grey(step_of(f, 5.0, cell));
		} else if (m2 < 1.3) { hidden = true; }
		// Two layers of stars, drifting left a whole cell at a time; a few twinkle.
		if (!hidden) {
			for (int layer = 0; layer < 2; layer++) {
				float speed = layer == 0 ? 2.0 : 5.0;
				vec2 star = vec2(mod(cell.x + floor(TIME * motion * speed), grid.x), cell.y);
				float h = hash(star + float(layer) * 97.0);
				if (h > (layer == 0 ? 0.9975 : 0.9988)) {
					float twinkle = step(0.5, fract(TIME * motion * 0.7 + h * 13.0));
					colour = layer == 0 ? vec3(0.157, 0.220, 0.408) : mix(vec3(0.408, 0.471, 0.690), vec3(0.941, 0.941, 0.973), twinkle);
				}
			}
		}
		COLOR = vec4(q5(colour), 1.0);
	}
}
