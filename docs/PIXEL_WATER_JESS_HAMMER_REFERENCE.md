# Pixel coastal water attribution and integration

Outpost's `scripts/voxel/coastal_water.gdshader` implements an original Godot 3D pixelated water adaptation, inspired by the visual approach of Jess Hammer's 2D Godot water VisualShader.

Upstream: https://github.com/jess-hammer/2d-pixel-water-shader-godot

The upstream demo is a Godot 4.4 Mono 2D VisualShader project and cannot be used directly as the 3D coastal material. Outpost preserves its existing 3D mesh, world-space coordinates, palette and opaque depth-tested rendering for Android Compatibility. No upstream shader assets or code were copied.

## Upstream license

MIT License

Copyright (c) 2024 jess-hammer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## QA checklist

- Open Alpha on Godot's Android Compatibility renderer and verify the ocean is visible.
- Confirm land still occludes ocean correctly at coast edges.
- Inspect animation and tile scaling while panning the camera.
- Compare FPS on a mobile device to the previous smooth coastal shader.
