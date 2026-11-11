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
	if updater_script != null:
		check(not updater_script.ALPHA_DOWNLOADS_PAUSED and updater_script.APK_INSTALLS_PAUSED, "Newer Alpha releases are discoverable while in-app installation remains paused")
		var blocked_url: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-alpha-v1012/Outpost-Alpha-v1012.apk"
		var blocked_release: Dictionary = {"tag_name":"outpost-alpha-v1012", "draft":false, "assets":[{"name":"Outpost-Alpha-v1012.apk", "browser_download_url":blocked_url}]}
		check(updater_script.find_newest_release([blocked_release], 0, "outpost-alpha-v").is_empty(), "Security-flagged v1012 never offered as a release")
		check(not updater_script.valid_asset_url(blocked_url, "alpha"), "Flagged v1012 is rejected even if a caller provides its URL")
	if updater_script == null:
		quit(1)
		return
	var older: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v12/Outpost-Android-v12.apk"
	var newer: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-android-v15/Outpost-Android-v15.apk"
	var inputs: Array = [_release(12, older), _release(15, newer), _release(14, "https://attacker.example/update.apk"), _release(99, newer, true)]
	check(updater_script.valid_asset_url(newer, "stable"), "Stable download path is strict and trusted")
	check(not updater_script.valid_asset_url(newer + "?inline=1", "stable"), "No GitHub querystring APK ambiguity")
	check(not updater_script.valid_asset_url(newer, "alpha"), "Cannot cross-wire a Stable file to Alpha installer")
	check(not updater_script.valid_asset_url("https://github.com.evil.example/Smurfis/outpost-rpg/releases/download/outpost-android-v15/Outpost-Android-v15.apk", "stable"), "Lookalike domains cannot trigger in-game downloads")
	var found: Dictionary = updater_script.find_newest_release(inputs, 11)
	check(int(found.get("version_code", 0)) == 15 and str(found.get("download_url", "")) == newer, "Picks highest trusted valid update code")
	check(updater_script.find_newest_release(inputs, 15).is_empty(), "Does not offer the installed version")
	check(updater_script.find_newest_release([_release(14, "https://evil.example/Outpost.apk")], 11).is_empty(), "Rejects arbitrary download websites")
	check(updater_script.find_newest_release([_release(99, newer, true)], 11).is_empty(), "Never publishes draft GitHub release")
	check(updater_script.find_newest_release([{"tag_name":"outpost-android-v5x","assets":[{"name":"Outpost-Android-v5x.apk","browser_download_url":newer}]}], 11).is_empty(), "Rejects nonnumeric version tags")
	var alpha_url: String = "https://github.com/Smurfis/outpost-rpg/releases/download/outpost-alpha-v1005/Outpost-Alpha-v1005.apk"
	var alpha_release: Dictionary = {"tag_name": "outpost-alpha-v1005", "draft": false, "assets": [{"name": "Outpost-Alpha-v1005.apk", "browser_download_url": alpha_url}]}
	check(updater_script.find_newest_release([alpha_release], 0, "outpost-alpha-v").get("download_url", "") == alpha_url, "Alpha gets its own APK even if Stable version codes differ")
	check(updater_script.find_newest_release([alpha_release], 0).is_empty(), "Stable never offers Alpha APKs")
	check(updater_script.find_newest_release(inputs, 0, "outpost-alpha-v").is_empty(), "Alpha never offers Stable APKs")
	check(updater_script.find_newest_release([{"tag_name":"outpost-alpha-v1005","assets":[{"name":"Outpost-Android-v1005.apk","browser_download_url":alpha_url}]}], 0, "outpost-alpha-v").is_empty(), "Mismatched APK names cannot be installed across channels")
	var title: PackedScene = load("res://scenes/ui/title_screen.tscn")
	check(title != null, "Title scene imports with updater")
	if title != null:
		var screen = title.instantiate()
		root.add_child(screen)
		await process_frame
		var panel: Control = screen.get_node_or_null("Artboard/SettingsPanel") as Control
		check(panel != null, "Title screen has settings panel")
		var scroll_button: Button = screen.get("_changelog_button") as Button
		var scroll_panel: PanelContainer = screen.get("_changelog_panel") as PanelContainer
		check(scroll_button != null and scroll_button.icon != null, "Small independent parchment changelog scroll exists")
		check(scroll_panel != null and not scroll_panel.visible, "Changelog scroll starts collapsed")
		screen._toggle_changelog()
		check(scroll_panel != null and scroll_panel.visible and scroll_panel.find_child("ChangelogBody", true, false) != null, "Changelog opens a scrollable reading panel")
		check(scroll_panel.position.x < 90.0 and scroll_panel.position.y < 80.0 and scroll_panel.size.x > 1100.0 and scroll_panel.size.y > 600.0, "Changelog is a near-full-screen readable central modal")
		var dim: ColorRect = screen.get("_changelog_dim") as ColorRect
		check(dim != null and dim.visible and dim.size.x >= 1280, "Changelog dims the full backdrop behind the reading panel")
		check(scroll_button.position.y < 200.0, "Changelog trigger remains at the top of the artwork")
		check((scroll_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.95, "Changelog has high-contrast wood background for readable text")
		check(panel.find_child("AndroidUpdateSectionFrame", true, false) != null, "Updater controls share a matching wood/parchment section")
		var footer: Button = screen.get("_settings_home_button") as Button
		check(footer != null and footer.text.contains("CANCEL") and footer.get_theme_stylebox("normal") is StyleBoxEmpty, "Settings uses the same frameless cancel action as world loading")
		var red_close: Button = scroll_panel.find_child("ChangelogCloseButton", true, false) as Button
		check(scroll_panel.clip_contents and scroll_panel.get_theme_stylebox("panel") is StyleBoxFlat, "Changelog contents are clipped inside one contained modal")
		check(red_close != null and red_close.get_theme_stylebox("normal") is StyleBoxFlat and (red_close.get_theme_stylebox("normal") as StyleBoxFlat).corner_radius_top_left >= 50, "Changelog uses the same large red circular close control")
		check(red_close != null and red_close.pressed.is_connected(screen._toggle_changelog), "Changelog close X is a functional action")
		screen._toggle_changelog()
		check(scroll_panel != null and not scroll_panel.visible and not dim.visible, "Changelog and its dimmer can be dismissed")
		var selected_glow: TextureRect = screen.get_node_or_null("Artboard/SelectedTitleButtonGlow") as TextureRect
		var settings_action: Button = screen.get_node_or_null("Artboard/SettingsButton") as Button
		check(selected_glow != null and selected_glow.texture != null, "All title buttons share one separate movable gold glow asset")
		if selected_glow != null and settings_action != null:
			screen._set_title_button_glow(settings_action)
			check(selected_glow.visible and is_equal_approx(selected_glow.position.x, settings_action.position.x - 44.0), "Selected glow follows Settings instead of remaining behind Play")
			screen._hide_title_glow_if_idle()
			check(not selected_glow.visible, "Old selected glow hides when focus moves elsewhere")

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
		check(download != null and not download.disabled and download.text.contains("COPY"), "Verified release action offers a clipboard link instead of an installer")
		check(download != null and download.pressed.is_connected(screen._check_or_download_update), "Link button is wired to the verified clipboard-only action")
		screen._check_or_download_update()
		check(label != null and label.text.contains("Copied"), "Tapping the release action reports the clipboard copy")
		check(not screen.get("_updater").has_active_download(), "Copying never starts a native APK download")
		check(screen.get("_download_progress_bar") != null and screen.get("_cancel_download_button") != null, "Legacy download state can be cleaned without exposing an installer")
		check(button.text == "CHECK FOR UPDATES", "Checking for newer updates remains available")
		var stable: Button = screen.get("_channel_stable_button") as Button
		var alpha: Button = screen.get("_channel_alpha_button") as Button
		check(stable != null and alpha != null and alpha.pressed.is_connected(screen._select_update_channel.bind("alpha")), "Stable/Alpha channels are actionable")
		screen._select_update_channel("alpha")
		check(screen.get("_update_download_url") == "" and (screen.get("_download_button") as Button).disabled, "Changing channel clears previous download links")
		check(screen.get("_updater").selected_channel() == "alpha", "Select Alpha correctly sets updater target")
		screen._select_update_channel("stable")
		check(screen.get("_updater").selected_channel() == "stable", "Switch back to Stable succeeds")
		screen.queue_free()
		await process_frame
	print("ANDROID UPDATER RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
