# Goblin reoccupation foundation

The physical mine can report a deterministic Goblin Reoccupation event after the existing clear, reward and vacancy checks pass. The test-only trigger is `mine.trigger_reoccupation_for_test()` with `OUTPOST_TEST_MINE_LIFECYCLE=1`. It saves the event and sealed state together before placing the existing streamed timber barricades. The event has a stable site and event identity, a deterministic next-cycle seed, an objective and a persisted phase. The HUD displays the objective and a toast announces the disturbance.

The existing lifecycle trigger can advance the event from reported to ready for renewal. Both phases retain cycle-zero defeats and rewards. Repeated triggers fail without changing the event. A failed save restores the previous in-memory state.

Renewal is still outstanding. Cycle-one terrain, collision, camera cache invalidation, encounters, rewards, event completion and recovery across terrain publication have not been implemented. The current save validator deliberately accepts only cycle zero. No gameplay loop beyond the sealed and ready states should be inferred from this foundation.
