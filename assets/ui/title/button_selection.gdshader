shader_type canvas_item;

// The approved PNGs already contain hand-lettered labels. Recolour the plaque
// *pixels*, not a rectangular focus box. Play's baked gold is turned into
// muted wood when another action is selected.
uniform bool selected = false;
uniform bool originally_gold = false;

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
    float midtone = smoothstep(0.11, 0.39, luma) * (1.0 - smoothstep(0.81, 0.96, luma));
    vec3 result = source.rgb;
    if (selected) {
        vec3 gold = vec3(min(1.0, luma * 1.42 + 0.10), min(1.0, luma * 0.92 + 0.03), min(1.0, luma * 0.43));
        result = mix(result, gold, 0.82 * midtone);
    } else if (originally_gold) {
        vec3 wood = vec3(luma * 1.02, luma * 0.62, luma * 0.42);
        result = mix(result, wood, 0.91 * midtone);
        // Play has permanent sparkle strokes near the extreme PNG edges.
        // Fade just those outer edges while unfocused; selected buttons
        // receive their own independently drawn, moveable gold starbursts.
        float outside = max(1.0 - smoothstep(0.02, 0.11, UV.x), smoothstep(0.89, 0.98, UV.x));
        source.a *= 1.0 - outside * 0.96;
    }
    COLOR = vec4(result, source.a) * COLOR;
}
