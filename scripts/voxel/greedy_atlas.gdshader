shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// 64x64 source, a 4x4 grid of 16x16 painted atlas tiles.
// UV repeats in world-space; UV2.x selects the atlas tile. Each merged plane
// still shows individually repeated 16px artwork instead of a stretched tile.
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	float id = floor(UV2.x + 0.5);
	vec2 block = vec2(mod(id, 4.0), floor(id / 4.0));
	vec2 local_uv = fract(UV);
	vec2 atlas_uv = (block * 16.0 + vec2(0.5) + local_uv * 15.0) / 64.0;
	vec4 pixel = texture(atlas_texture, atlas_uv);
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
	ROUGHNESS = 1.0;
}
