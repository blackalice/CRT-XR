shader_type spatial;
// The soft bloom a bright tube leaves around itself in a dark room: light in
// the eye, not on the casing. A flat quad over the casing's face, clear over
// the picture and fading out across the bezel, in the picture's colours (left
// and right halves, like the screen light). It stops inside the casing's own
// outline, so it never haloes the black room beyond. Additive, so it only adds.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// In the quad's own metres, from its centre (the picture's centre): half the
// picture's size, how far the halo fades over, and the casing's face.
uniform vec2 screen_half = vec2(0.66, 0.495);
uniform float reach = 0.12;
uniform float corner = 0.06;
uniform vec2 quad_half = vec2(0.85, 0.63);
uniform vec2 casing_centre = vec2(0.0);
uniform vec2 casing_half = vec2(0.85, 0.63);
uniform float casing_corner = 0.06;
uniform vec3 left_colour = vec3(0.0);
uniform vec3 right_colour = vec3(0.0);
uniform float strength = 0.0;
varying vec3 surface_world;
varying vec3 normal_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_half;
	p.y = -p.y;
	// Distance outside the screen's rounded rectangle; zero over the picture.
	vec2 q = abs(p) - screen_half + vec2(corner);
	float outside = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float d = max(outside, 0.0) / reach;
	// A bright inner rim and a short tail, gone well before the casing's edge
	// so the bloom never shows an outline where it stops.
	float glow = (exp(-d * 4.0) * 0.7 + exp(-d * 2.5) * 0.3) * (1.0 - smoothstep(0.5, 1.0, d));
	// Ends a little inside the casing's edge.
	vec2 c = abs(p - casing_centre) - casing_half + vec2(casing_corner);
	float inside_casing = -(length(max(c, vec2(0.0))) + min(max(c.x, c.y), 0.0) - casing_corner);
	glow *= smoothstep(0.0, 0.05, inside_casing);
	// Ease in over the tube's own edge so there is no seam with the picture.
	glow *= smoothstep(-0.02, 0.01, outside);
	// Seen from the side it would read as paint on the bezel; fade it out.
	vec3 view = normalize(CAMERA_POSITION_WORLD - surface_world);
	glow *= smoothstep(0.2, 0.7, abs(dot(view, normalize(normal_world))));
	vec3 colour = mix(left_colour, right_colour, smoothstep(-screen_half.x, screen_half.x, p.x));
	ALBEDO = colour * glow * strength;
}
