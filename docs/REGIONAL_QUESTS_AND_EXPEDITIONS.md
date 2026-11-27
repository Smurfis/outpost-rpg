# Regional quests and expeditions — design and initial contracts

World generation must provide safe, meaningful giver locations as well as objectives. This supplements, not replaces, the existing starter quest.

## Initial implementation

Default regional plans expose deterministic quest_anchors records. Each identifies a nearby landmark, a unique off-road standing cell, an adjacent road approach, a role, and an objective location hint. Anchors avoid building footprints, caves, crops, scenery and other contacts. The generated road graph must connect the approach to the hub. Hub contacts can coordinate expeditions. If no suitable cell exists, omit the contact rather than place an inaccessible NPC. The hint is not an actual spawned objective.

regional_adventure_policy.gd provides data-only category and reward-preview functions. Local quests pay the supplied base reward. Expeditions pay exactly 5/2 of that base, integer values rounded half-up. A verified route is required. Travel above a configurable local budget, or a route requiring a remote journey, is an expedition. The budget is intentionally not tuned yet: use realistic traversal costs, not straight-line distance; distinguish verified land, sea/transport, and underground access. No live payout is changed.

## Future dynamic quest generation

1. Bind eligible role-specific contacts and objectives to stable site IDs, level and encounter availability.
2. Choose nearby reachable objectives for ordinary quests. Use bounded road/network path cost and actual objective entrance; do not infer cave traversal from the cave approach alone. A contact may offer multiple tasks, and objectives may have several candidates. Prefer the nearest suitable contact, not necessarily the nearest Euclidean position.
3. Allow expedition coordinators to offer a deliberately distant but reachable objective, with clear destination, transport requirements, recommended level, expected journey and 2.5x rewards. Distance and combat difficulty are independent. Do not automatically turn every cross-island trip into an expedition until travel budgets are playtested; the policy remote_travel flag represents a deliberate long-range route classification.
4. Pin offered objectives, route classification, base reward and multiplier at acceptance. Regenerating chunks, moving givers, or taking detours must not alter the reward or duplicate completion.
5. Persist accepted quest instances and claim state through save/reload; use authoritative, idempotent completion and payout. Support a local hand-in or expedition return to a coordinator, depending on design.
6. Proposed multiplier scope: XP and ordinary currency/reputation where appropriate, not unique item quantities or guaranteed rare drops. Confirm reward economy before implementing payouts. Provide meaningful expedition encounters and avoid rewarding distance alone.
7. Stream NPCs with their owning chunks but persist their identities independently. Add quest symbols, dialogue, map markers respecting fog-of-war, journal categories and objective tracking. No PC-only creator controls in the Android RPG.

No NPCs, dynamic objectives, live rewards, dialogue, quest journal or APK are implemented by this iteration. Anchor placement and policy have regression coverage pending runtime results. Existing Alpha/stable and starter quest remain untouched.
