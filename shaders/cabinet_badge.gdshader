shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D artwork : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 badge_colour : source_color = vec4(0.73, 0.70, 0.63, 1.0);
void fragment() {
 ALBEDO = badge_colour.rgb;
 METALLIC = 0.55;
 ROUGHNESS = 0.48;
 ALPHA = texture(artwork, UV).a;
 ALPHA_SCISSOR_THRESHOLD = 0.45;
}
