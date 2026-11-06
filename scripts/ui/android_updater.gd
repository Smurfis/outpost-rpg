extends Node
## Safe public GitHub release lookup for self-updates.
## This is intentionally a user-initiated check: installation must be explicitly
## approved by Android. Do not try to silently install sideloaded applications.
signal status_changed(message: String)
signal update_found(download_url: String, version_code: int, release_url: String)

const API: String = "https://api.github.com/repos/Smurfis/outpost-rpg/releases?per_page=20"
const TAG_PREFIX: String = "outpost-android-v"
const ALPHA_TAG_PREFIX: String = "outpost-alpha-v"
const CHANNEL_KEY: String = "application/config/build_channel"
const DOWNLOAD_PREFIX: String = "https://github.com/Smurfis/outpost-rpg/releases/download/"
const PROJECT_VERSION_KEY: String = "application/config/android_build_code"
const DEFAULT_VERSION_CODE: int = 11

var _request: HTTPRequest

func installed_version_code() -> int:
	return int(ProjectSettings.get_setting(PROJECT_VERSION_KEY, DEFAULT_VERSION_CODE))

func check_for_updates() -> void:
	if _request != null:
		status_changed.emit("Already checking for an update...")
		return
	_request = HTTPRequest.new()
	_request.timeout = 15.0
	_request.body_size_limit = 2 * 1024 * 1024
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	status_changed.emit("Checking Outpost releases...")
	var error: Error = _request.request(
		API,
		PackedStringArray(["User-Agent: Outpost-Android-Updater", "Accept: application/vnd.github+json"]),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_finish_request()
		status_changed.emit("Could not connect. Check your internet connection.")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_finish_request()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_changed.emit("Update check unavailable. Try again later.")
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (json is Array):
		status_changed.emit("Could not read the update information.")
		return
	var current_code: int = installed_version_code()
	var channel: String = str(ProjectSettings.get_setting(CHANNEL_KEY, "stable"))
	var tag_prefix: String = ALPHA_TAG_PREFIX if channel == "alpha" else TAG_PREFIX
	var latest: Dictionary = find_newest_release(json as Array, current_code, tag_prefix)
	if latest.is_empty():
		status_changed.emit("Outpost is up to date (build %d)." % current_code)
	else:
		update_found.emit(str(latest["download_url"]), int(latest["version_code"]), str(latest["release_url"]))

func _finish_request() -> void:
	if _request != null:
		var old: HTTPRequest = _request
		_request = null
		old.queue_free()

static func find_newest_release(releases: Array, installed_code: int, tag_prefix: String = TAG_PREFIX) -> Dictionary:
	# Only GitHub assets from OUR repo and tags with monotonically increasing
	# integer build codes. No arbitrary URL redirects, webview or code execution.
	var latest: Dictionary = {}
	var max_code: int = installed_code
	for release in releases:
		if not (release is Dictionary):
			continue
		var item: Dictionary = release
		if bool(item.get("draft", false)):
			continue
		var tag: String = str(item.get("tag_name", ""))
		if not tag.begins_with(tag_prefix):
			continue
		var number: String = tag.trim_prefix(tag_prefix)
		if not number.is_valid_int():
			continue
		var code: int = int(number)
		if code <= max_code:
			continue
		var assets: Variant = item.get("assets", [])
		if not (assets is Array):
			continue
		for value in assets:
			if not (value is Dictionary):
				continue
			var asset: Dictionary = value
			var url: String = str(asset.get("browser_download_url", ""))
			if not str(asset.get("name", "")).ends_with(".apk") or not url.begins_with(DOWNLOAD_PREFIX):
				continue
			if not url.contains("/" + tag + "/"):
				continue
			max_code = code
			latest = {
				"version_code": code,
				"download_url": url,
				"release_url": str(item.get("html_url", ""))
			}
			break
	return latest
