shader_type canvas_item;

// Circular portrait cutout: the original pixel adventurer art stays separate,
// with NO rectangular grey/black background or 9-slice matte.
void fragment() {
    vec4 portrait = texture(TEXTURE, UV);
    float circle = length((UV - vec2(0.5)) * 2.0);
    float mask = 1.0 - smoothstep(0.87, 0.96, circle);
    COLOR = vec4(portrait.rgb, portrait.a * mask) * COLOR;
}
