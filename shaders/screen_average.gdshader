shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D signal_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	// Every output pixel contains the same whole-picture mean. No spatial image
	// detail is allowed through to the cabinet's lighting material.
	vec3 mean = vec3(0.0);
	for (int y = 0; y < 8; y++) {
		for (int x = 0; x < 8; x++) {
			vec3 sample_color = texture(signal_texture, (vec2(float(x), float(y)) + vec2(0.5)) / 8.0).rgb;
			mean += pow(max(sample_color, vec3(0.0)), vec3(2.2));
		}
	}
	COLOR = vec4(pow(mean / 64.0, vec3(1.0 / 2.2)), 1.0);
}
