shader_type canvas_item;
render_mode unshaded;
// Applied to each eye's SubViewportContainer: the fade multiplies the eye image
// in the copy that already happens, instead of a separate full-screen blend.
uniform float fade_width : hint_range(0.0, 0.2) = 0.075;
void fragment() {
	if (fade_width > 0.0001) {
		vec2 edge = min(UV, vec2(1.0) - UV);
		vec2 falloff = smoothstep(vec2(0.0), vec2(fade_width), edge);
		COLOR.rgb *= falloff.x * falloff.y;
	}
}
