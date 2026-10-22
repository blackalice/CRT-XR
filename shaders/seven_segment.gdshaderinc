// Seven-segment clock digits for prop displays. Cell space: x 0..1, y 0..2 (down).
// Returns vec2(lit coverage, all-segment coverage) so unlit segments can show
// faintly behind the display filter, as on real LED/VFD panels.
const int SEGMENT_DIGITS[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);

float segment_box(vec2 p, vec2 centre, vec2 half_size) {
	vec2 d = abs(p - centre) - half_size;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

vec2 seven_segment(vec2 p, int digit, float aa) {
	p.x += (p.y - 1.0) * 0.09; // the slight italic of period clock displays
	vec2 centres[7] = vec2[](vec2(0.5, 0.1), vec2(0.88, 0.55), vec2(0.88, 1.45), vec2(0.5, 1.9), vec2(0.12, 1.45), vec2(0.12, 0.55), vec2(0.5, 1.0));
	vec2 sizes[7] = vec2[](vec2(0.30, 0.065), vec2(0.065, 0.36), vec2(0.065, 0.36), vec2(0.30, 0.065), vec2(0.065, 0.36), vec2(0.065, 0.36), vec2(0.30, 0.065));
	float lit = 0.0;
	float all = 0.0;
	int mask = digit >= 0 ? SEGMENT_DIGITS[digit] : 0;
	for (int i = 0; i < 7; i++) {
		float coverage = 1.0 - smoothstep(-aa, aa, segment_box(p, centres[i], sizes[i]));
		all = max(all, coverage);
		if (((mask >> i) & 1) == 1) lit = max(lit, coverage);
	}
	return vec2(lit, all);
}

// Four digits and a steady colon across a window; q is in window-height units.
// Returns vec2(lit, all) like seven_segment. Leading digit -1 shows as unlit.
vec2 clock_digits(vec2 q, float width, int d0, int d1, int d2, int d3, float aa) {
	float x0 = (width - 1.88) * 0.5;
	float digit_scale = 0.35;
	vec2 result = vec2(0.0);
	float origins[4] = float[](0.0, 0.42, 1.04, 1.46);
	int digits[4] = int[](d0, d1, d2, d3);
	for (int k = 0; k < 4; k++) {
		vec2 cell = (q - vec2(x0 + origins[k], 0.15)) / digit_scale;
		if (cell.x > -0.3 && cell.x < 1.3 && cell.y > -0.2 && cell.y < 2.2)
			result = max(result, seven_segment(cell, digits[k], aa / digit_scale));
	}
	for (int dot_index = 0; dot_index < 2; dot_index++) {
		float dot_cover = 1.0 - smoothstep(0.035 - aa, 0.035 + aa, length(q - vec2(x0 + 0.92, dot_index == 0 ? 0.38 : 0.62)));
		result = max(result, vec2(dot_cover));
	}
	return result;
}
