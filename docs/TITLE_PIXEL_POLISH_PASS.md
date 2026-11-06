# Outpost Home Screen — Pixel-fantasy polish pass

**Feature:** `feature/title-screen-pixel-polish` (branched from current `main` after the title screen, Android updater, loading gateway, voxel world and HUD changes).

## Approved source composition

The original approved 1536×864 pixel-art concept remains the visual North Star. It contains:
- Warm lavender/pink/orange **sunset valley** and layered pixel clouds.
- Camp on the **left**: rustic canvas tent, watchtower, flags, barrel, lanterns, fire, book, map and compass.
- On the **right**: cliff ruins, waterfall, winding river and a purple **dungeon portal**.
- At the **top centre**: ornate *Outpost* wood/stone tent crest with rope, greenery, red pennants and campfire.
- Four **separate real buttons** in the middle: gold Play, dark wooden Continue, grey stone Settings, pale parchment Quit.
- Angled warm-yellow rotating splash lettering, framed edges/pennants and a small version badge.

**Do not flatten the reference screenshot into the menu.** That would create unclickable baked-in buttons, duplicated version text and scaled fonts. The screenshot is a design target; independent art layers and runtime Godot Controls remain required. The reference's old `v0.1.0-dev` must never replace the live project version.

## Implemented in this pass

- **Additional transparent light layer**: `assets/ui/title/title_lights.svg`, which adds glow around the approved composition's hanging lanterns, campfire, waterfall and dungeon portal. It overlays the existing self-contained `title_backdrop.svg` and is *not* a replacement for the illustrated scene.
- **Subtle animated light breathing** with an inexpensive opacity oscillation, automatically static when the existing reduced-motion preference is enabled. The overlay ignores pointer/touch input.
- **Title crest details**: compact flames, stones, camp ropes, canvas patch and pixel-fantasy greenery added to the existing separate textless `outpost_logo_vector.svg`.
- **Rustic tip plaque**: `tip_panel.svg` gains wood grain, brass edging, rivets and leaf accents. It stays separate from its live editable text.
- **29 short rotating adventure tips** including torch/shield off-hand tradeoff, crafting, stronger equipment, dungeons, camera, Fields exploration, inventory load and an intentional rare personal campfire easter egg.
- **11 playful yellow rotating slogans** while retaining the approved first line, “Now with deeper dungeons!”
- **Tip accessibility**: tips start at a different entry each session, rotate about every nine seconds, gently fade between lines unless reduced motion is selected, and their entire plaque hides when tips are disabled.
- **Preserved integrations**: Android updater and update banner, Play/Continue save logic, progressive world-loading gateway, settings and platform quit control.
- Dedicated `tests/title_pixel_polish_smoke.gd` and GitHub Actions check for artwork import, node hierarchy, tips, slogans, animations and interactive buttons.

## Source-owned assets

All assets required by this pass are **committed in this Git branch**: existing `assets/ui/title/title_backdrop.svg`, `outpost_logo_vector.svg`, `title_frame.svg`, button plaques/icons, banner, company mark, version plaque, modified tip plaque and new light overlay. No ZIP from ChatGPT is needed. The final approved pixel-perfect PNG art is a later replacement of these layers, not silently bundled here.

## Manual Android checks

1. Start Godot 4.7.2 in Android landscape and verify Five Star ident → illustrated Outpost title → Play/Continue → loading screen → game.
2. Check main logo and yellow splash have no overlap at 16:9 and slightly wider phone aspect ratios.
3. Check background/overlay alignment with campfire, portal, lantern and waterfall; adjust overlay coordinates if the current backdrop shifts in later art changes.
4. Watch cycling tips: ensure long lines aren't clipped, full plaque hides with tips off, and there is no flashing with reduced motion.
5. Verify banner, button plaque/icon and version label sizes; check touch focus, Continue save validation, updater settings and Android Back input.
6. Monitor 60 FPS target or device-specific budget; ambience should remain a single 2D texture without expensive shaders or continuously created particles.
7. Compare to the approved image before accepting final visual quality.

## Future TODO (not yet completed)

- [ ] Bring the approved illustrative **pixel-art source** into Git as **individual real alpha assets**: clean UI-free backdrop, crest, separated menu plaques without baked text, icons, tips, camp/portal particle sprites. Do not import the flattened mock-up as a final background.
- [ ] Author a coherent **pixel-font** family that is readable on small landscape phones; audit licensed embedding and kerning for long translations.
- [ ] Add optional separate low-cost waterfall/campfire animation sprite sheets, with reduced-motion alternative.
- [ ] Make atmospheric overlays retargetable if the background composition is replaced.
- [ ] Validate real Android screenshots and render performance before approving the feature merge.

The approved composition is preserved as the reference; this is a **functional/art polish increment**, not a claim that the original fully painted mock-up is already pixel-perfect in Godot.
