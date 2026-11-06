shader_type canvas_item;
// The approved raster crest includes some surrounding sky in its crop.
// Fade that cutout to the painted scene instead of showing a hard opaque box.
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    float left = smoothstep(0.0, 0.10, UV.x);
    float right = smoothstep(0.0, 0.11, 1.0 - UV.x);
    float top = smoothstep(0.0, 0.025, UV.y);
    float bottom = smoothstep(0.0, 0.075, 1.0 - UV.y);
    pixel.a *= min(min(left, right), min(top, bottom));
    COLOR = pixel * COLOR;
}
