shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float reflection_strength : hint_range(0.0, 0.4) = 0.12;
varying vec3 surface_world;
varying vec3 normal_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 view = normalize(CAMERA_POSITION_WORLD - surface_world);
	vec3 normal = normalize(normal_world);
	vec3 reflected = reflect(-view, normal);
	// Procedural room-light reflections fixed in world directions, shared by both eyes.
	float panel = (1.0 - smoothstep(0.15, 0.23, abs(reflected.x + 0.42)))
		* (1.0 - smoothstep(0.20, 0.30, abs(reflected.y - 0.38)))
		* smoothstep(0.2, 0.7, reflected.z);
	// Window mullions remove reflected light, never darken the game underneath.
	// Soft, pixel-filtered gaps remain stable as the head moves or the TV shrinks.
	vec2 window_offset = reflected.xy - vec2(-0.42, 0.38);
	vec2 gap_softness = max(fwidth(window_offset), vec2(0.006));
	vec2 panes = smoothstep(vec2(0.009), vec2(0.009) + gap_softness * 2.0, abs(window_offset));
	panel *= panes.x * panes.y;
	float ceiling = pow(max(dot(reflected, normalize(vec3(0.3, 0.8, 0.5))), 0.0), 32.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(view, normal), 0.0), 5.0);
	float rim = smoothstep(0.87, 1.0, max(abs(UV.x * 2.0 - 1.0), abs(UV.y * 2.0 - 1.0)));
	ALBEDO = vec3(0.73, 0.84, 1.0);
	ALPHA = reflection_strength * (panel * 0.48 + ceiling * 0.15 + fresnel * (0.12 + rim * 0.5));
}
