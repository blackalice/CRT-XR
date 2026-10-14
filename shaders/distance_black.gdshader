shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;

uniform float fade_begin = 4.5;
uniform float fade_end = 11.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(fade_begin, fade_end, distance(CAMERA_POSITION_WORLD, world_position));
}
