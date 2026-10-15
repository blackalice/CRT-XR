shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, shadows_disabled;

// Retain ordinary PBR lighting, but use the authored baked occlusion on the
// casing instead of receiving unstable real-time self-shadows. This opaque
// material still casts a shadow onto the furniture and floor.
// Grain is static and mip-filtered; its normal detail fades when unresolved.
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 base_colour : source_color = vec4(1.0);
uniform vec2 roughness_limits = vec2(0.40, 0.76);
uniform float normal_depth = 0.65;
uniform bool has_normal = true;
uniform float ao_direct = 0.18;
uniform sampler2D baked_ao_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool has_baked_ao = false;
uniform float baked_ao_strength : hint_range(0.0, 1.0) = 0.70;
uniform sampler2D grain_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_grain = false;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    vec3 surface = texture(surface_map, UV).rgb;
    ALBEDO = texture(albedo_map, UV).rgb * base_colour.rgb;
    // The casing is a dielectric, even where the shared atlas includes metal.
    METALLIC = 0.0;
    SPECULAR = 0.5;
    ROUGHNESS = mix(roughness_limits.x, roughness_limits.y, surface.g);
    vec2 grain_normal = vec2(0.0);
    if (has_grain && grain_strength > 0.0001) {
        vec2 grain_uv = UV * 8.0;
        vec3 grain = texture(grain_map, grain_uv).rgb;
        // Mostly a finish variation, with very little painted colour noise.
        ROUGHNESS = clamp(ROUGHNESS + (grain.r - 0.5) * 0.18 * grain_strength, 0.32, 0.96);
        ALBEDO *= 1.0 + (grain.r - 0.5) * 0.04 * grain_strength;
        float footprint = max(length(dFdx(grain_uv)), length(dFdy(grain_uv))) * 256.0;
        float resolved = 1.0 - smoothstep(0.5, 1.5, footprint);
        grain_normal = (grain.gb - vec2(0.5)) * 0.18 * grain_strength * resolved;
    }
    AO = surface.r;
    if (has_baked_ao) {
        float contact = texture(baked_ao_map, UV).r;
        // An intentionally gentle artistic bake: retain recess depth even in
        // direct light, where Compatibility's ambient-only AO is too weak.
        ALBEDO *= mix(1.0, contact, baked_ao_strength);
        AO = mix(surface.r, min(surface.r, contact), baked_ao_strength);
    }
    AO_LIGHT_AFFECT = ao_direct;
    vec3 detailed_normal = has_normal ? texture(normal_map, UV).rgb : vec3(0.5, 0.5, 1.0);
    detailed_normal.xy = clamp(detailed_normal.xy + grain_normal, vec2(0.0), vec2(1.0));
    NORMAL_MAP = detailed_normal;
    NORMAL_MAP_DEPTH = has_normal ? normal_depth : 1.0;
}
