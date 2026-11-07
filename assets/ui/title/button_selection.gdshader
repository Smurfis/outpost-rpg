shader_type canvas_item;

// The Alpha build physically removes the old screenshot shadows/rays from
// its imported PNGs via tools/clean_title_art.py. Never draw another geometric
// silhouette mask or opaque circular selection border on top of the art.
uniform bool selected = false;
uniform bool originally_gold = false;
uniform int plaque_kind = 0; // Play, Continue, Settings, Quit

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec3 rgb = source.rgb;
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
    if (!selected && originally_gold) {
        // The base Play plaque was painted brighter than every other one.
        rgb = mix(rgb, vec3(luma * 0.99, luma * 0.70, luma * 0.51),
                  smoothstep(0.10, 0.46, luma) * 0.68);
    }
    if (selected && plaque_kind != 3) {
        // Warm the existing wood and lettering only; don't create a gold oval.
        float wood = smoothstep(0.10, 0.28, luma) *
                     (1.0 - smoothstep(0.93, 1.0, luma));
        rgb = mix(rgb, vec3(min(1.0, luma * 1.34 + 0.09),
                            min(1.0, luma * 0.98 + 0.06),
                            min(1.0, luma * 0.58 + 0.02)), wood * 0.56);
    } else if (selected && plaque_kind == 3) {
        // White luminous Quit text + power icon, not gold stars or a ring.
        float lettering = smoothstep(0.26, 0.33, UV.x) *
                          (1.0 - smoothstep(0.77, 0.84, UV.x)) *
                          smoothstep(0.18, 0.25, UV.y) *
                          (1.0 - smoothstep(0.77, 0.85, UV.y));
        float ink = 1.0 - smoothstep(0.16, 0.40, luma);
        rgb = mix(rgb, vec3(1.0, 1.0, 0.98), lettering * ink);
    }
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), source.a) * COLOR;
}
