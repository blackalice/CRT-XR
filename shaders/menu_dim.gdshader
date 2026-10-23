shader_type canvas_item;
render_mode unshaded;
// Steps the room back behind an open menu: an even dim plus a soft vignette.
uniform float strength = 0.0;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.25);
	float vignette = smoothstep(0.2, 0.75, length(d));
	COLOR = vec4(0.0, 0.0, 0.0, strength * (0.3 + 0.4 * vignette));
}
