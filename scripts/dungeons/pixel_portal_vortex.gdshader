shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// Small local portal surface only; animated 32x40 pixel vortex.
// Keeps existing rarity colours and collision/entrance logic untouched.
uniform vec4 portal_color : source_color = vec4(0.65, 0.28, 1.0, 1.0);

void fragment() {
	vec2 pixel_uv = (floor(UV * vec2(32.0, 40.0)) + 0.5) / vec2(32.0, 40.0);
	vec2 p = (pixel_uv - vec2(0.5)) * vec2(1.0, 1.18);
	float radius = length(p);
	float a = atan(p.y, p.x);
	float vortex = sin(a * 3.0 - radius * 24.0 + TIME * 1.8);
	float braid = sin(a * 6.0 + radius * 32.0 - TIME * 2.7);
	float ring = smoothstep(0.37, 0.46, radius);
	float edge = 1.0 - smoothstep(0.46, 0.51, radius);
	float brightness = clamp(0.45 + vortex * 0.25 + braid * 0.15, 0.0, 1.0);
	vec3 tint = mix(portal_color.rgb * 0.28, portal_color.rgb * 1.65, brightness);
	tint = mix(tint, vec3(0.90, 0.72, 1.0), ring * 0.75);
	ALBEDO = tint;
	EMISSION = tint * (0.9 + ring * 1.2);
	ALPHA = edge * 0.94;
}
