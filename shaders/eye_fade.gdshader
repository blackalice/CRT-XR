shader_type canvas_item;
render_mode unshaded;
uniform float fade_width : hint_range(0.0, 0.2) = 0.075;
void fragment() {
	float visibility = 1.0;
	if (fade_width > 0.0001) {
		vec2 edge = min(UV, vec2(1.0) - UV);
		vec2 falloff = smoothstep(vec2(0.0), vec2(fade_width), edge);
		visibility = falloff.x * falloff.y;
	}
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - visibility);
}
