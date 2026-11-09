shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_draw_opaque;

// Preserve atlas UV repeats across greedily merged terrain planes.
// UV2.x is tile id. UV2.y stores the face's upper world Y for walls,
// or -9999 for horizontal tops; no new geometry, textures or draw calls.
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D coast_texture : source_color, filter_nearest, repeat_disable;

float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float id = floor(UV2.x + 0.5);
	vec2 block = vec2(mod(id, 4.0), floor(id / 4.0));
	vec2 local_uv = fract(UV);
	vec2 atlas_uv = (block * 16.0 + vec2(0.5) + local_uv * 15.0) / 64.0;
	vec3 pigment = texture(atlas_texture, atlas_uv).rgb;
	if (id >= 16.0 && id <= 19.0) {
		float coastal_id = id - 16.0;
		vec2 coastal_block = vec2(mod(coastal_id, 2.0), floor(coastal_id / 2.0));
		vec2 coastal_uv = (coastal_block * 16.0 + vec2(0.5) + local_uv * 15.0) / 32.0;
		pigment = texture(coast_texture, coastal_uv).rgb;
	}
	// Rich, earth-coloured exposed soil. Small, stable pixel clusters are
	// computed from world-space UV, avoiding noisy subpixel shimmer on mobile.
	if (id == 3.0 && UV2.y > -1000.0) {
		vec2 px = floor(UV * 16.0);
		float grain = pixel_hash(floor(px / 3.0));
		pigment *= mix(0.82, 1.10, grain);
		// Irregular overhanging grass fringe along the upper edge of a soil
		// cliff. It follows the true wall top even on merged vertical faces.
		float fringe = (pixel_hash(vec2(floor(UV.x * 9.0), floor(UV2.y * 7.0))) - 0.5) * 0.13;
		if (UV.y > UV2.y - 0.14 - fringe) {
			vec2 grass_uv = (vec2(0.5) + local_uv * 15.0) / 64.0;
			vec3 grass = texture(atlas_texture, grass_uv).rgb;
			pigment = mix(pigment, grass * 0.88, 0.92);
		}
	}
	ALBEDO = pigment;
	ROUGHNESS = 1.0;
}
