shader_type spatial;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float phase = local_position.z * 170.0 + sin(local_position.x * 6.0) * 2.0 + local_position.y * 35.0;
	float resolved = 1.0 - smoothstep(0.7, 2.5, fwidth(phase));
	float grain = sin(phase) * resolved;
	float broad = sin(local_position.z * 18.0 + sin(local_position.x * 3.0));
	ALBEDO = vec3(0.40, 0.265, 0.15) * (1.0 + grain * 0.035 + broad * 0.045);
	ROUGHNESS = 0.68;
	SPECULAR = 0.25;
}
