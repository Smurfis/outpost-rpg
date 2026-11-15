shader_type canvas_item;

// Smoothly remove the screenshot sky painted behind the approved crest.
// The previous separate top/side UV bands made horizontal gradient slices
// on mobile as the logo overlapped a differently scaled panorama.
// Sample the already-composited COLOR once; do not double-darken the image.
void fragment() {
    vec3 rgb = COLOR.rgb;
    float blue_sky = smoothstep(0.025, 0.13, rgb.b - rgb.r)
        * smoothstep(0.01, 0.10, rgb.b - rgb.g)
        * smoothstep(0.18, 0.48, rgb.b);
    float pink_sky = smoothstep(0.06, 0.17, rgb.r - rgb.g)
        * smoothstep(0.04, 0.16, rgb.b - rgb.g)
        * smoothstep(0.34, 0.62, rgb.r)
        * smoothstep(0.21, 0.45, rgb.b);

    // Protect the carved central wordmark and stone, not a broad horizontal
    // rectangle across the logo. This preserves smooth coverage of sky pixels.
    float carved_wordmark = smoothstep(0.12, 0.28, UV.x)
        * (1.0 - smoothstep(0.73, 0.86, UV.x))
        * smoothstep(0.48, 0.61, UV.y)
        * (1.0 - smoothstep(0.82, 0.92, UV.y));
    float sky = clamp(max(blue_sky, pink_sky), 0.0, 1.0);
    COLOR.a *= 1.0 - sky * (1.0 - carved_wordmark) * 0.995;

    // Only feather the actual outer edge. No independent left/right/top
    // opacity strips over the campsite or logo lettering.
    float sides = smoothstep(0.0, 0.028, UV.x)
        * smoothstep(0.0, 0.028, 1.0 - UV.x);
    float ends = smoothstep(0.0, 0.032, UV.y)
        * smoothstep(0.0, 0.055, 1.0 - UV.y);
    COLOR.a *= sides * ends;
}
