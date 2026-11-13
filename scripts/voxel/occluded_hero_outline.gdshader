shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix;

// A slim gold silhouette appears only when a solid island blocks the
// isometric sightline. Terrain collision stays intact and no mountain faces
// are deleted merely to make the adventurer visible.
uniform vec4 outline_tint : source_color = vec4(0.96, 0.78, 0.40, 0.82);
uniform float outline_width = 0.075;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_tint.rgb;
	ALPHA = outline_tint.a;
}
