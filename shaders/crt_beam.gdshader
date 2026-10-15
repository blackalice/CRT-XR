shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Timothy Lottes' public-domain Gaussian horizontal reconstruction, evaluated
// once per source row and shared between eyes. No mask, vertical scanline phase,
// geometry or derivative-dependent attenuation is baked into this cache.
uniform sampler2D signal_texture : source_color, filter_linear, repeat_disable;
uniform vec2 signal_size = vec2(256,240);
uniform float beam_softness = 3.0;
#include "res://shaders/include/crt_colour.gdshaderinc"
vec3 fetch_pixel(vec2 uv,float offset) {
 vec2 at = (floor(uv*signal_size+vec2(offset,0))+.5)/signal_size;
 return grade_rgb(texture(signal_texture,clamp(at,vec2(.5)/signal_size,vec2(1)-vec2(.5)/signal_size)).rgb);
}
void fragment() {
 bool wide = UV.y>=.5;
 vec2 uv = vec2(UV.x,fract(UV.y*2.0));
 float dst = .5-fract(uv.x*signal_size.x);
 float wb = exp2(-beam_softness*(dst-1.0)*(dst-1.0));
 float wc = exp2(-beam_softness*dst*dst);
 float wd = exp2(-beam_softness*(dst+1.0)*(dst+1.0));
 vec3 sum = fetch_pixel(uv,-1.0)*wb+fetch_pixel(uv,0.0)*wc+fetch_pixel(uv,1.0)*wd;
 float weight = wb+wc+wd;
 if(wide) {
  float wa = exp2(-beam_softness*(dst-2.0)*(dst-2.0));
  float we = exp2(-beam_softness*(dst+2.0)*(dst+2.0));
  sum += fetch_pixel(uv,-2.0)*wa+fetch_pixel(uv,2.0)*we;
  weight += wa+we;
 }
 // Encode for the Compatibility viewport's 8-bit target to retain dark tones.
 // The eye shader decodes before the original vertical beam reconstruction.
 // Reserve 2x headroom: user brightness/warmth can exceed white before the
 // final eye shader clamps. Clipping here would change bright scanline peaks.
 COLOR = vec4(pow(max(sum/weight,vec3(0))*.5,vec3(1.0/2.2)),1);
}
