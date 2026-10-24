shader_type spatial;
// The soft bloom a bright tube leaves around itself in a dark room: light in
// the eye, not on the casing. A flat quad just in front of the faceplate, clear
// over the picture and fading out across the bezel, in the picture's colours
// (left and right halves, like the screen light). Additive, so it only adds.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Half the picture's size and the halo's reach, in the quad's own metres.
uniform vec2 screen_half = vec2(0.66, 0.495);
uniform float reach = 0.16;
uniform float corner = 0.06;
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
	vec2 half_size = screen_half + vec2(reach);
	vec2 p = (UV - 0.5) * 2.0 * half_size;
	p.y = -p.y;
	// Distance outside the screen's rounded rectangle; zero over the picture.
	vec2 q = abs(p) - screen_half + vec2(corner);
	float outside = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float d = max(outside, 0.0) / reach;
	// A bright inner rim and a long soft tail, ending at the quad's edge.
	float glow = (exp(-d * 5.0) * 0.6 + exp(-d * 1.8) * 0.4) * (1.0 - smoothstep(0.75, 1.0, d));
	// Ease in over the tube's own edge so there is no seam with the picture.
	glow *= smoothstep(-0.02, 0.01, outside);
	// Seen from the side it would read as paint on the bezel; fade it out.
	vec3 view = normalize(CAMERA_POSITION_WORLD - surface_world);
	glow *= smoothstep(0.2, 0.7, abs(dot(view, normalize(normal_world))));
	vec3 colour = mix(left_colour, right_colour, smoothstep(-screen_half.x, screen_half.x, p.x));
	ALBEDO = colour * glow * strength;
}
