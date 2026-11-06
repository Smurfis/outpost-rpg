# Outpost — Alpha / Stable version selector
Date: 6 November 2026

## Implementation
The **Settings > Android Builds** panel offers a persistent **STABLE / ALPHA TEST** selector. Selecting a channel sets the release lookup target. **CHECK FOR UPDATES** obtains the newest published signed APK for that specific channel; **DOWNLOAD APK** opens its validated GitHub URL in the browser. Android requires explicit install approval.

This is *not* a live Git branch hot-swap: installed Android APKs cannot change their running GDScript to another branch. Both apps are separately installed and remain visible in the Android launcher.

### App identities and saves
- **Stable**: package `com.fivestarinteractive.outpost.preview`, tags `outpost-android-v<integer>`.
- **Alpha**: package `com.fivestarinteractive.outpost.alpha`, tags `outpost-alpha-v<integer>`, published as pre-releases.
- Independent package IDs create separate Android private save directories: **no automatic save transfer** and no need to uninstall Stable.
- Both APK exports use the same already provisioned signing keystore (but different package IDs). The package ID must remain stable *within* each channel for an in-place upgrade.
- Cross-channel lookup does not compare Android version codes between the two packages: every app's code only applies to itself.
- The updater verifies exact repo URL, channel tag format, version integer and APK asset filename. It never installs automatically.
- A selected channel persists in `user://outpost_ui.cfg`.

## Testing
- [x] Retain Alpha-specific signing/build workflow while inheriting latest stable game fixes.
- [x] Add Android channel selection in themed title Settings and per-channel release lookup.
- [x] Add automated tests proving no Stable/Alpha URL mix and previous download link invalidation.
- [ ] Verify the new Alpha APK compiles and the full headless Godot smoke check succeeds.
- [ ] Verify **two** launcher icons and installations coexist on a physical Android phone.
- [ ] Verify saves remain separate, Settings target persists, and downloads open Android installation confirmation.
- [ ] Promote this feature to Stable after the Alpha phone check so Stable can point to Alpha too.
- [ ] Optional future true launch-other-version shortcut requires an audited Android intent bridge; currently choose the installed app in Android launcher.

## Next Alpha visual and UX backlog
- Separate menu button transparency, selected gold emission and moving asterisks; remove baked permanent Play glow/shadow and static sparkles from original PNG artwork.
- A small readable parchment changelog scroll near the title corner, preferably linked to actual release data.
- Fix enchanting crafting modal locking out navigation and the exit button; test input flow, station switching, back and close.
- Replace old interim touch HUD with approved transparent player portrait/HP, sleek frames, bottom XP and silver-gold radial level ring, properly placed clickable square action icons, compact minimap and controls.
