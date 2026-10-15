// Shared picture grading; keep the reference and cached beam paths identical.
uniform float gamma = 2.25;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec2 hue_rotation = vec2(1,0);
uniform vec3 white_balance = vec3(1);
vec3 grade_rgb(vec3 c) {
 float y = dot(c,vec3(.299,.587,.114));
 vec2 iq = vec2(dot(c,vec3(.595716,-.274453,-.321263)),dot(c,vec3(.211456,-.522591,.311135)));
 iq = vec2(iq.x*hue_rotation.x-iq.y*hue_rotation.y,iq.x*hue_rotation.y+iq.y*hue_rotation.x)*saturation;
 c = vec3(y+.9563*iq.x+.6210*iq.y,y-.2721*iq.x-.6474*iq.y,y-1.1070*iq.x+1.7046*iq.y);
 c = clamp((c-.5)*contrast+.5,vec3(0),vec3(1))*white_balance;
 return pow(max(c,vec3(0)),vec3(gamma))*brightness;
}
