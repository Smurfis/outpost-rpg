# Outpost — original pixel-fantasy UI source assets

This folder contains transparent UI frames, item cards, button states, and five original action icons in SVG and 128×128 transparent PNG. No copyrighted third-party artwork is included.

## Godot 4.7.x import

These files are already committed to the `feature/pixel-ui-crafting-overhaul` branch, so the integration agent needs **no external ZIP**. The SVGs are referenced from `scripts/hud.gd`.

For optional PNG panels use `NinePatchRect` or `StyleBoxTexture` with 16 px stretch margins for 128×128 panel files; the center of `transparent_wood_frame.png` is alpha transparent. For 192×64 buttons use 18 px horizontal and 12 px vertical margins. Use nearest-neighbour sampling; preserve icon aspect ratio. In Godot 4.7.2, import before testing textures.

The current `scripts/ui/outpost_skin.gd` uses `StyleBoxFlat` for a functional, screen-size-independent baseline. The PNG artwork is available to improve that theme and is **not yet fully applied to every control**.

Palette: parchment #e8d0a2; wood #79502d; ink #342416; brass #e3b75d; green #42663a; red #773a31.
