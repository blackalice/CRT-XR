shader_type spatial;
// Original clock radio: charcoal plastic, perforated speaker grille, smoked
// red-filtered LED display and a snooze bar. The display glows dimly and does
// not light the room; it is steady, with no blinking.
#include "res://shaders/seven_segment.gdshaderinc"
uniform int hours = 12;
uniform int minutes = 0;
uniform bool pm = false;
uniform bool twelve_hour = true;
uniform float display_level = 0.6;
varying flat float face;

// Antialiasing width per axis: a face seen at a shallow angle is far more
// compressed in one direction, and a shared width would smear it into bars.
float rect(vec2 uv, vec4 bounds, vec2 aa) {
	vec2 inside = smoothstep(bounds.xy - aa, bounds.xy + aa, uv) * (1.0 - smoothstep(bounds.zw - aa, bounds.zw + aa, uv));
	return inside.x * inside.y;
}

void vertex() { face = UV2.x; }

void fragment() {
	vec3 body = vec3(0.032, 0.032, 0.035);
	vec3 albedo = body;
	float roughness = 0.55;
	vec3 emission = vec3(0.0);
	vec2 aa = fwidth(UV) * 0.75;
	if (face < 0.5) {
		// Front: grille on the left, display window on the right.
		float grille = rect(UV, vec4(0.05, 0.16, 0.42, 0.84), aa);
		vec2 holes = fract(UV * vec2(64.0, 20.0)) - 0.5;
		float hole = 1.0 - smoothstep(0.22, 0.32, length(holes * vec2(1.0, 0.95)));
		// Once the holes are smaller than a pixel, show their average instead.
		float resolved = 1.0 - smoothstep(0.3, 0.9, max(fwidth(UV.x * 64.0), fwidth(UV.y * 20.0)));
		albedo = mix(albedo, mix(vec3(0.022), mix(vec3(0.022), vec3(0.006), hole), resolved), grille);
		float window = rect(UV, vec4(0.48, 0.2, 0.95, 0.8), aa);
		vec2 window_uv = (UV - vec2(0.48, 0.2)) / vec2(0.47, 0.6);
		float aspect = 2.34;
		int hour = twelve_hour ? (hours % 12 == 0 ? 12 : hours % 12) : hours;
		vec2 digits = clock_digits(vec2(window_uv.x * aspect, window_uv.y), aspect,
			hour >= 10 ? hour / 10 : (twelve_hour ? -1 : 0), hour % 10, minutes / 10, minutes % 10, max(aa.x, aa.y) * 4.0);
		float pm_dot = twelve_hour && pm ? 1.0 - smoothstep(0.03, 0.05, length(vec2(window_uv.x * aspect, window_uv.y) - vec2((aspect - 1.88) * 0.5 - 0.1, 0.22))) : 0.0;
		vec3 red = vec3(1.0, 0.07, 0.03);
		albedo = mix(albedo, vec3(0.018, 0.004, 0.004) + red * 0.035 * digits.y, window);
		roughness = mix(roughness, 0.18, window);
		emission = red * max(digits.x, pm_dot) * display_level * window;
	} else if (face > 3.5 && face < 4.5) {
		// Top: snooze bar towards the front, a row of small setting buttons behind.
		float snooze = rect(UV, vec4(0.28, 0.6, 0.72, 0.8), aa);
		albedo = mix(albedo, vec3(0.06, 0.06, 0.065), snooze);
		for (int i = 0; i < 4; i++) {
			float x = 0.14 + float(i) * 0.08;
			albedo = mix(albedo, vec3(0.05), rect(UV, vec4(x, 0.22, x + 0.05, 0.32), aa));
		}
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
	EMISSION = emission;
}
