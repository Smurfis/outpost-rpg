shader_type canvas_item;

// The original crest is already painted and fully coloured. Godot supplies
// its sampled texture in fragment COLOR; sampling TEXTURE and multiplying
// COLOR once more doubles the colour and darkens the entire Outpost wordmark.
// Fade only the outer alpha, never the source RGB.
void fragment() {
    float left_fade = smoothstep(0.0, 0.08, UV.x);
    float right_fade = smoothstep(0.0, 0.08, 1.0 - UV.x);
    float top_fade = smoothstep(0.0, 0.02, UV.y);
    float bottom_fade = smoothstep(0.0, 0.07, 1.0 - UV.y);
    float edge_alpha = min(min(left_fade, right_fade), min(top_fade, bottom_fade));
    COLOR.a *= edge_alpha;
}
