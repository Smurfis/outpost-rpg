shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D coast_texture : source_color, filter_nearest, repeat_disable;
uniform vec3 player_position;
uniform float visible_radius = 18.0;
varying vec3 at;
void vertex() { at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float id = floor(UV2.x + 0.5);
	vec3 pigment = COLOR.rgb;
	if (id >= 0.0) {
		vec2 local = fract(UV);
		if (id >= 16.0) {
			float tile = id - 16.0;
			vec2 block = vec2(mod(tile, 2.0), floor(tile / 2.0));
			pigment = texture(coast_texture, (block * 16.0 + 0.5 + local * 15.0) / 32.0).rgb;
		} else {
			vec2 block = vec2(mod(id, 4.0), floor(id / 4.0));
			pigment = texture(atlas_texture, (block * 16.0 + 0.5 + local * 15.0) / 64.0).rgb;
		}
		pigment *= UV2.y;
	} else if (id < -1.5) {
		// Same world-anchored, quantized blue ripple language as coastal water.
		// Only TIME changes: animation never rebuilds cached map geometry.
		vec2 p = (floor(at.xz * 3.0) + 0.5) / 3.0;
		float t = TIME * 0.72;
		float wave = sin(p.x * 0.78 + p.y * 0.37 + t * 0.70);
		wave += 0.60 * sin(p.y * 1.14 - p.x * 0.48 - t * 0.56);
		float band = step(-0.20, wave);
		pigment = mix(vec3(0.025,0.145,0.36), vec3(0.04,0.36,0.63), band * 0.82);
		float glint = step(0.85, sin(p.x * 1.35 - p.y * 0.7 - t * 1.35));
		pigment = mix(pigment, vec3(0.37,0.79,0.95), glint * 0.35);
	}
	float light = mix(0.55, 1.0, 1.0 - smoothstep(visible_radius - 2.0, visible_radius, distance(at.xz, player_position.xz)));
	ALBEDO = pigment * light;
}
