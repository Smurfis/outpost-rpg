# HUD V2 / Wallet, Last Gathered & status effects — Alpha review slice

Reference: ChatGPT Library `/Outpost/Handoff-2026-11-08/APPROVED_HUD_UI_V2_2026-11-08.png` and `OUTPOST_HUD_V2_APPROVED_IMPLEMENTATION_SPEC_2026-11-08.md`.

This change **does not** attempt the full artwork redraw. It implements data-backed utilities and the shared semi-transparent Quest/Last Gathered panel style. Existing damage text (player and enemy) remains driven by `scripts/vfx/pixel_feedback.gd` so it is not duplicated. Buff/debuff icons are initially hidden and only rendered via `hud.set_status_effects(real_effects)` once actual effects are wired to gameplay.

- World-harvest `Game.gather()` forwards only successfully granted items to the three-entry Last Gathered widget.
- Right of screen under minimap's clock; no new permanent overlaid buttons near smart-action wheel.
- Collapsed card retains header and offers 30 px button, with root touch interception.
- Status effects appear in the existing weapon-info line only when supplied; first five icons with `+N` overflow, debuffs before buffs, descriptive tooltips.
- Shared `hud_v2_components.gd` utility background can later be used for Settings/Changelog section cards.
- Existing wallet collapse button and floating joystick logic are not replaced in this first change. Full currency breakdown and icon art will be the next UX-approved slice.
- Overall HUD XP strip, character portrait, weapon labels and controls are otherwise untouched pending Android screenshot review.

This is **not approved artwork, not merged into Alpha and not an APK** until CI and Android checks prove it. No changes to Stable and no package installer permission changes.
