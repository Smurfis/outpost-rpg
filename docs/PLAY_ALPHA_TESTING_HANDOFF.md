# Outpost Alpha on Google Play: publishing handoff (8 Nov 2026)

**State**: The repository's Alpha workflow publishes `Outpost-Alpha-vNNNN.apk` as a GitHub prerelease. That is **not** a Google Play internal testing release and does **not** submit anything for Google Play review or Play Protect classification. This project has no GitHub workflow for Google Play publishing and the connected tooling in this chat does not have Play Console credentials or an authorised upload action. No Play Console release or internal sharing link has been generated here.

## Security restriction in the app

`scripts/ui/android_updater.gd` intentionally has `ALPHA_DOWNLOADS_PAUSED = true` and `APK_INSTALLS_PAUSED = true` because v1012 previously triggered a Play Protect warning (issue #69). Do **not** remove this gate just to suppress an installer review. `docs/ANDROID_UPDATER_SETUP.md` documents permanent signing, package name, version codes and Android update behaviour.

## Safe publication options

1. **Google Play internal testing** (preferred for an app installed and updated *through Google Play*). In Play Console, create an internal testing track, authorise testers, build a release AAB from the correct application ID with a stable upload key/Play App Signing, submit it to the internal track and verify the Play-installed package can actually update the installed app without losing saves. New Play apps generally require AAB for publishing.
2. **Google Play internal app sharing** is a fast, link-only test distribution option. It accepts APK/AAB uploads, but Google re-signs them under an Internal App Sharing key. **Do not assume this will update the GitHub-signed Alpha in place.** Internal sharing uploads cannot be promoted directly into Play testing/production releases. Links expire and testers must enable the feature.
3. **GitHub Alpha APK** remains the independent, permanently signed sideload-testing route. Android may still require explicit installation confirmation or flag APKs for review. It is incorrect to claim a Play review is solved by an APK version bump, UI change or different hosting link.

## Before any actual Play upload

- Confirm Play Console ownership/access, developer account status, registered application ID, current Play App Signing certificate, package identity and whether a test track already exists.
- Confirm Android AAB export configuration, upload key and GitHub Actions secret identity without exposing the credentials in commits, chat or logs.
- Check for collisions with the existing `com.fivestarinteractive.outpost.preview` sideload package name and preserve saved game data.
- Only after these checks, set up a **separate** `play-internal` build and publishing workflow with explicit user approval of its track, rollout audience and credentials; do not mix it into automatically published GitHub Alpha.
- Test delivery and on-device install from an authorised Play test link before describing it as working.

Official guidance:
- https://support.google.com/googleplay/android-developer/answer/9844679?hl=en
- https://support.google.com/googleplay/android-developer/answer/9845334?hl=en
