shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Each vertex stores the atlas tile ID in COLOR.r (0..1) and real repeats
// in UV. This avoids stretching or bleeding into neighbouring atlas tiles.
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;

void fragment() {
	float tile = floor(COLOR.r * 15.0 + 0.5);
	vec2 origin = vec2(mod(tile, 4.0), floor(tile / 4.0)) * 16.0;
	vec2 sample_at = (origin + vec2(0.5) + fract(UV) * 15.0) / 64.0;
	ALBEDO = texture(atlas, sample_at).rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
