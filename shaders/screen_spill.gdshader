shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

// A short-range approximation of light from the faceplate onto its bezel.
// Only a whole-picture mean reaches this material, never the picture itself.
uniform sampler2D average_texture : source_color, filter_nearest, repeat_disable;
uniform mat4 world_to_tv;
uniform vec2 screen_half_size = vec2(0.66, 0.495);
uniform float strength : hint_range(0.0, 0.4) = 0.10;
varying vec3 tv_position;
varying vec3 tv_normal;

void vertex() {
	tv_position = (world_to_tv * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tv_normal = mat3(world_to_tv) * MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 p = tv_position - vec3(-0.07, 0.035, 0.06);
	vec2 nearest = clamp(p.xy, -screen_half_size, screen_half_size);
	vec3 to_screen = vec3(nearest, 0.10) - p;
	float falloff = 1.0 - smoothstep(0.02, 0.32, length(to_screen));
	float facing = max(dot(normalize(tv_normal), normalize(to_screen + vec3(0.0, 0.0, 0.0001))), 0.0);
	float front = smoothstep(-0.12, 0.0, p.z);
	vec3 color = texture(average_texture, vec2(0.5)).rgb;
	if (OUTPUT_IS_SRGB) color = pow(max(color, vec3(0.0)), vec3(2.2));
	vec3 spill = color * strength * 0.12 * falloff * falloff * facing * front;
	ALBEDO = OUTPUT_IS_SRGB ? pow(spill, vec3(1.0 / 2.2)) : spill;
	ALPHA = 1.0;
}
