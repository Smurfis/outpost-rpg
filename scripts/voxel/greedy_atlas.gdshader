shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_draw_opaque;

// 64x64 source, a 4x4 grid of 16x16 painted atlas tiles.
// UV repeats in world-space; UV2.x selects the atlas tile. Each merged plane
// still shows individually repeated 16px artwork instead of a stretched tile.
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D coast_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
	float id = floor(UV2.x + 0.5);
	vec2 block = vec2(mod(id, 4.0), floor(id / 4.0));
	vec2 local_uv = fract(UV);
	vec2 atlas_uv = (block * 16.0 + vec2(0.5) + local_uv * 15.0) / 64.0;
	vec3 pigment = texture(atlas_texture, atlas_uv).rgb;
	if (id >= 16.0 && id <= 19.0) {
		// Four separate forest-to-beach textures in a 32px 2x2 atlas.
		// The same UV repeat as grass and dirt remains safe for merged
		// planes and for all eight isometric camera rotations.
		float coastal_id = id - 16.0;
		vec2 coastal_block = vec2(mod(coastal_id, 2.0), floor(coastal_id / 2.0));
		vec2 coastal_uv = (coastal_block * 16.0 + vec2(0.5) + local_uv * 15.0) / 32.0;
		pigment = texture(coast_texture, coastal_uv).rgb;
	}
	ALBEDO = pigment;
	// The voxel atlas is fully opaque RGBA. Writing ALPHA, even 1.0,
	// forces the transparent pipeline and makes the animated ocean render
	// over solid walkable ground on Android Compatibility.
	ROUGHNESS = 1.0;
}
