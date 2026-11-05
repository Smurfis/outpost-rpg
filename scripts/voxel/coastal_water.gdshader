shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Two moving low-frequency colour bands. No reflections, screen copies,
// subdivision or post-processing, suitable for Android GL Compatibility.
uniform vec4 ocean_deep : source_color = vec4(0.070, 0.250, 0.365, 1.0);
uniform vec4 ocean_swell : source_color = vec4(0.210, 0.470, 0.540, 1.0);
uniform vec4 ocean_glint : source_color = vec4(0.430, 0.690, 0.700, 1.0);
uniform float wave_speed = 0.9;
varying vec2 surface_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = TIME * wave_speed;
	float ripples = sin(surface_world.x * 1.5 + surface_world.y * 0.45 + t);
	ripples += 0.55 * sin(surface_world.y * 2.35 - surface_world.x * 0.62 - t * 1.17);
	float broad = smoothstep(-0.95, 1.25, ripples);
	float streaks = smoothstep(0.72, 1.15, sin(surface_world.x * 2.7 + surface_world.y * 1.15 + t * 1.45));
	vec3 hue = mix(ocean_deep.rgb, ocean_swell.rgb, broad);
	ALBEDO = mix(hue, ocean_glint.rgb, streaks * 0.21);
	EMISSION = ocean_glint.rgb * streaks * 0.035;
	// Intentionally no ALPHA write. This is an opaque water surface;
	// the Compatibility renderer must use its depth buffer so terrain
	// remains visible in front of ocean, even on Adreno/Mali devices.
}
