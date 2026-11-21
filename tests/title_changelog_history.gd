extends SceneTree
## Alpha changelog: bounded layout, readable Markdown, dated GitHub entries and offline history.
const READER := preload("res://scripts/ui/changelog_reader.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if ok:
		print("PASS CHANGELOG: " + note)
	else:
		failures += 1
		push_error("FAIL CHANGELOG: " + note)

func _run() -> void:
	var offline: Array[Dictionary] = READER.offline_entries()
	_check(offline.size() >= 3, "Existing docs/CHANGELOG.md history is available offline")
	if not offline.is_empty():
		_check(str(offline[0].get("version", "")).begins_with("v0.5.0"), "Offline versions come from Markdown release headers")
		_check(str(offline[0].get("date", "")).contains("not recorded"), "Missing historical release timestamps are not invented")
		_check((offline[0].get("lines", []) as Array).size() >= 3, "Markdown list items remain distinct changelog bullets")
	var sample: Array = [
		{
			"tag_name": "outpost-alpha-v1062",
			"name": "Alpha v1062 - Dungeon improvements",
			"published_at": "2026-11-12T14:21:50Z",
			"author": {"login": "github-actions[bot]"},
			"draft": false,
			"body": "### Dungeons\n- New floor warnings\n- Fixed doorway stairs"
		},
		{"tag_name": "outpost-stable-v1", "draft": false},
		{"tag_name": "outpost-alpha-v1063", "draft": true}
	]
	var releases: Array[Dictionary] = READER.releases_from_json(JSON.stringify(sample))
	_check(releases.size() == 1, "Published Alpha releases exclude Stable tags and drafts")
	if not releases.is_empty():
		var first: Dictionary = releases[0]
		_check(str(first["date"]).contains("2026-11-12") and str(first["date"]).contains("14:21 UTC"), "Real published date/time is displayed in UTC")
		_check(str(first["author"]).contains("Smurf") and str(first["author"]).contains("github-actions[bot]"), "Author and automated publisher stay distinguishable")
		var lines: Array = first["lines"]
		_check(lines.size() == 3 and str(lines[0]["kind"]) == "heading" and str(lines[1]["kind"]) == "bullet", "Section headers and round bullets are parsed")

	var scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_check(scene != null, "Title scene still imports")
	if scene == null:
		quit(1)
		return
	var title: Control = scene.instantiate() as Control
	root.add_child(title)
	await process_frame
	var panel: Panel = title.get_node_or_null("Artboard/ChangelogPanel") as Panel
	var close: Button = panel.find_child("ChangelogCloseButton", true, false) as Button if panel != null else null
	var scroll: ScrollContainer = panel.find_child("ChangelogScrollList", true, false) as ScrollContainer if panel != null else null
	var entries: VBoxContainer = panel.find_child("ChangelogEntries", true, false) as VBoxContainer if panel != null else null
	_check(panel != null and panel.size.y <= 560.0 and panel.position.y + panel.size.y <= 650.0, "Changelog ends above the bottom of the 720p title")
	_check(close != null and scroll != null and entries != null, "Close action, scroll region and version cards are accessible")
	if scroll != null:
		_check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS, "Visible vertical scroll bar supports touch and mouse")
	if entries != null:
		_check(entries.get_child_count() >= 3, "Offline Markdown version history is rendered as separate cards")
		_check(entries.find_child("ChangelogMetadata", true, false) != null, "Each card contains author and date/time metadata")
		_check(entries.find_child("ChangelogBullet", true, false) != null, "Rounded bullet points are real individual rows")
	title.call("_layout_for_size", Vector2(2400, 1080))
	_check(panel != null and panel.position.y + panel.size.y <= 650.0, "Ultrawide phone layout retains fixed vertical bounds")
	# Inject the exact GitHub response path without requiring a live network call in CI.
	title.call("_on_changelog_releases_loaded", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(sample).to_utf8_buffer())
	if entries != null:
		_check(entries.find_child("ChangelogArchiveHeading", true, false) != null, "Online releases append archived Markdown versions")
		_check(entries.get_child_count() >= 5, "Online and offline histories are both visible")
	title.queue_free()
	await process_frame
	print("CHANGELOG RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
