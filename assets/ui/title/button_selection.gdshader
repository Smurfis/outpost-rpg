shader_type canvas_item;

// Keep the artist's wood/icon/text, but remove the screenshot scenery and
// permanent starbursts around each separately-rendered button. A SINGLE
// separate SVG glow in title_screen.gd follows the currently selected button.
uniform bool selected = false;
uniform bool originally_gold = false;
uniform bool disabled_button = false;
uniform bool down = false;
uniform int plaque_kind = 0; // 0 Play, 1 Continue, 2 Settings, 3 Quit
void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec3 rgb = original.rgb;
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));

    // ImageTexture now contains actual transparent pixels outside the plaque.
    // Do not apply another rectangular/oval clipping mask over the artwork.
    float alpha = original.a;

    // Play's original golden plaque should dim when not selected, like all
    // other plaques; never leave gold around it when moving to another.
    if (!selected && originally_gold) {
        vec3 wood = vec3(luma * 0.98, luma * 0.66, luma * 0.47);
        rgb = mix(rgb, wood, 0.72 * smoothstep(0.09, 0.43, luma));
    }
    if (selected && plaque_kind != 3) {
        float wood_areas = smoothstep(0.09, 0.32, luma) *
                           (1.0 - smoothstep(0.90, 1.0, luma));
        vec3 bright_gold = vec3(min(1.0, luma * 1.53 + 0.13),
                                min(1.0, luma * 1.03 + 0.04),
                                min(1.0, luma * 0.47));
        rgb = mix(rgb, bright_gold, wood_areas * 0.72);
    } else if (selected && plaque_kind == 3) {
        // Quit is different: no gold rays, no asterisks. The label and power
        // symbol illuminate white against the unchanged amber button plaque.
        // A white power symbol AND Quit lettering, even on pressed/touch.
        // Extend the ink mask leftward to include the separately painted icon.
        float centre = smoothstep(0.11, 0.18, UV.x) *
                       (1.0 - smoothstep(0.82, 0.90, UV.x)) *
                       smoothstep(0.22, 0.31, UV.y) *
                       (1.0 - smoothstep(0.75, 0.86, UV.y));
        float dark_ink = 1.0 - smoothstep(0.19, 0.42, luma);
        rgb = clamp(rgb * 1.06 + vec3(0.018), vec3(0.0), vec3(1.0));
        rgb = mix(rgb, vec3(1.0), centre * dark_ink);
    }
    // COLOR already contains the sampled texel in Godot's canvas fragment.
    // Multiplying the newly whitened glyph by that original dark ink would
    // turn the power symbol and Quit label black again. Output once instead.
    if (disabled_button) {
        rgb *= vec3(0.70);
        alpha *= 0.88;
    } else if (down && plaque_kind != 3) {
        rgb *= vec3(0.93, 0.91, 0.88);
    }
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), alpha);
}
