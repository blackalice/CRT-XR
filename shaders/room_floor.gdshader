shader_type spatial;

uniform float fade_begin = 4.5;
uniform float fade_end = 9.0;
uniform float brightness = 1.15;
uniform sampler2D carpet_colour : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carpet_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carpet_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D contact_ao : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 contact_rect = vec4(-3.0,-2.5,6.0,5.0);
uniform bool contact_enabled = false;
varying vec3 world_position;
varying vec2 floor_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    floor_position = VERTEX.xz;
}
void fragment() {
    // A half-metre tile keeps the short pile believable; mipmaps suppress shimmer.
    vec2 carpet_uv = floor_position / 0.5;
    vec3 fibre = texture(carpet_colour,carpet_uv).rgb;
    float tone = dot(fibre,vec3(0.2126,0.7152,0.0722));
    // Muted warm wool, preserving the source pile's photographic variation.
    vec3 colour = vec3(0.30,0.275,0.235) * clamp(0.92 + tone * 0.8,0.9,1.1);
    float patch = 1.0 - smoothstep(0.48,0.98,length((UV-0.5)*2.0));
    float visibility = 1.0 - smoothstep(fade_begin,fade_end,distance(CAMERA_POSITION_WORLD,world_position));
    ALBEDO = colour * visibility * patch * brightness;
    NORMAL_MAP = texture(carpet_normal,carpet_uv).rgb;
    // Fade fine pile normals at distance as well as relying on mip filtering.
    float footprint=max(length(dFdx(carpet_uv)),length(dFdy(carpet_uv)));
    NORMAL_MAP_DEPTH = 0.18 * (1.0-smoothstep(0.012,0.06,footprint));
    ROUGHNESS = mix(0.86,1.0,texture(carpet_roughness,carpet_uv).r);
    SPECULAR = 0.12 * visibility * patch;
    float contact = texture(contact_ao,(floor_position-contact_rect.xy)/contact_rect.zw).r;
    // Native AO does not affect Compatibility direct lights.
    ALBEDO *= contact_enabled ? mix(1.0,contact,0.9) : 1.0;
    AO = 1.0;
}
