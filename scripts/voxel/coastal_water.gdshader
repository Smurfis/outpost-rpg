shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// 3D Android-compatible pixel-water adaptation inspired by Jess Hammer's
// 2D pixel water VisualShader (MIT, copyright 2024 jess-hammer).
// https://github.com/jess-hammer/2d-pixel-water-shader-godot
// Intentionally opaque: avoids transparency sorting and depth issues on mobile.
uniform vec4 ocean_deep : source_color = vec4(0.070, 0.250, 0.365, 1.0);
uniform vec4 ocean_swell : source_color = vec4(0.210, 0.470, 0.540, 1.0);
uniform vec4 ocean_glint : source_color = vec4(0.430, 0.690, 0.700, 1.0);
uniform float wave_speed = 0.9;
uniform float pixel_density : hint_range(1.0, 16.0, 1.0) = 5.0;
varying vec2 surface_world;

void vertex() {
    surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    // Quantising world-space sampling creates stable, chunky pixel shapes
    // across the existing ocean mesh and avoids UV seams between terrain chunks.
    vec2 pixel_world = (floor(surface_world * pixel_density) + vec2(0.5)) / pixel_density;
    float t = TIME * wave_speed;
    float ripples = sin(pixel_world.x * 1.5 + pixel_world.y * 0.45 + t);
    ripples += 0.55 * sin(pixel_world.y * 2.35 - pixel_world.x * 0.62 - t * 1.17);
    float broad = step(0.05, ripples);
    float streaks = step(0.88, sin(pixel_world.x * 2.7 + pixel_world.y * 1.15 + t * 1.45));
    vec3 hue = mix(ocean_deep.rgb, ocean_swell.rgb, broad);
    ALBEDO = mix(hue, ocean_glint.rgb, streaks * 0.22);
    EMISSION = ocean_glint.rgb * streaks * 0.035;
    // Do not write ALPHA: retain opaque depth-tested water on Android Compatibility.
}
