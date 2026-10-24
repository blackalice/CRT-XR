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
// TV moments (scripts/rendering/tv_effects.gd): a channel change's static and
// picture roll, a degauss's wobble and colour swirl, and the power-off.
uniform float channel_static : hint_range(0.0,1.0) = 0.0;
uniform float picture_roll : hint_range(0.0,1.0) = 0.0;
uniform float degauss : hint_range(0.0,1.0) = 0.0;
uniform bool degauss_wobble = true;
uniform float power_off : hint_range(0.0,1.0) = 0.0;
float static_noise(vec2 cell) {
 return fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
}
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
 vec2 tube = uv;
 // Power-off: the picture collapses to a bright line, then to a dot.
 if(power_off>0.0) {
  vec2 squash = vec2(mix(1.0,.008,smoothstep(.40,.78,power_off)),mix(1.0,.006,smoothstep(0.0,.42,power_off)));
  uv = (uv-.5)/squash+.5;
 }
 // A rolling picture settles back into place after a channel change.
 if(picture_roll>0.0) uv.y = fract(uv.y+picture_roll);
 if(degauss>0.0 && degauss_wobble) {
  uv.x += sin(uv.y*17.0+TIME*31.0)*.010*degauss;
  uv.y += sin(uv.x*11.0+TIME*23.0)*.006*degauss;
 }
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
  if(degauss>0.0) {
   // The coil's field sweeps colour blotches across the mask as it fades.
   vec3 swirl = .5+.5*cos(6.283185*(vec3(0.0,.33,.67)+uv.x*1.4+uv.y*.8+TIME*.9));
   color *= mix(vec3(1),swirl*1.7,degauss*.65);
  }
  if(power_off>0.0) color *= 1.0+3.0*smoothstep(.25,.60,power_off);
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
 if(picture_roll>0.0) {
  // The vertical blanking interval rolls past as a dark bar.
  float rolled = fract(tube.y+picture_roll);
  color *= smoothstep(0.0,.035,rolled)*smoothstep(1.0,.965,rolled);
 }
 if(channel_static>0.0) {
  float inside_tube = step(0.0,tube.x)*step(tube.x,1.0)*step(0.0,tube.y)*step(tube.y,1.0);
  float snow = static_noise(floor(tube*vec2(320.0,240.0))+vec2(floor(TIME*60.0)*7.0,floor(TIME*60.0)*13.0));
  color = mix(color,vec3(snow*.85)*inside_tube,channel_static);
 }
 if(power_off>.70) {
  // The last of the beam: a dot that fades in the middle of the tube.
  vec2 centre = (tube-.5)*vec2(picture_rect.z/picture_rect.w*4.0/3.0,1.0);
  float dot_glow = exp(-dot(centre,centre)*2600.0)*(1.0-smoothstep(.80,1.0,power_off));
  color = color*(1.0-smoothstep(.76,.84,power_off)) + vec3(dot_glow);
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
