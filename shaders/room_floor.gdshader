shader_type spatial;

uniform float fade_begin = 4.5;
uniform float fade_end = 11.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 nearest_line = abs(fract(p + 0.5) - 0.5);
	vec2 line_width = max(fwidth(p), vec2(0.001));
	vec2 lines = vec2(1.0) - smoothstep(vec2(0.003), vec2(0.003) + line_width, nearest_line);
	float grid = max(lines.x, lines.y);
	float visibility = 1.0 - smoothstep(fade_begin, fade_end, distance(CAMERA_POSITION_WORLD, world_position));
	ALBEDO = mix(vec3(0.055, 0.062, 0.075), vec3(0.10, 0.115, 0.135), grid) * visibility;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
