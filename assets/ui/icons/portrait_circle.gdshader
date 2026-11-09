shader_type canvas_item;
render_mode unshaded;

// A real circular mask on the existing original hero PNG. Its square-painted
// backing never covers the world outside the gold portrait ring.
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float circular_alpha = 1.0 - smoothstep(0.90, 0.99, length(p));
	COLOR.a *= circular_alpha;
}
