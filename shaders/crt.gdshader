shader_type spatial;
render_mode unshaded, cull_disabled;
// Gaussian beam reconstruction adapted from Timothy Lottes' PUBLIC DOMAIN
// crt-lottes.glsl. Original retained in third_party/shaders with provenance.
// Curvature is geometry only; fitting never discards source pixels.
uniform sampler2D signal_texture : source_color, filter_linear, repeat_disable;
uniform vec2 signal_size = vec2(256.0,240.0);
uniform vec4 picture_rect = vec4(.045,.045,.91,.91);
uniform float scanlines = .22;
uniform float mask_strength = .10;
uniform float glow_strength = .12;
uniform float beam_softness = 3.0;
uniform float vignette = .06;
#include "res://shaders/include/crt_colour.gdshaderinc"
uniform sampler2D beam_texture : source_color, filter_linear, repeat_disable;
uniform bool use_shared_beam = false;
uniform bool fitting_guides = false;
uniform float power_progress : hint_range(0.0,1.0) = 1.0;
vec3 linear_signal(vec2 uv) {
 vec3 c = texture(signal_texture,clamp(uv,vec2(.5)/signal_size,vec2(1)-vec2(.5)/signal_size)).rgb;
 if (!OUTPUT_IS_SRGB) c = pow(max(c,vec3(0)),vec3(1.0/2.2));
 return grade_rgb(c);
}
vec3 fetch_pixel(vec2 uv,vec2 offset) {
 return linear_signal((floor(uv*signal_size+offset)+vec2(.5))/signal_size);
}
float gauss(float p,float sharpness) { return exp2(-sharpness*p*p); }
vec3 horz(vec2 uv,float line,bool wide) {
 float dst = .5-fract(uv.x*signal_size.x);
 float wb = gauss(dst-1.0,beam_softness);
 float wc = gauss(dst,beam_softness);
 float wd = gauss(dst+1.0,beam_softness);
 vec3 sum = fetch_pixel(uv,vec2(-1,line))*wb + fetch_pixel(uv,vec2(0,line))*wc + fetch_pixel(uv,vec2(1,line))*wd;
 float weight = wb+wc+wd;
 if(wide) {
  float wa = gauss(dst-2.0,beam_softness);
  float we = gauss(dst+2.0,beam_softness);
  sum += fetch_pixel(uv,vec2(-2,line))*wa + fetch_pixel(uv,vec2(2,line))*we;
  weight += wa+we;
 }
 return sum/weight;
}
vec3 cached_row(vec2 uv,float line,float stripe) {
 float row = clamp((floor(uv.y*signal_size.y)+line+.5)/signal_size.y,.5/signal_size.y,1.0-.5/signal_size.y);
 vec3 encoded = texture(beam_texture,vec2(clamp(uv.x,0.0,1.0),(row+stripe)*.5)).rgb;
 return (OUTPUT_IS_SRGB ? pow(max(encoded,vec3(0)),vec3(2.2)) : encoded)*2.0;
}
void fragment() {
 vec2 uv = (UV-picture_rect.xy)/picture_rect.zw;
 vec2 pixel = uv*signal_size;
 vec2 footprint = fwidth(pixel);
 vec3 color = vec3(0);
 if(all(greaterThanEqual(uv,vec2(0))) && all(lessThanEqual(uv,vec2(1)))) {
  float resolved = 1.0-smoothstep(.35,.95,footprint.y);
  color = linear_signal(uv);
  if(scanlines*resolved>.001) {
   float dst = .5-fract(pixel.y);
   float wa = gauss(dst-1.0,6.0), wb = gauss(dst,6.0), wc = gauss(dst+1.0,6.0);
   vec3 beam;
   if(use_shared_beam) beam = cached_row(uv,-1.0,0.0)*wa + cached_row(uv,0.0,1.0)*wb + cached_row(uv,1.0,0.0)*wc;
   else beam = horz(uv,-1.0,false)*wa + horz(uv,0.0,true)*wb + horz(uv,1.0,false)*wc;
   // Integral of the Gaussian keeps average energy stable, not each scan row.
   beam /= sqrt(3.14159265/(6.0*log(2.0)));
   color = mix(color,beam,scanlines*resolved);
  }
  float mask = mask_strength*(1.0-smoothstep(.20,.55,footprint.x));
  color *= vec3(1)+mask*cos(vec3(pixel.x*6.283185)+vec3(0,2.094395,4.188790));
  if(glow_strength>.001) {
   vec2 spread = vec2(1.5)/signal_size;
   vec3 halo = (linear_signal(uv+spread)+linear_signal(uv-spread)+linear_signal(uv+vec2(spread.x,-spread.y))+linear_signal(uv+vec2(-spread.x,spread.y)))*.25;
   color += glow_strength*max(halo-vec3(.45),vec3(0));
  }
  vec2 p = abs(uv*2.0-1.0);
  color *= 1.0-vignette*dot(p*p,p*p);
  color = clamp(color,vec3(0),vec3(1));
  if(fitting_guides) {
   vec2 edge = min(uv,vec2(1)-uv)*signal_size;
   if(min(edge.x,edge.y)<2.0) {
    color = uv.y < .02 ? vec3(1,.15,.1) : (uv.y>.98 ? vec3(.15,.3,1) : (uv.x<.02 ? vec3(.15,1,.2) : vec3(1,1,.1)));
   }
   float circle = length((uv-.5)*vec2(4.0/3.0,1.0));
   if(abs(circle-.3)<max(fwidth(circle),.002)) color = vec3(.8);
  }
 }
 // Brief deflection warm-up: a dim centre line opens into the full picture.
 // Reveal existing pixels rather than squeezing/cropping the game image.
 if(power_progress<1.0) {
  float t = clamp(power_progress,0.0,1.0);
  float half_height = mix(.0015,.505,smoothstep(.10,.48,t));
  float edge = max(fwidth(uv.y)*1.5,.002);
  float aperture = 1.0-smoothstep(half_height-edge,half_height+edge,abs(uv.y-.5));
  float power_brightness = smoothstep(.12,1.0,t);
  float line = exp(-abs(uv.y-.5)*320.0)*smoothstep(.02,.10,t)*(1.0-smoothstep(.18,.40,t));
  float inside = step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
  color = color*aperture*power_brightness + vec3(.10,.115,.12)*line*inside;
 }
 ALBEDO = OUTPUT_IS_SRGB ? pow(color,vec3(1.0/2.2)) : color;
}
