shader_type canvas_item;

// Keep the central tent, campfire, waterfall and title furniture at original
// pixel proportions on 20:9 Android screens. Stretch only the far scenery
// margins to fill spare width. No duplicated panels or hard image seams.
uniform float side_extension_px = 0.0;
uniform float source_width_px = 1280.0;
uniform float preserve_left_px = 260.0;
uniform float preserve_right_px = 1040.0;

void fragment() {
    float display_width = source_width_px + 2.0 * side_extension_px;
    float screen_x = UV.x * display_width - side_extension_px;
    float source_x = screen_x;
    if (screen_x < preserve_left_px) {
        source_x = (screen_x + side_extension_px) * preserve_left_px
            / max(1.0, preserve_left_px + side_extension_px);
    } else if (screen_x > preserve_right_px) {
        source_x = preserve_right_px + (screen_x - preserve_right_px)
            * (source_width_px - preserve_right_px)
            / max(1.0, source_width_px + side_extension_px - preserve_right_px);
    }
    COLOR = texture(TEXTURE, vec2(clamp(source_x / source_width_px, 0.0, 1.0), UV.y));
}
