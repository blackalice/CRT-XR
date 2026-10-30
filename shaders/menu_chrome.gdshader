shader_type canvas_item;
// Chrome lettering for the menu title, as on console boot logos: white to pale
// blue, a hard dark "horizon" across the middle, then light again. Only the
// light fill of the text takes the chrome; the dark outline and shadow drawn by
// the same Label keep their own colour.
uniform float height = 44.0;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 glyph = COLOR * texture(TEXTURE, UV);
	float t = clamp(local_y / height, 0.0, 1.0);
	vec3 chrome;
	if (t < 0.48) chrome = mix(vec3(1.0), vec3(0.753, 0.831, 0.973), t / 0.48);
	else if (t < 0.54) chrome = vec3(0.220, 0.345, 0.659);
	else chrome = mix(vec3(0.533, 0.659, 0.878), vec3(0.910, 0.941, 1.0), (t - 0.54) / 0.46);
	float light = dot(COLOR.rgb, vec3(0.333));
	COLOR = vec4(light > 0.5 ? chrome : glyph.rgb, glyph.a);
}
