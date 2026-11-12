extends RefCounted
## Data-only changelog parser. GitHub releases provide dated Alpha entries, while
## docs/CHANGELOG.md provides offline historical versions without invented dates.
const SOURCE_MD := "res://docs/CHANGELOG.md"
const MAX_RELEASES := 8
const OFFLINE_SNAPSHOT := """# Changelog

## v0.5.0-dev — 3D art, equipment and gathering feedback
- Added ten original multi-material OBJ model files for avatar, gear and environment.
- Replaced spherical/block avatar with a multipart 3D figure and pivot-driven walking, gathering and combat animations.
- Trees and stone resources now use mesh imports; added original oak grove props, supply crates, faceted boulders and winding pathways.
- Added gear screen with main hand, offhand, back, woodcutting, mining and foraging slots.
- Added real equip/unequip behaviour and 3D preview with animated rotation.
- Gathering effects: targeted node ring, remaining-hits label, floating pickup text and arm/tool swing.
- Health bar and equipped weapon name on mobile HUD.
- Local save schema v5 migrates previous inventories; no loss of older items.
- Godot 4.7.2 CI tests source compilation, OBJ import, crafting and item/equipment behaviour.

## v0.4.0-dev — Visual crafting and gathering overhaul
- Ten gatherable resource types, 13 recipes and four 3D production stations.
- Ingredient loading, timed hands-on crafting, cancellation safety, save migration.

## v0.3.0-dev — Inventory and crafting
- Inventory screen, data-driven recipes, contextual interactions and reduced popup spam.
"""

static func offline_entries() -> Array[Dictionary]:
	var markdown: String = OFFLINE_SNAPSHOT
	if FileAccess.file_exists(SOURCE_MD):
		var loaded: String = FileAccess.get_file_as_string(SOURCE_MD)
		if not loaded.strip_edges().is_empty():
			markdown = loaded
	return parse_history(markdown)

static func parse_history(markdown: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current: Dictionary = {}
	for raw in markdown.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("## "):
			if not current.is_empty():
				result.append(current)
			var heading: String = line.trim_prefix("## ").strip_edges()
			var version: String = heading.get_slice(" ", 0)
			current = {
				"version": version,
				"title": heading,
				"date": "Date and time not recorded",
				"author": "Outpost development",
				"lines": []
			}
		elif not current.is_empty() and not line.is_empty():
			var parsed_lines: Array = current["lines"]
			parsed_lines.append(_parse_line(line))
	if not current.is_empty():
		result.append(current)
	return result

static func releases_from_json(json_text: String) -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(json_text)
	var entries: Array[Dictionary] = []
	if not (parsed is Array):
		return entries
	for release_item in parsed:
		if not (release_item is Dictionary):
			continue
		var release: Dictionary = release_item
		var tag: String = str(release.get("tag_name", ""))
		if bool(release.get("draft", false)) or not tag.begins_with("outpost-alpha-v"):
			continue
		var heading: String = str(release.get("name", "")).strip_edges()
		if heading.is_empty():
			heading = "Alpha release " + tag.trim_prefix("outpost-alpha-v")
		var published: String = str(release.get("published_at", ""))
		var stamp: String = "Publication date and time unavailable"
		if published.length() >= 16:
			stamp = "%s  •  %s UTC" % [published.substr(0, 10), published.substr(11, 5)]
		var author_data: Dictionary = {}
		if release.get("author", null) is Dictionary:
			author_data = release["author"]
		var author: String = str(author_data.get("login", "Unknown publisher"))
		if author.contains("[bot]"):
			author = "Smurf (maintainer)  •  Published by " + author
		var body: String = str(release.get("body", "")).strip_edges()
		var parsed_notes: Array[Dictionary] = []
		if body.is_empty():
			parsed_notes.append({"kind": "body", "text": "No release notes published."})
		else:
			for line in body.replace("\r", "").split("\n"):
				var cleaned: String = line.strip_edges()
				if cleaned.is_empty() or cleaned.begins_with("<!--"):
					continue
				parsed_notes.append(_parse_line(cleaned))
				if parsed_notes.size() >= 36:
					parsed_notes.append({"kind": "body", "text": "Further details are available in GitHub Releases."})
					break
		entries.append({
			"version": "ALPHA " + tag.trim_prefix("outpost-alpha-v"),
			"title": heading,
			"date": stamp,
			"author": author,
			"lines": parsed_notes
		})
		if entries.size() >= MAX_RELEASES:
			break
	return entries

static func _parse_line(raw: String) -> Dictionary:
	var line: String = raw.strip_edges()
	var kind: String = "body"
	if line.begins_with("## ") or line.begins_with("### ") or line.begins_with("#### "):
		kind = "heading"
		line = line.trim_prefix("#### ").trim_prefix("### ").trim_prefix("## ")
	elif line.begins_with("- ") or line.begins_with("* ") or line.begins_with("• "):
		kind = "bullet"
		line = line.substr(2)
	elif line.begins_with("# "):
		kind = "heading"
		line = line.trim_prefix("# ")
	elif line.begins_with("> "):
		kind = "body"
		line = line.substr(2)
	# Keep the display readable without introducing unsafe BBCode or raw URLs.
	line = line.replace("**", "").replace("__", "").replace("`", "")
	return {"kind": kind, "text": line.strip_edges()}
