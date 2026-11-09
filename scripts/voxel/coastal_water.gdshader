shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Illustrated opaque pixel water for Android Compatibility.
// Keeps the existing 3D water mesh and Jess Hammer-inspired pixel grid.
// No alpha blend, reflection textures, screen sampling or extra draw calls.
uniform vec4 ocean_deep : source_color = vec4(0.025, 0.145, 0.360, 1.0);
uniform vec4 ocean_swell : source_color = vec4(0.040, 0.360, 0.630, 1.0);
uniform vec4 ocean_glint : source_color = vec4(0.370, 0.790, 0.950, 1.0);
uniform vec4 ocean_foam : source_color = vec4(0.750, 0.940, 0.980, 1.0);
uniform float wave_speed : hint_range(0.0, 3.0) = 0.72;
uniform float pixel_density : hint_range(1.0, 16.0, 1.0) = 3.0;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.72;
varying vec2 surface_world;

float cell_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Large legible blocks in world space, independent of camera and mesh UVs.
	// Quantisation prevents subpixel glitter and seams between terrain chunks.
	vec2 cell = floor(surface_world * pixel_density);
	vec2 p = (cell + 0.5) / pixel_density;
	float t = TIME * wave_speed;

	// Broad, slowly travelling blue patches instead of uniform stripes.
	float swells = sin(p.x * 0.78 + p.y * 0.37 + t * 0.70);
	swells += 0.60 * sin(p.y * 1.14 - p.x * 0.48 - t * 0.56);
	swells += 0.25 * sin((p.x + p.y) * 2.05 + t * 0.32);
	float water_band = step(-0.20, swells);
	vec3 pigment = mix(ocean_deep.rgb, ocean_swell.rgb, water_band * 0.82);

	// Broken cyan currents, with hashed gaps so they resemble clusters of
	// painted pixels rather than repeating full-length sinusoidal bars.
	float flow = sin(p.x * 1.35 - p.y * 0.70 - t * 1.35);
	float cross_flow = sin(p.y * 0.87 + p.x * 0.32 + t * 0.45);
	float streak = step(0.70, flow + cross_flow * 0.34);
	float gap = step(0.28, cell_hash(floor((cell + vec2(floor(t * 1.3), 0.0)) / 3.0)));
	float cyan = streak * gap * highlight_strength;
	pigment = mix(pigment, ocean_glint.rgb, cyan * 0.80);

	// Sparse glimmer pixels use discrete time so highlights pulse instead
	// of sliding continuously across every pixel on weak mobile hardware.
	float sparkle = step(0.976, cell_hash(floor(cell / 2.0) + vec2(floor(t * 1.1), 17.0)));
	float foam_mask = sparkle * step(0.1, swells) * highlight_strength;
	pigment = mix(pigment, ocean_foam.rgb, foam_mask * 0.84);

	ALBEDO = pigment;
	EMISSION = ocean_glint.rgb * cyan * 0.045;
	ROUGHNESS = 1.0;
	// Deliberately do not write ALPHA: the mobile terrain/water depth
	// ordering depends on the opaque pipeline.
}
