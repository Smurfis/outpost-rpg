# Dungeon connector seam repair

This branch stacks on PR #14, with no changes to the existing title, pixel HUD, crafting or player controls. It fixes a known falling-off-the-map bug at the join between procedurally generated rooms.

## Geometry
- `STEP` reduced from 14 to 13 units. Adjacent door walls are now only one unit apart.
- Every linked room pair receives a **4.6 × 6.6** continuous bridge deck and physical floor, overlapping both original room floors.
- Every bridge has a pair of **1.45-unit-high side parapets**, including collision, to prevent moving diagonally off the side of the door join.
- The centre KayKit floor tile remains as decorative detail; the new stone deck fills its previously exposed sides.

## Verification
`tests/dungeon_seams.gd` raycasts multiple points along every generated passage and scans barriers at both edges across deterministic rarity floors. This is an automated physics regression, not a physical Android device certification.

## Limitations
The existing dungeon room templates still need a distinct visual/archetype pass. The bridge art is simple stone, meant to solve collision immediately without inventing missing painterly pixel artwork; detailed variations can follow. No dungeon save-schema or progression change.
