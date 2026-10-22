shader_type spatial;
// Original slim VHS recorder: dark plastic, cassette door, small buttons and a
// dim teal fluorescent panel showing the standby clock (steady, no blinking).
#include "res://shaders/seven_segment.gdshaderinc"
uniform int hours = 12;
uniform int minutes = 0;
uniform bool twelve_hour = true;
uniform float display_level = 0.35;
uniform vec2 face_size = vec2(0.99, 0.22);
varying flat float face;

// Antialiasing width per axis: a face seen at a shallow angle is far more
// compressed in one direction, and a shared width would smear it into bars.
float rect(vec2 uv, vec4 bounds, vec2 aa) {
	vec2 inside = smoothstep(bounds.xy - aa, bounds.xy + aa, uv) * (1.0 - smoothstep(bounds.zw - aa, bounds.zw + aa, uv));
	return inside.x * inside.y;
}

void vertex() { face = UV2.x; }

void fragment() {
	vec3 albedo = vec3(0.04, 0.04, 0.043);
	float roughness = 0.45;
	vec3 emission = vec3(0.0);
	vec2 aa = fwidth(UV) * 0.75;
	if (face < 0.5) {
		// Cassette door: a recessed panel with a fine hinge line.
		float door = rect(UV, vec4(0.07, 0.24, 0.5, 0.66), aa);
		albedo = mix(albedo, vec3(0.014), door);
		albedo = mix(albedo, vec3(0.07), rect(UV, vec4(0.08, 0.29, 0.49, 0.31), aa) * door);
		// Fluorescent display window with the standby clock.
		float window = rect(UV, vec4(0.56, 0.24, 0.8, 0.62), aa);
		vec2 window_uv = (UV - vec2(0.56, 0.24)) / vec2(0.24, 0.38);
		float aspect = (0.24 * face_size.x) / (0.38 * face_size.y);
		int hour = twelve_hour ? (hours % 12 == 0 ? 12 : hours % 12) : hours;
		vec2 digits = clock_digits(vec2(window_uv.x * aspect, window_uv.y), aspect,
			hour >= 10 ? hour / 10 : (twelve_hour ? -1 : 0), hour % 10, minutes / 10, minutes % 10, max(aa.x, aa.y) * 4.0);
		vec3 teal = vec3(0.25, 0.95, 0.82);
		albedo = mix(albedo, vec3(0.006, 0.012, 0.012) + teal * 0.025 * digits.y, window);
		roughness = mix(roughness, 0.15, window);
		emission = teal * digits.x * display_level * window;
		// Transport buttons under the display, power button and standby LED to the right.
		for (int i = 0; i < 5; i++) {
			float x = 0.56 + float(i) * 0.048;
			albedo = mix(albedo, vec3(0.065), rect(UV, vec4(x, 0.72, x + 0.036, 0.8), aa));
		}
		albedo = mix(albedo, vec3(0.07), rect(UV, vec4(0.86, 0.28, 0.93, 0.44), aa));
		float led = 1.0 - smoothstep(0.006, 0.011, length((UV - vec2(0.895, 0.56)) * vec2(4.0, 1.0)));
		emission += vec3(1.0, 0.12, 0.05) * led * 0.25;
	} else if (face > 3.5 && face < 4.5) {
		// Ventilation slots across the back of the lid.
		float slots = rect(UV, vec4(0.25, 0.08, 0.75, 0.3), aa) * step(0.5, fract(UV.y * 40.0));
		albedo = mix(albedo, vec3(0.012), slots);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
	EMISSION = emission;
}
