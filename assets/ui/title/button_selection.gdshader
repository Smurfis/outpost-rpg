shader_type canvas_item;

// Keep the artist's wood/icon/text, but remove the screenshot scenery and
// permanent starbursts around each separately-rendered button. A SINGLE
// separate SVG glow in title_screen.gd follows the currently selected button.
uniform bool selected = false;
uniform bool originally_gold = false;
uniform int plaque_kind = 0; // 0 Play, 1 Continue, 2 Settings, 3 Quit
void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec3 rgb = original.rgb;
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));

    // The PNG source cutouts also include an opaque rectangular landscape
    // screenshot. Mask it to the button silhouette, with soft 2-3 px edges.
    // The unselected plaque never contains its permanent surrounding rays.
    float y = UV.y;
    float curve = smoothstep(0.21, 0.49, abs(y - 0.50));
    float inset = 0.092 + 0.078 * curve;
    float top = 0.07;
    float bottom = 0.94;
    if (plaque_kind == 1) {
        inset = 0.055 + 0.055 * curve;
        top = 0.075;
        bottom = 0.94;
    } else if (plaque_kind == 2) {
        inset = 0.053 + 0.065 * curve;
        top = 0.075;
        bottom = 0.935;
    } else if (plaque_kind == 3) {
        inset = 0.110 + 0.068 * curve;
        top = 0.10;
        bottom = 0.92;
    }
    float left_soft = smoothstep(inset, inset + 0.015, UV.x);
    float right_soft = 1.0 - smoothstep(1.0 - inset - 0.015, 1.0 - inset, UV.x);
    float top_soft = smoothstep(top, top + 0.016, y);
    float bottom_soft = 1.0 - smoothstep(bottom - 0.016, bottom, y);
    float alpha = original.a * left_soft * right_soft * top_soft * bottom_soft;

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
        float centre = smoothstep(0.24, 0.27, UV.x) *
                       (1.0 - smoothstep(0.80, 0.84, UV.x)) *
                       smoothstep(0.20, 0.27, UV.y) *
                       (1.0 - smoothstep(0.79, 0.86, UV.y));
        float dark_ink = 1.0 - smoothstep(0.16, 0.35, luma);
        rgb = mix(rgb, vec3(1.0, 1.0, 0.98), centre * dark_ink * 0.98);
    }
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), alpha) * COLOR;
}
