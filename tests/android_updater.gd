extends SceneTree
## Deterministic, offline updater checks: never download an APK in CI.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, explanation: String) -> void:
	if condition:
		print("PASS ANDROID UPDATER: " + explanation)
	else:
		failures += 1
		push_error("FAIL ANDROID UPDATER: " + explanation)

func _release(code: int, url: String, is_draft: bool = false) -> Dictionary:
	var tag: String = "outpost-android-v%d" % code
	return {
		"tag_name": tag,
		"draft": is_draft,
		"html_url": "https://github.com/Smurfis/outpost-rpg/releases/tag/" + tag,
		"assets": [{
			"name": "Outpost-Android-v%d.apk" % code,
			"browser_download_url": url
		}]
	}

func _run() -> void:
	var updater_script = load("res://scripts/ui/android_updater.gd")
	check(updater_script != null, "Updater script imports")
	if updater_script == null:
		quit(1)
		return
	var browser_script = load("res://scripts/ui/android_external_browser.gd")
	check(browser_script != null, "External Chrome launcher script imports")
	if browser_script != null:
		check(str(browser_script.CHROME_PACKAGE) == "com.android.chrome", "Android APK downloads explicitly prefer Google Chrome")
		check(browser_script.is_trusted_release_apk("https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v1047/Outpost-Android-v1047.apk"), "Current Stable APK URL is accepted")
		check(browser_script.is_trusted_release_apk("https://github.com/Smurfis/outpost-rpg/releases/download/outpost-alpha-v1005/Outpost-Alpha-v1005.apk"), "Alpha APK URLs are accepted for future channel support")
		check(not browser_script.is_trusted_release_apk("https://evil.example/Outpost-Android-v1047.apk"), "Untrusted APK download hosts are rejected")
		check(not browser_script.is_trusted_release_apk("https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v1047/Outpost-Android-v1047.apk?redirect=evil"), "Query or redirect injections are rejected")
		check(not browser_script.is_trusted_release_apk("https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v1047/Outpost-Alpha-v1047.apk"), "Stable and Alpha filenames cannot be swapped")
		check(browser_script.open_apk_in_browser("https://evil.example/app.apk") == ERR_INVALID_PARAMETER, "Invalid downloads are refused before any browser is opened")
	var older: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v12/Outpost-Android-v12.apk"
	var newer: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v15/Outpost-Android-v15.apk"
	var inputs: Array = [_release(12, older), _release(15, newer), _release(14, "https://attacker.example/update.apk"), _release(99, newer, true)]
	var found: Dictionary = updater_script.find_newest_release(inputs, 11)
	check(int(found.get("version_code", 0)) == 15 and str(found.get("download_url", "")) == newer, "Picks highest trusted valid update code")
	check(updater_script.find_newest_release(inputs, 15).is_empty(), "Does not offer the installed version")
	check(updater_script.find_newest_release([_release(14, "https://evil.example/Outpost.apk")], 11).is_empty(), "Rejects arbitrary download websites")
	check(updater_script.find_newest_release([_release(99, newer, true)], 11).is_empty(), "Never publishes draft GitHub release")
	check(updater_script.find_newest_release([{"tag_name":"outpost-android-v5x","assets":[{"name":"Outpost-Android-v5x.apk","browser_download_url":newer}]}], 11).is_empty(), "Rejects nonnumeric version tags")
	var alpha_url: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-alpha-v1005/Outpost-Alpha-v1005.apk"
	var alpha_release: Dictionary = {"tag_name":"outpost-alpha-v1005", "draft":false, "assets":[{"name":"Outpost-Alpha-v1005.apk", "browser_download_url":alpha_url}]}
	check(updater_script.find_newest_release([alpha_release], 0, "outpost-alpha-v").get("download_url", "") == alpha_url, "Alpha channel finds its own published APK")
	check(updater_script.find_newest_release([alpha_release], 0).is_empty(), "Stable channel never advertises Alpha APKs")
	check(updater_script.find_newest_release(inputs, 0, "outpost-alpha-v").is_empty(), "Alpha channel never advertises Stable APKs")
	check(updater_script.find_newest_release([{"tag_name":"outpost-alpha-v1005", "assets":[{"name":"Outpost-Android-v1005.apk", "browser_download_url":alpha_url}]}], 0, "outpost-alpha-v").is_empty(), "Mismatched channel APK filenames rejected")
	var title: PackedScene = load("res://scenes/ui/title_screen.tscn")
	check(title != null, "Title scene imports with updater")
	if title != null:
		var screen = title.instantiate()
		root.add_child(screen)
		await process_frame
		var panel: Control = screen.get_node_or_null("Artboard/SettingsPanel") as Control
		check(panel != null, "Title screen has settings panel")
		check(screen.get("_updater") != null, "In-app updater service is connected")
		var button: Button = screen.get("_update_button") as Button
		check(button != null and button.text == "CHECK FOR UPDATES", "Visible and deliberate update-check action")
		var label: Label = screen.get("_update_status") as Label
		check(label != null and label.text.contains("build"), "Settings display installed Android build code")
		if button != null:
			check(button.pressed.is_connected(screen._check_updates_only), "Update button has a working callback")
		var notice: Button = screen.get("_update_notice") as Button
		check(notice != null and not notice.visible, "Update banner stays hidden until a newer build is found")
		screen._on_update_found(newer, 15, "https://github.com/Smurfis/outpost-rpg/releases/tag/outpost-android-v15")
		check(notice != null and notice.visible and notice.text.contains("BUILD 15"), "New release shows visible title-screen update notice")
		var download: Button = screen.get("_download_button") as Button
		check(download != null and not download.disabled and download.text.contains("15"), "Dedicated download button enables for the discovered build")
		check(download != null and download.pressed.is_connected(screen._check_or_download_update), "Download action opens only the trusted update URL")
		check(button.text == "CHECK FOR UPDATES", "Checking for newer updates remains available")
		var stable: Button = screen.get("_channel_stable_button") as Button
		var alpha: Button = screen.get("_channel_alpha_button") as Button
		check(stable != null and alpha != null and alpha.pressed.is_connected(screen._select_update_channel.bind("alpha")), "Stable and Alpha Test channel buttons are actionable")
		screen._select_update_channel("alpha")
		check(screen.get("_update_download_url") == "" and (screen.get("_download_button") as Button).disabled, "Switching to Alpha clears old Stable download")
		check(screen.get("_updater").selected_channel() == "alpha", "Main Settings actually targets Alpha releases")
		screen._on_update_found(alpha_url, 1005, "https://github.com/Smurfis/outpost-rpg/releases/tag/outpost-alpha-v1005")
		check(screen.get("_update_download_url") == alpha_url, "Alpha release URL is offered for Download APK")
		screen._select_update_channel("stable")
		check(screen.get("_updater").selected_channel() == "stable", "Switching back to Stable selects Stable releases")
		check(screen.get("_update_download_url") == "" and (screen.get("_download_button") as Button).disabled, "Switching to Stable clears old Alpha download")
		check(str(screen.get("_selected_channel")) == "stable", "Selected channel persists as a settings choice")
		screen.queue_free()
		await process_frame
	print("ANDROID UPDATER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
