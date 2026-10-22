shader_type spatial;
// Lower shelf board: the table's average wood tone with long grain, darkened
// because it sits in the tabletop's shade (it has no baked contact AO).
uniform vec3 wood : source_color = vec3(0.30, 0.16, 0.09);
uniform float shade = 0.7;
varying vec3 local_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() { local_position = VERTEX; }

void fragment() {
	// Grain runs along the board (x); stretched noise reads as long fibres.
	vec2 grain_uv = vec2(local_position.x * 2.0, local_position.z * 40.0 + local_position.y * 40.0);
	float grain = value_noise(grain_uv) * 0.7 + value_noise(grain_uv * 3.1 + 5.0) * 0.3;
	ALBEDO = wood * mix(0.8, 1.12, grain) * shade;
	ROUGHNESS = mix(0.55, 0.75, grain);
	SPECULAR = 0.3;
}
