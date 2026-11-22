shader_type canvas_item;
render_mode unshaded;

// Warm sunset sky with broad stepped voxel-like cloud silhouettes.
// Intentionally no baked-in logo, words, stars, or portal art.
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	vec3 sky_top = vec3(0.24, 0.20, 0.36);
	vec3 sky_mid = vec3(0.65, 0.34, 0.41);
	vec3 sky_low = vec3(0.99, 0.60, 0.33);
	vec3 sky = mix(sky_top, sky_mid, smoothstep(0.08, 0.67, h));
	sky = mix(sky, sky_low, smoothstep(0.35, 0.88, h));
	float horizon = exp(-pow((h - 0.70) * 9.0, 2.0));
	sky += vec3(0.13, 0.075, 0.025) * horizon;
	vec2 grid = floor(UV * vec2(50.0, 32.0));
	float n = hash21(floor(grid * vec2(0.19, 0.42)));
	float stripe = sin(grid.x * 0.15 + n * 4.0) * 0.5 + 0.5;
	float cloud_y = 0.12 + 0.12 * stripe + 0.12 * n;
	float cloud = step(abs(grid.y / 32.0 - cloud_y), 0.045);
	cloud += step(abs(grid.y / 32.0 - (cloud_y + 0.20)), 0.025) * 0.48;
	cloud = clamp(cloud, 0.0, 1.0);
	vec3 cloud_color = vec3(0.94, 0.56, 0.53);
	sky = mix(sky, cloud_color, cloud * 0.28);
	float vignette = 1.0 - 0.19 * pow(abs(UV.x * 2.0 - 1.0), 2.0);
	COLOR = vec4(sky * vignette, 1.0);
}
