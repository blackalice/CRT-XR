/*
    Copyright (c) 2016, Viacheslav Slavinsky
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED.
    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
    THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Godot adaptation of svo's PAL singlepass shader (Viacheslav Slavinsky, 2016).
// See third_party/shaders/PAL-LICENSE.txt for the retained BSD notice.
// NTSC uses the upstream YIQ matrices, without PAL's alternating V phase.
uniform sampler2D source_texture : source_color, filter_linear, repeat_disable;
uniform vec2 source_size = vec2(256.0, 240.0);
uniform int signal_standard = 2;
uniform float composite_strength = 0.65;
uniform float artifact_strength = 0.35;
uniform float phase_noise = 0.0;
uniform float signal_motion = 0.0;
uniform float frame_index = 0.0;
const float FIR[20] = float[20](-0.008030271,0.003107906,0.016841352,0.032545161,
 0.049360136,0.066256720,0.082120150,0.095848433,0.106453014,0.113151423,
 0.115441842,0.113151423,0.106453014,0.095848433,0.082120150,0.066256720,
 0.049360136,0.032545161,0.016841352,0.003107906);
const mat3 RGB_YUV = mat3(vec3(.299,-.14713,.615),vec3(.587,-.28886,-.514991),vec3(.114,.436,-.10001));
const mat3 YUV_RGB = mat3(vec3(1,1,1),vec3(0,-.39465,2.03211),vec3(1.13983,-.58060,0));
const mat3 RGB_YIQ = mat3(vec3(.299,.595716,.211456),vec3(.587,-.274453,-.522591),vec3(.114,-.321263,.311135));
const mat3 YIQ_RGB = mat3(vec3(1,1,1),vec3(.9563,-.2721,-1.1070),vec3(.6210,-.6474,1.7046));
vec3 sample_source(vec2 uv) {
 return texture(source_texture,clamp(uv,vec2(.5)/source_size,vec2(1)-vec2(.5)/source_size)).rgb;
}
float hash_row(vec2 p) { return fract(sin(mod(dot(p,vec2(12.9898,78.233)),3.14))*43758.5453); }
void fragment() {
 vec2 xy = vec2(UV.x,(floor(UV.y*source_size.y)+.5)/source_size.y);
 bool pal = signal_standard == 2;
 float counts = pal ? (4433618.75/15625.0) : 227.5;
 float invx = .25/counts;
 float row = floor(xy.y*source_size.y);
 float alt_sign = pal && mod(row,2.0)>0.5 ? -1.0 : 1.0;
 float phase = pal ? 0.0 : mod(row,3.0)*2.0*PI/3.0;
 phase += mod(frame_index,3.0)*2.0*PI/3.0*signal_motion;
 float noise = phase_noise*(hash_row(vec2(row,frame_index))-0.5);
 // Every FIR tap advances exactly a quarter carrier cycle. Rotate the same
 // carrier instead of recomputing four trigonometric functions for every tap.
 float wt = xy.x*counts*2.0*PI+phase;
 vec2 center_carrier = vec2(sin(wt),cos(wt));
 vec2 wave = -center_carrier; // first tap is ten quarter-cycles before centre
 vec2 jitter = vec2(cos(noise),sin(noise));
 vec2 filtered = vec2(0);
 for (int i=0;i<20;i++) {
  vec2 at = xy+vec2((float(i)-10.0)*invx,0);
  vec3 rgb = sample_source(at);
  vec3 yuv = pal ? RGB_YUV*rgb : RGB_YIQ*rgb;
  float signal = clamp(yuv.x+yuv.y*wave.x+yuv.z*wave.y*alt_sign,0.0,1.0);
  vec2 demod = vec2(wave.x*jitter.x+wave.y*jitter.y,alt_sign*(wave.y*jitter.x-wave.x*jitter.y));
  filtered += 1.5*signal*demod*FIR[i];
  wave = vec2(wave.y,-wave.x);
 }
 vec3 raw = sample_source(xy);
 vec3 yuv = pal ? RGB_YUV*raw : RGB_YIQ*raw;
 float signal = clamp(yuv.x+yuv.y*center_carrier.x+yuv.z*center_carrier.y*alt_sign,0.0,1.0);
 float luma = signal-1.1*dot(filtered,vec2(center_carrier.x,center_carrier.y*alt_sign));
 vec3 decoded = vec3(mix(yuv.x,luma,artifact_strength),filtered);
 vec3 rgb = pal ? YUV_RGB*decoded : YIQ_RGB*decoded;
 COLOR = vec4(clamp(mix(raw,rgb,composite_strength),vec3(0),vec3(1)),1);
}
