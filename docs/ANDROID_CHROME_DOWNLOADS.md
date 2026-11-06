# Outpost Android — Open APK downloads in the standalone Chrome app

## Stable updater behaviour
When the player chooses **Settings → Check for Updates → Download APK** in the stable title menu, Outpost validates that the URL is an official APK asset under:
`https://github.com/Smurfis/outpost-rpg/releases/download/`.

The new `scripts/ui/android_external_browser.gd` launches an Android `ACTION_VIEW` intent with:
- the official GitHub APK URL as the data URI;
- `Intent.CATEGORY_BROWSABLE` to restrict receivers to browser-safe activities;
- package `com.android.chrome`, so an installed Google Chrome is preferred explicitly;
- `Intent.FLAG_ACTIVITY_NEW_TASK`, asking Android to open Chrome in its own task;
- **no Custom Tabs extras** or in-game WebView.

When Chrome is absent or cannot accept the intent, the helper falls back to Godot's `OS.shell_open` default-browser action. APK installation always requires Android's user confirmation; the game never installs an APK silently.

The helper accepts matching Stable and Alpha release filename/tag pairs but rejects any other host, unexpected paths, query parameters and mismatched APK filenames. The existing update source selector still determines which published release is offered.

## Limitations and verification
- This change only affects links opened **from Outpost's in-game Download button in newly built APKs**. It cannot change how the ChatGPT app, GitHub mobile UI or other apps open a tapped Markdown link; those apps have their own browser settings.
- A previously published APK (for example `Outpost-Android-v1047.apk`) cannot change retroactively. Merge the fix into `main` and use its next signed release.
- The JNI/Android runtime path cannot be exercised by headless Linux CI. The offline updater test covers validated URLs and trusted Chrome package; a **physical Android test** is still required to verify that Chrome opens as a separate task on the player's device and that the GitHub download completes.
- If the target phone doesn't have Chrome installed or enabled, fallback behaviour depends on the device's default browser settings.
