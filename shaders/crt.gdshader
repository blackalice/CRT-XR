shader_type spatial;
render_mode unshaded, cull_disabled;
// Curvature belongs to the mesh: a second UV warp would bend the picture twice.
uniform sampler2D signal_texture : source_color, filter_linear, repeat_disable;
uniform float scanlines : hint_range(0.0, 1.0) = 0.22;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.10;
uniform vec2 signal_size = vec2(256.0, 240.0);
uniform float glow_strength : hint_range(0.0, 0.4) = 0.12;

vec3 linear_signal(vec2 uv) {
	vec3 color = texture(signal_texture, uv).rgb;
	return OUTPUT_IS_SRGB ? pow(max(color, vec3(0.0)), vec3(2.2)) : color;
}

void fragment() {
	vec2 pixel = UV * signal_size;
	vec2 footprint = fwidth(pixel);
	// Resolve rows at their centres when magnified, integrate them when distant.
	vec2 sample_uv = vec2(UV.x, mix((floor(pixel.y) + 0.5) / signal_size.y,
		UV.y, smoothstep(0.4, 1.0, footprint.y)));
	vec3 signal = linear_signal(sample_uv);
	vec2 spread = 1.5 / signal_size;
	vec3 halo = (linear_signal(UV + vec2(spread.x, spread.y))
		+ linear_signal(UV + vec2(-spread.x, spread.y))
		+ linear_signal(UV + vec2(spread.x, -spread.y))
		+ linear_signal(UV - spread)) * 0.25;
	float brightness = dot(signal, vec3(0.2126, 0.7152, 0.0722));
	float beam = scanlines * (1.0 - smoothstep(0.35, 0.9, footprint.y))
		* (1.0 - 0.3 * brightness);
	// Mean compensation avoids simply darkening the picture with black stripes.
	float scan = (1.0 - beam * (0.5 + 0.5 * cos(pixel.y * 6.283185)))
		/ (1.0 - 0.5 * beam);
	// Smooth RGB grille, suppressed when the eye viewport cannot resolve it.
	float mask = mask_strength * (1.0 - smoothstep(0.20, 0.5, footprint.x));
	vec3 grille = vec3(1.0) + mask * cos(vec3(pixel.x * 6.283185) + vec3(0.0, 2.094395, 4.188790));
	vec3 color = signal * scan * grille + glow_strength * max(halo - vec3(0.45), vec3(0.0));
	vec2 p = abs(UV * 2.0 - 1.0);
	float vignette = 1.0 - 0.10 * dot(p * p, p * p);
	vec2 corner = max(p - vec2(0.94), vec2(0.0));
	float edge = 1.0 - smoothstep(0.058 - fwidth(length(corner)), 0.062, length(corner));
	color = clamp(color * vignette * edge, vec3(0.0), vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? pow(color, vec3(1.0 / 2.2)) : color;
}
