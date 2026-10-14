shader_type spatial;

uniform float fade_begin = 4.5;
uniform float fade_end = 9.0;
uniform float brightness = 1.15;
varying vec3 world_position;
varying vec2 patch_uv;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	patch_uv = UV;
}

void fragment() {
	vec2 fibres = world_position.xz * 260.0;
	float detail = sin(fibres.x) * sin(fibres.y * 1.13);
	float resolved = 1.0 - smoothstep(0.2, 0.8, max(fwidth(fibres.x), fwidth(fibres.y)));
	float mottling = sin(world_position.x * 7.0 + world_position.z * 3.0) * 0.025;
	float patch = 1.0 - smoothstep(0.48, 0.98, length((patch_uv - 0.5) * 2.0));
	float visibility = 1.0 - smoothstep(fade_begin, fade_end, distance(CAMERA_POSITION_WORLD, world_position));
	ALBEDO = vec3(0.22, 0.265, 0.245) * (1.0 + detail * resolved * 0.05 + mottling) * visibility * patch * brightness;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
