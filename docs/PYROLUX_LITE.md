# PyroLux Lite in Outpost (Alpha)

**Status:** install-on-demand integration; effect presets are not yet wired into Outpost gameplay scenes.

PyroLux Lite 1.0.3 is usable in commercial games, but its license prohibits sharing the
raw addon source as a standalone pack or tool. Do **not** commit the extracted
`addons/pyrolux_fx/` or `pyrolux_lite_demo/` directories to this public repository.

## Install from the official Godot Asset Store

From the Outpost repository root, with Python 3.9 or later:

```sh
python3 tools/install_pyrolux_lite.py
```

If already downloaded, e.g. on Android or offline:

```sh
python3 tools/install_pyrolux_lite.py --archive /path/to/pyrolux_lite_store_v1.0.3.zip
```

The script checks the SHA-256 checksum of v1.0.3, unpacks the addon into
`addons/pyrolux_fx/` and optionally the demo into `pyrolux_lite_demo/`.
Use `--no-demo` to omit demo files. In Godot, open
`res://pyrolux_lite_demo/lite_demo.tscn` and run the current scene (F6).

## Using it in Outpost

Add the presets as scene children when ready:
- `res://addons/pyrolux_fx/presets/3d/fire_campfire.tscn`
- `res://addons/pyrolux_fx/presets/3d/fire_torch.tscn`
- `res://addons/pyrolux_fx/presets/3d/explosion_grenade.tscn`

Don't ship any gameplay scene with those references until the addon is also installed
in every export/build environment. The `pyrolux-installer-check.yml` workflow only
verifies installation; existing Android workflows must likewise run
`python3 tools/install_pyrolux_lite.py --no-demo` **before importing or exporting**
the Godot project.

The addon supports GL Compatibility on Godot 4.7.2, but Android performance
and visual quality still need device testing.
