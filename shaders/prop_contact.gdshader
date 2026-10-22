shader_type spatial;
// Soft contact darkening under props: multiplies the surface below, standing in
// for the baked contact AO that the table and TV use. Vertex colour rg is the
// prop footprint as a fraction of the quad.
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.5;
varying vec2 core;

void vertex() { core = COLOR.rg; }

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	// Distance outside the footprint, normalised to the quad's margin.
	vec2 outside = max(p - core, vec2(0.0)) / max(vec2(1.0) - core, vec2(0.001));
	float shade = smoothstep(0.0, 1.0, length(outside));
	ALBEDO = vec3(mix(1.0 - strength, 1.0, shade));
}
