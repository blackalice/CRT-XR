shader_type spatial;
uniform float fade_begin = 4.5;
uniform float fade_end = 9.0;
uniform float brightness = 1.15;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = max(p.x, p.y);
	float hem = smoothstep(0.83, 0.85, edge) * (1.0 - smoothstep(0.94, 0.96, edge));
	float band = floor(UV.y * 11.0);
	vec3 color = mix(vec3(0.18, 0.29, 0.30), vec3(0.40, 0.20, 0.16), mod(band, 3.0) / 2.0);
	color = mix(color, vec3(0.63, 0.48, 0.30), hem);
	vec2 fibres = UV * vec2(650.0, 450.0);
	float detail = sin(fibres.x * 6.283) * sin(fibres.y * 6.283);
	float resolved = 1.0 - smoothstep(0.2, 0.8, max(fwidth(fibres.x), fwidth(fibres.y)));
	float visibility = 1.0 - smoothstep(fade_begin, fade_end, distance(CAMERA_POSITION_WORLD, world_position));
	ALBEDO = color * (1.0 + detail * resolved * 0.045) * brightness * visibility;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
