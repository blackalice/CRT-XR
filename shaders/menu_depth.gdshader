shader_type canvas_item;
render_mode unshaded;
// Gives the flat menu image depth in side-by-side 3D. Each eye shifts layers
// horizontally in opposite directions: the whole menu floats in front of the
// TV, the page eases forward after a tab change, and the selected row lifts
// a little. The lifted row's original place
// is filled with the backdrop just above it, so no copy of it shows beside
// the lifted one. In mono the shifts are zero; a soft shadow and a slight scale-up carry
// the lift instead. All sizes are menu texture pixels; rectangles are x, y,
// width, height (width 0 = none).
uniform sampler2D menu_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(960.0, 720.0);
uniform float base_shift = 0.0;
uniform float scale = 1.0;
uniform float fade = 1.0;
// Curved menu: the side edges sit closer than the centre, like a curved
// monitor. curve_shift is the extra eye shift at the edges; curve_height how
// much taller the edges look for being closer (both fall to 0 at the centre).
uniform float curve_shift = 0.0;
uniform float curve_height = 0.0;
uniform vec4 page_rect = vec4(0.0);
uniform float page_shift = 0.0;
uniform vec4 lift_rect = vec4(0.0);
uniform float lift_shift = 0.0;
uniform float lift_scale = 1.0;
uniform float shadow = 0.0;

bool inside(vec2 p, vec4 r) {
	return r.z > 0.0 && p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w;
}

vec4 sample_menu(vec2 p) {
	vec2 uv = p / tex_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
	return texture(menu_tex, uv);
}

// Undoes the lifted row's scale-up (mono emphasis) about its centre.
vec2 unscale_lift(vec2 p) {
	vec2 centre = lift_rect.xy + lift_rect.zw * 0.5;
	return centre + (p - centre) / lift_scale;
}

void fragment() {
	vec2 p = UV * tex_size;
	p = (p - tex_size * 0.5) / scale + tex_size * 0.5;
	float bend = pow(p.x / tex_size.x * 2.0 - 1.0, 2.0);
	p.y = tex_size.y * 0.5 + (p.y - tex_size.y * 0.5) / (1.0 + curve_height * bend);
	p.x -= base_shift + curve_shift * bend;
	vec4 colour;
	// Topmost layer first: lifted row, page, panel.
	vec2 lift_source = unscale_lift(vec2(p.x - page_shift - lift_shift, p.y));
	vec2 page_source = vec2(p.x - page_shift, p.y);
	if (inside(lift_source, lift_rect)) {
		colour = sample_menu(lift_source);
	} else if (inside(page_source, page_rect)) {
		// Where the row was before it lifted, show what it sits on: the gap
		// just above it holds the panel colour (or the Now playing panel's).
		colour = inside(page_source, lift_rect) ? sample_menu(vec2(lift_rect.x + lift_rect.z * 0.5, lift_rect.y - 3.0)) : sample_menu(page_source);
		// Mono only: a soft shadow under the lifted row.
		if (shadow > 0.0 && lift_rect.z > 0.0) {
			vec2 shadow_source = unscale_lift(vec2(page_source.x - 2.0, p.y - 4.0));
			vec2 centre = lift_rect.xy + lift_rect.zw * 0.5;
			vec2 d = abs(shadow_source - centre) - lift_rect.zw * 0.5;
			float outside = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
			colour.rgb *= 1.0 - shadow * 0.25 * (1.0 - smoothstep(-2.0, 8.0, outside));
		}
	} else {
		colour = sample_menu(p);
	}
	COLOR = vec4(colour.rgb, colour.a * fade);
}
