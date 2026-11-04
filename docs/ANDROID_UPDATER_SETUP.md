# Outpost Android in-place updates and permanent signing

## What changed
The old workflow ran `keytool -genkeypair` on every GitHub Actions run. That created an unrelated Android signing identity each time. Android refuses to install a same-package APK if the certificate does not match; users had to uninstall and risk losing local progress. **Never restore that per-run signing behavior.**

The new app uses the SAME package name `com.fivestarinteractive.outpost.preview`, a permanent keystore stored only in GitHub Actions secrets, and a monotonically increasing `version/code`. It embeds that build code as `application/config/android_build_code` in `project.godot` during the build. The version label remains `0.5.0-dev` until intentional game version bumps.

The in-game title Settings contains **Check for Android Updates**. It queries the public GitHub releases API for tags of the form `outpost-android-v<number>`, accepts only APK assets under this repository's GitHub release URLs, compares against the installed build code, and opens the verified APK URL in the device browser when the player taps Download.

**Android still requires the person installing the APK to approve the installation.** This is an in-app update checker / download shortcut, not a silent install or Google Play In-App Updates. A fully embedded download + PackageInstaller prompt would additionally require a Godot Android plugin with FileProvider/Intent APIs. Do not try to silently elevate installer privileges or load unverified URLs.

## One-time signing setup — required before shipping the first compatible APK

On a trusted computer with Java 17+ installed, run a command prompt (PowerShell or terminal):

```sh
keytool -genkeypair -keystore outpost-android-update.jks -alias outpostpreview -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Outpost, O=Five Star Interactive, C=GB"
```

Choose a long, unique password when prompted. For this Godot build configuration the key password should be identical to the keystore password. **Do not paste any secret or private key into ChatGPT or a public issue, commit or message.**

Encode the file into base64, then copy the entire single-line text. Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path ".\outpost-android-update.jks"))) | Set-Clipboard
```

Go to **https://github.com/Smurfis/outpost-rpg/settings/secrets/actions** and create the following repository Actions secrets:

1. `OUTPOST_ANDROID_KEYSTORE_B64`: entire base64 value from the clipboard
2. `OUTPOST_ANDROID_KEY_ALIAS`: `outpostpreview`
3. `OUTPOST_ANDROID_KEY_PASSWORD`: the secret password entered when creating the keystore

Keep a secure **offline backup** of both the `.jks` file and its password. If you lose them, Android cannot install subsequent APKs over apps signed with that key.

After setting the secrets, merge the updater branch through PR review and run **Export Outpost Android updateable APK** from Actions (or push/merge to main).

The workflow deliberately fails with an actionable message when the secrets are absent or invalid; it will **not** make a disposable fallback key. On successful main builds it:

- Signs with the permanent keystore.
- Sets Android `version/code` and embedded `android_build_code` to `1000 + github.run_number`, so update codes are strictly increasing across main builds of that workflow.
- Retains the same `package/unique_name` and launcher artwork.
- Publishes an APK under a unique tag `outpost-android-v<code>`, so the built-in update checker can discover it.
- Validates the package archive and actual launcher image resources.

## The final migration from earlier APKs
The previously issued Android test builds, including `Outpost-v05-Unified-Android.apk`, were each signed with ephemeral certificates. The first APK signed with this new permanent key **cannot** update them in place, even if it has a higher version code. Back up progress before uninstalling that old preview, install the new permanent-key build **once**, and thereafter install newer versions over the existing Outpost app (without uninstalling).

Godot's release keys are different from Google Play App Signing: if later distributing through Play, plan your signing identity and store channel carefully; do not accidentally change signing certificates or package identifiers.

## CI and acceptance checks
- Run `tests/android_updater.gd` to verify trusted-version selection, malicious URL rejection, installed-version comparison and the title Settings button.
- Title Settings **Check for Android Updates** must show no update when current, and a download button on a newer published release.
- Confirm installed `version/code` increases by at least 1 between builds.
- On a physical Android phone, install build N, save game, install N+1 from its APK and confirm the game saves persist. The Godot headless smoke suite cannot verify Android's PackageManager update behavior.
