shader_type canvas_item;
render_mode unshaded, blend_disabled;
// A VHS tape between the video and the TV: the VCR's playback, before its
// composite output reaches the CRT's own signal pass. Luma loses detail and
// gains the recorder's edge sharpening; chroma is smeared, delayed and noisy;
// lines wobble with timebase error; the head switch tears the bottom lines;
// search (FF/REW) rolls noise bars through the picture. Original CRT XR code.
uniform float wear = 0.4;              // 0 = a good tape, 1 = a worn one
uniform float search = 0.0;            // 0..1 while fast-forwarding or rewinding
uniform float search_direction = 1.0;  // 1 forward (bars fall), -1 back (bars rise)
uniform float still = 0.0;             // 1 on a paused (still) frame
uniform float seed = 0.0;              // advances once per field
const mat3 RGB_YIQ = mat3(vec3(.299,.595716,.211456),vec3(.587,-.274453,-.522591),vec3(.114,-.321263,.311135));
const mat3 YIQ_RGB = mat3(vec3(1,1,1),vec3(.9563,-.2721,-1.1070),vec3(.6210,-.6474,1.7046));

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float smooth_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 3.1)), hash(vec2(i + 1.0, 3.1)), f * f * (3.0 - 2.0 * f));
}
vec3 yiq(sampler2D picture, vec2 uv, vec2 pixel) {
	return RGB_YIQ * texture(picture, clamp(uv, pixel * 0.5, vec2(1.0) - pixel * 0.5)).rgb;
}
// A noise bar of the given half-height centred at `centre` (wrapping vertically).
float bar(float y, float centre, float half_height) {
	float d = abs(fract(y - centre + 0.5) - 0.5);
	return 1.0 - smoothstep(half_height * 0.4, half_height, d);
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float lines = 1.0 / pixel.y;
	float row = floor(UV.y * lines);
	float field = floor(seed);
	// Noise bars: two rolling through during search; a worn tape's still frame
	// shows one, shivering near the bottom.
	float rolling = search * max(bar(UV.y, field * 0.013 * search_direction, 0.05), bar(UV.y, 0.5 + field * 0.013 * search_direction, 0.05));
	float paused_bar = still * smoothstep(0.5, 1.0, wear) * 0.7 * bar(UV.y, 0.84 + 0.004 * sin(field * 1.7), 0.02);
	float noisy = max(rolling, paused_bar);
	// Head switching tears the last few lines before the vertical blank.
	float switching = smoothstep(1.0 - 0.03 - 0.02 * wear, 1.0, UV.y);
	float shift = (smooth_noise(row * 0.09 + field * 0.6) - 0.5) * (0.6 + 1.8 * wear)
		+ switching * (5.0 + 12.0 * hash(vec2(row, field))) * (0.5 + wear)
		+ noisy * (hash(vec2(row, field + 7.0)) - 0.5) * 24.0;
	vec2 uv = vec2(UV.x + shift * pixel.x, (row + 0.5) * pixel.y);

	// Luma: about 3 MHz of detail, with the recorder's sharpening halo.
	float near = 0.0;
	float wide = 0.0;
	for (int i = -4; i <= 4; i++) {
		float y = yiq(TEXTURE, uv + vec2(float(i) * pixel.x, 0.0), pixel).x;
		wide += y / 9.0;
		if (abs(i) <= 2) near += y * (i == 0 ? 6.0 : (abs(i) == 1 ? 4.0 : 1.0)) / 16.0;
	}
	float luma = near + (0.35 + 0.25 * wear) * (near - wide);
	luma += (hash(UV * vec2(997.0, lines) + field) - 0.5) * (0.03 + 0.05 * wear);

	// Chroma: a fraction of the luma's bandwidth, late on the line, averaged
	// with the line above, and streaked with low-frequency noise.
	vec2 chroma = vec2(0.0);
	float delay = (2.0 + 2.0 * wear) * pixel.x;
	for (int i = -5; i <= 5; i++) {
		vec2 at = uv + vec2(float(i) * 2.0 * pixel.x - delay, 0.0);
		chroma += yiq(TEXTURE, at, pixel).yz + yiq(TEXTURE, at - vec2(0.0, pixel.y), pixel).yz;
	}
	chroma *= 0.9 / 22.0;
	chroma += (vec2(smooth_noise(UV.x * 24.0 + row * 13.0 + field), smooth_noise(UV.x * 24.0 + row * 7.0 - field)) - 0.5) * 0.05 * wear;

	// Dropouts: a rare bright streak where the oxide has worn away.
	float dropout_row = step(1.0 - 0.0004 * wear * wear, hash(vec2(row, field + 19.0)));
	float start = hash(vec2(row, field + 23.0));
	float span = 0.006 + 0.02 * hash(vec2(row, field));
	float dropout = dropout_row * smoothstep(start, start + 0.003, UV.x) * (1.0 - smoothstep(start + span, start + span + 0.003, UV.x));
	luma = mix(luma, 0.8, dropout);

	// Torn and noisy lines lose their colour and fill with snow.
	float snow = hash(vec2(UV.x * 431.0 + field, row));
	luma = mix(luma, snow, noisy * 0.75) + switching * (snow - 0.5) * 0.12;
	chroma *= 1.0 - max(noisy, switching * 0.7);
	COLOR = vec4(clamp(YIQ_RGB * vec3(luma, chroma), vec3(0.0), vec3(1.0)), 1.0);
}
