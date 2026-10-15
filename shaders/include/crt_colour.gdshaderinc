// Shared picture grading; keep the reference and cached beam paths identical.
uniform float gamma = 2.25;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec2 hue_rotation = vec2(1,0);
uniform vec3 white_balance = vec3(1);
uniform mat3 colour_matrix = mat3(1);
vec3 grade_rgb(vec3 c) {
 // Compose RGB/YIQ conversion, hue and saturation once when controls change.
 c = colour_matrix*c;
 c = clamp((c-.5)*contrast+.5,vec3(0),vec3(1))*white_balance;
 return pow(max(c,vec3(0)),vec3(gamma))*brightness;
}
