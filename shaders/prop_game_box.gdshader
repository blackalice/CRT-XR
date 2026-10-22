shader_type spatial;
// The stack shares one mesh/material. Vertex colour g identifies plastic;
// b selects the bottom (0.5, cardboard-01) or top (1.0, cardboard-02) carton.
varying flat float face;
varying flat float kind;
varying flat float artwork;
uniform sampler2D carton_cover : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D carton_spine : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D carton_edge : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D carton2_cover : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D carton2_spine : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D carton2_edge : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D clamshell_cover : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D clamshell_spine : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D clamshell_edge : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// The artwork is authored for screens; its near-white backgrounds would read as
// glowing beside the dark VCR and radio. Scale print into a paper-like range.
uniform float print_albedo : hint_range(0.0, 1.0) = 0.65;

vec3 print(sampler2D artwork_texture, vec2 uv) {
	return texture(artwork_texture, uv).rgb * print_albedo;
}

void vertex() {
	face = UV2.x;
	kind = COLOR.g;
	artwork = COLOR.b;
}

void fragment() {
	vec3 albedo;
	float roughness;
	if (kind > 0.5) {
		albedo = vec3(0.018);
		roughness = 0.35;
		// The portrait case's long edges are its left/right faces, unlike the
		// landscape cartons. Front/back are the plain short edges.
		if (face < 1.5) {
			albedo = print(clamshell_edge, UV);
		} else if (face < 3.5) {
			albedo = print(clamshell_spine, UV);
		} else if (face < 4.5) {
			// Keep the black plastic rim around the printed cover insert.
			vec2 aa = fwidth(UV) * 0.75;
			vec2 inside = smoothstep(vec2(0.06, 0.04) - aa, vec2(0.06, 0.04) + aa, UV)
				* (1.0 - smoothstep(vec2(0.94, 0.96) - aa, vec2(0.94, 0.96) + aa, UV));
			vec2 insert_uv = (UV - vec2(0.06, 0.04)) / vec2(0.88, 0.92);
			albedo = mix(albedo, print(clamshell_cover, insert_uv), inside.x * inside.y);
			roughness = 0.22;
		}
	} else {
		roughness = 0.75;
		if (face < 1.5) {
			albedo = artwork > 0.75 ? print(carton2_spine, UV) : print(carton_spine, UV);
		} else if (face < 3.5) {
			albedo = artwork > 0.75 ? print(carton2_edge, UV) : print(carton_edge, UV);
		} else if (face < 4.5) {
			albedo = artwork > 0.75 ? print(carton2_cover, UV) : print(carton_cover, UV);
		} else {
			albedo = vec3(0.10);
		}
	}
	// Printed ink is lit by the room and screen, with no emission or baked lighting.
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
}
