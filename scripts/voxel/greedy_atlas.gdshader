shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_draw_opaque;

// Preserve atlas UV repeats across greedily merged terrain planes.
// UV2.x is tile id. UV2.y stores the face's upper world Y for walls,
// or -9999 for horizontal tops; no new geometry, textures or draw calls.
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D coast_texture : source_color, filter_nearest, repeat_disable;

// Off by default: starter Fields, ordinary dungeons, maps and all existing
// users of the shared atlas render exactly as before. The remote islands
// duplicate the material and supply their own player/camera uniforms.
uniform bool island_cutaway_enabled = false;
uniform bool island_cave_mode = false;
uniform vec3 island_cutaway_focus = vec3(0.0);
uniform vec3 island_cutaway_eye = vec3(0.0);
// Maximum horizontal span is clamped to the 3 x 3 voxel grid around hero.
uniform float island_cutaway_radius = 1.5;
varying vec3 island_world_position;
varying vec3 island_world_normal;

void vertex() {
	island_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	island_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float pixel_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Minecraft/Diorama-style cutaway: lift ONLY a few blocks immediately
	// above the adventurer. The previous eye-to-player corridor cut a long
	// diagonal swathe across the mountain and revealed the blue ocean.
	// The roof material is separate from all walkable ground/cliff walls.
	if (island_cutaway_enabled && island_cave_mode) {
		// Only horizontal, overhead cavern roof faces. Cave floors and
		// vertical stone walls always remain visible and collidable.
		bool roof_face = abs(island_world_normal.y) > 0.88;
		bool overhead = island_world_position.y > island_cutaway_focus.y + 1.25;
		// Snap the clipping footprint to the one-metre voxel grid to
		// avoid shimmering or cutting into partial cliffside triangles.
		vec2 roof_cell = floor(island_world_position.xz - vec2(0.001));
		vec2 player_cell = floor(island_cutaway_focus.xz);
		vec2 cell_distance = abs(roof_cell - player_cell);
		float max_cells = min(floor(island_cutaway_radius), 1.0);
		bool directly_above = all(lessThanEqual(cell_distance, vec2(max_cells)));
		if (roof_face && overhead && directly_above) {
			discard;
		}
	}
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
		pigment *= mix(0.79, 1.12, grain);
		// A low-frequency ochre soil seam adds readable layered earth on
		// exposed faces without a second texture or any terrain mesh changes.
		float strata = fract(UV.y * 0.83 + floor(UV.x * 0.45) * 0.14);
		pigment *= mix(1.0, 0.87, step(0.86, strata));
		// Irregular overhanging grass fringe along the upper edge of a soil
		// cliff. It follows the true wall top even on merged vertical faces.
		float fringe = (pixel_hash(vec2(floor(UV.x * 9.0), floor(UV2.y * 7.0))) - 0.5) * 0.13;
		if (UV.y > UV2.y - 0.19 - fringe) {
			vec2 grass_uv = (vec2(0.5) + local_uv * 15.0) / 64.0;
			vec3 grass = texture(atlas_texture, grass_uv).rgb;
			pigment = mix(pigment, grass * 0.88, 0.92);
		}
	}
	ALBEDO = pigment;
	ROUGHNESS = 1.0;
}
