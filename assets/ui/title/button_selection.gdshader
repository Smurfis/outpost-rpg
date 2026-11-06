shader_type canvas_item;

// Artwork and selection are separate systems. Every button uses the same
// gold treatment, while Play's permanently painted edge glints are masked.
// Selected light comes from a separate movable SVG beneath the button.
uniform bool selected = false;
uniform bool originally_gold = false;

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
    float midtone = smoothstep(0.09, 0.39, luma) * (1.0 - smoothstep(0.88, 1.0, luma));
    // Remove the opaque cutout's baked outer shadow rather than masking the
    // entire rectangular Button. Keep its hand-lettered centre crisp.
    float horizontal = smoothstep(0.015, 0.095, UV.x) * (1.0 - smoothstep(0.905, 0.985, UV.x));
    float vertical = smoothstep(0.008, 0.085, UV.y) * (1.0 - smoothstep(0.915, 0.992, UV.y));
    source.a *= horizontal * vertical;
    if (originally_gold) {
        // Original Play PNG has permanent side asterisks. They must not stay
        // visible when another action owns the dynamic starburst selection.
        float painted_stars = max(1.0 - smoothstep(0.055, 0.160, UV.x),
                                  smoothstep(0.840, 0.945, UV.x));
        source.a *= 1.0 - painted_stars * 0.995;
    }
    vec3 result = source.rgb;
    if (selected) {
        vec3 gold = vec3(min(1.0, luma * 1.60 + 0.14),
                         min(1.0, luma * 1.03 + 0.08),
                         min(1.0, luma * 0.45 + 0.02));
        result = mix(result, gold, 0.97 * midtone);
        result += vec3(0.10, 0.065, 0.015) * midtone;
    } else if (originally_gold) {
        vec3 wood = vec3(luma * 0.95, luma * 0.62, luma * 0.43);
        result = mix(result, wood, smoothstep(0.10, 0.43, luma) * 0.98);
    }
    COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), source.a) * COLOR;
}
