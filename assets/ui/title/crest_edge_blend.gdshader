shader_type canvas_item;

// The approved crest PNG includes a *painted rectangular sky*. Even if its
// outside edge is faded, blue/purple sky to either side of the tent still
// overlays the title's separate landscape as an obvious opacity box.
// Chroma-key only the unmistakable blue/pink sky hues. Keep the original
// brown/gold tent, lettering, flames, leaves and stone colour unchanged.
// Read COLOR (the already composited texture) directly: sampling TEXTURE
// again would double-darken the wordmark.
void fragment() {
	vec3 rgb = COLOR.rgb;
	float blue_sky = smoothstep(0.025, 0.13, rgb.b - rgb.r)
			* smoothstep(0.01, 0.10, rgb.b - rgb.g)
			* smoothstep(0.18, 0.48, rgb.b);
	float pink_sky = smoothstep(0.06, 0.17, rgb.r - rgb.g)
			* smoothstep(0.04, 0.16, rgb.b - rgb.g)
			* smoothstep(0.34, 0.62, rgb.r)
			* smoothstep(0.21, 0.45, rgb.b);
	// Protect the wordmark / carved stone band from any similarly coloured
	// purple pixels; the loose sky is primarily above and below that band.
	float exposed_sky_area = max(1.0 - smoothstep(0.43, 0.57, UV.y),
			smoothstep(0.82, 0.95, UV.y));
	float side_sky_area = max(1.0 - smoothstep(0.10, 0.36, UV.x),
			smoothstep(0.64, 0.90, UV.x));
	float sky = clamp(max(blue_sky, pink_sky), 0.0, 1.0);
	COLOR.a *= 1.0 - sky * max(exposed_sky_area, side_sky_area) * 0.98;

	// A tiny outer feather avoids a hard square edge even on the painted
	// top/bottom border pixels. Never attenuate COLOR.rgb.
	float left_fade = smoothstep(0.0, 0.036, UV.x);
	float right_fade = smoothstep(0.0, 0.036, 1.0 - UV.x);
	float top_fade = smoothstep(0.0, 0.035, UV.y);
	float bottom_fade = smoothstep(0.0, 0.070, 1.0 - UV.y);
	float edge_alpha = min(min(left_fade, right_fade), min(top_fade, bottom_fade));
	COLOR.a *= edge_alpha;
}
