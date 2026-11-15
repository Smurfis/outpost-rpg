# PC controls and cross-platform interaction

The shared input controller resolves world hits against terrain and interaction geometry, plans a bounded route, and invokes the existing range-checked actions. WASD or the joystick cancels navigation. Short taps and clicks interact; touch drags orbit and long presses inspect. Right drag orbits on PC and the wheel zooms. The gold ring marks an accepted ground destination.

The bottom action row has three abilities, Interact, tool swap, potion and food. PC shortcuts are 1–3, T, Q and E. Tab focuses the nearest enemy; Interact and abilities use that focus. Space interacts, I opens inventory, C opens equipment, K opens skills, and Escape closes the active interface or opens the game menu. E is food. Movement automatically steps over low terrain and hops onto low ore/clay bundles; there is no manual jump key.

Resource bundles contain two or three nodes' worth of gathering actions and rewards. Harvestable scenery uses shared placement footprints. Shrimp pools appear in coastal shallows; craft the Shrimp Net from six fibre at the workbench and cook two shrimp at the campfire. Assign cooked shrimp to the food slot in inventory.

Validation is ongoing. The PC integration, gameplay smoke, RPG movement, coastal beach and portal tests pass headlessly. Android HUD reflow and chunk-streaming tests still assert the previous radial layout and batched decoration; assess and update those assertions along with device performance and touch QA before merging.
