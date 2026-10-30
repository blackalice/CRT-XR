shader_type canvas_item;
render_mode unshaded;
// A menu panel in the 16-bit style: a dithered top-to-bottom fill in 15-bit
// colour and a one-cell bevel, on the same 2×2-pixel grid as the backdrop.
// `recessed` swaps the bevel for an inset (wells, LCD windows). `marquee`
// replaces the bevel with a border whose colours run round the panel: the
// selection cursor. Its size comes from the UV's screen-space rate, so one
// material serves panels of any size.
uniform vec4 top_colour : source_color = vec4(0.063, 0.157, 0.376, 1.0);
uniform vec4 bottom_colour : source_color = vec4(0.031, 0.078, 0.251, 1.0);
uniform vec4 hi_colour : source_color = vec4(0.220, 0.345, 0.627, 1.0);
uniform vec4 lo_colour : source_color = vec4(0.0, 0.016, 0.094, 1.0);
uniform bool recessed = false;
uniform bool marquee = false;
// Marquee steps per second; 0 holds it still (Reduce animation).
uniform float marquee_speed = 8.0;
uniform vec4 cycle_a : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cycle_b : source_color = vec4(0.659, 0.816, 0.973, 1.0);
uniform vec4 cycle_c : source_color = vec4(0.220, 0.408, 0.816, 1.0);

const float CELL = 2.0;
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float threshold(vec2 cell) {
	int i = int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0));
	return (BAYER[i] + 0.5) / 16.0;
}

vec3 q5(vec3 c) { return floor(c * 31.0 + 0.5) / 31.0; }

void fragment() {
	vec2 size = floor(1.0 / fwidth(UV) + 0.5);
	vec2 grid = max(floor(size / CELL), vec2(1.0));
	vec2 cell = min(floor(UV * size / CELL), grid - 1.0);
	// Dither against the screen, so neighbouring panels share one pattern.
	vec2 screen_cell = floor(FRAGCOORD.xy / CELL);
	bool edge_top = cell.y < 1.0, edge_left = cell.x < 1.0;
	bool edge_bottom = cell.y >= grid.y - 1.0, edge_right = cell.x >= grid.x - 1.0;
	if (marquee && (edge_top || edge_left || edge_bottom || edge_right)) {
		// Position along the border, clockwise from the top-left corner.
		float along;
		if (edge_top) along = cell.x;
		else if (edge_right) along = grid.x + cell.y;
		else if (edge_bottom) along = grid.x + grid.y + (grid.x - 1.0 - cell.x);
		else along = 2.0 * grid.x + grid.y + (grid.y - 1.0 - cell.y);
		float phase = mod(floor(along / 2.0) + floor(TIME * marquee_speed), 4.0);
		vec4 c = phase < 0.5 ? cycle_a : (phase < 1.5 ? cycle_b : (phase < 2.5 ? cycle_c : cycle_b));
		COLOR = vec4(q5(c.rgb), 1.0);
	} else if (edge_top || edge_left) {
		COLOR = vec4(q5((recessed ? lo_colour : hi_colour).rgb), 1.0);
	} else if (edge_bottom || edge_right) {
		COLOR = vec4(q5((recessed ? hi_colour : lo_colour).rgb), 1.0);
	} else {
		// Four quantised steps from top to bottom, dithered between.
		float f = clamp((cell.y - 1.0) / max(grid.y - 3.0, 1.0), 0.0, 1.0) * 3.0;
		float base = floor(f);
		float level = min(base + (f - base > threshold(screen_cell) ? 1.0 : 0.0), 3.0);
		COLOR = vec4(q5(mix(top_colour.rgb, bottom_colour.rgb, level / 3.0)), top_colour.a);
	}
}
