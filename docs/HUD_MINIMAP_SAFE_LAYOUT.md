# HUD placement refinement — minimap-safe menu and hidden overlays

Feature branch: `feature/minimap-safe-hud-placement`  
Base: current `main`, after UI PR #45.

## Approved layout goals

- Bag and Gear are **not persistent gameplay sidebars**. They are separate modals, opened on request, closed when done. Neither opening them nor selecting them moves the virtual joystick, Interact button, three skills, consumables, or camera touch zones.
- Move the existing day/night display and consolidated top-right menu button **under the reserved minimap location**. The current game HUD has no implemented minimap; do not render a fake one or move all the existing buttons to accommodate imaginary tiles.
- When the single menu button is tapped/held, reveal Craft, Gear, Co-op, Skills, Journal and Settings in a compact **3 columns × 2 rows** dropdown. The dropdown stays between the minimap footer and the ability arc, not across abilities or map.
- Retain exactly three unlocked combat skills and the two real owned consumable quick slots; keep the smart tool picker and floating/fixed joystick modes unchanged.
- No separate gameplay Settings cog is needed: Settings is available through the dropdown.

## Normalized layout regions

At a 1280×720 baseline, the intended regions are:
- Future minimap: top-right, x≈0.83–0.99, y≈0.02–0.31 (**reserved, not yet rendered**).
- Day/night footer + menu: x≈0.81–0.99, y≈0.32–0.40.
- Expanded options: x≈0.68–0.99, y≈0.40–0.58, closed by default.
- Three combat skills: y≥0.60. The expanded options must end above that line.

## Modified files

- `scripts/hud.gd` — repositioned existing real clock, menu, six option buttons and optional dropdown; left Bag/Gear modal and gameplay controls otherwise intact.
- `tests/mobile_hud_wallet_floating_joystick.gd` — asserts the minimap footer positioning, menu flyout not covering ability arcs, modal-only Bag/Gear, unchanged joystick/skill positions.

## QA

Run full `.github/workflows/godot-smoke.yml` and inspect Android screenshots at 16:9 and taller landscape aspect ratios. Confirm tap/hold menu, Bag and Gear overlays, close/Back, day/night visibility, and three ability interactions still work. The illustration in the conversation is visual guidance, not a screenshot of shipped gameplay.
