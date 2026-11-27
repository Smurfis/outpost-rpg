shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Illustrated opaque pixel water for Android Compatibility.
// Keeps the existing 3D water mesh and Jess Hammer-inspired pixel grid.
// No alpha blend, reflection textures, screen sampling or extra draw calls.
uniform vec4 ocean_deep : source_color = vec4(0.025, 0.145, 0.360, 1.0);
uniform vec4 ocean_swell : source_color = vec4(0.040, 0.360, 0.630, 1.0);
uniform vec4 ocean_glint : source_color = vec4(0.370, 0.790, 0.950, 1.0);
uniform vec4 ocean_foam : source_color = vec4(0.750, 0.940, 0.980, 1.0);
// Shallow water uses flat per-cell shoreline colour, not a screen-space mask.
uniform vec4 ocean_shallow : source_color = vec4(0.080, 0.670, 0.790, 1.0);
uniform float wave_speed : hint_range(0.0, 3.0) = 0.72;
uniform float pixel_density : hint_range(1.0, 16.0, 1.0) = 3.0;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.72;
uniform float deep_opacity : hint_range(0.0,1.0) = 0.88;
uniform float shallow_opacity : hint_range(0.0,1.0) = 0.52;
uniform bool island_land_mask_enabled = false;
uniform sampler2D island_land_mask : filter_nearest, repeat_disable;
uniform float island_mask_half_extent = 384.0;
varying vec2 surface_world;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// The distant ocean spans the remote islands. Never draw it inside land:
	// terrain cutaways can otherwise expose the ocean from below a mountain.
	if (island_land_mask_enabled) {
		vec2 cell = floor(surface_world);
		vec2 mask_uv = (cell + vec2(island_mask_half_extent + 0.5)) / (2.0 * island_mask_half_extent);
		if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThan(mask_uv, vec2(1.0))) && texture(island_land_mask, mask_uv).r > 0.5) discard;
	}
	// Large legible blocks in world space, independent of camera and mesh UVs.
	// Quantisation prevents subpixel glitter and seams between terrain chunks.
	vec2 cell = floor(surface_world * pixel_density);
	vec2 p = (cell + 0.5) / pixel_density;
	float t = TIME * wave_speed;

	// Broad, slowly travelling blue patches instead of uniform stripes.
	float ripples = sin(p.x * 0.78 + p.y * 0.37 + t * 0.70);
	ripples += 0.60 * sin(p.y * 1.14 - p.x * 0.48 - t * 0.56);
	ripples += 0.25 * sin((p.x + p.y) * 2.05 + t * 0.32);
	float water_band = smoothstep(-0.95,0.95,ripples);
	vec3 pigment = mix(ocean_deep.rgb, ocean_swell.rgb, water_band * 0.82);
	// Shallow tint is constant across both triangles of each streamed water cell.
	// Bright water has depth and remains opaque (Android Compatibility-safe).
	float shallow = clamp(COLOR.r, 0.0, 1.0);
	pigment = mix(pigment, ocean_shallow.rgb, shallow * (0.43 + water_band * 0.24));

	// Broken cyan currents, with hashed gaps so they resemble clusters of
	// painted pixels rather than repeating full-length sinusoidal bars.
	float flow = sin(p.x * 1.35 - p.y * 0.70 - t * 1.35);
	float cross_flow = sin(p.y * 0.87 + p.x * 0.32 + t * 0.45);
	float streak = step(0.70, flow + cross_flow * 0.34);
	float gap = step(0.28, cell_hash(floor((cell + vec2(floor(t * 1.3), 0.0)) / 3.0)));
	float cyan = streak * gap * highlight_strength * (0.65+0.35*sin(t*1.7+p.x*0.2));
	pigment = mix(pigment, ocean_glint.rgb, cyan * 0.80);

	// Sparse glimmer pixels use discrete time so highlights pulse instead
	// of sliding continuously across every pixel on weak mobile hardware.
	float sparkle = step(0.976, cell_hash(floor(cell / 2.0) + vec2(floor(t * 1.1), 17.0)));
	float foam_mask = sparkle * step(0.1, ripples) * highlight_strength;
	pigment = mix(pigment, ocean_foam.rgb, foam_mask * 0.84);

	ALBEDO = pigment;
	EMISSION = ocean_glint.rgb * cyan * 0.045;
	ROUGHNESS = 1.0;
	// Surface tint remains animated; reveal actual seabed in shallow water.
	ALPHA = clamp(mix(deep_opacity,shallow_opacity,shallow)+cyan*0.10+foam_mask*0.08,0.0,1.0);
}
