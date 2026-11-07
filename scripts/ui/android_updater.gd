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
var target_channel: String = ""
signal download_progress(downloaded_bytes: int, total_bytes: int)
signal download_ready(channel: String, version_code: int)

const DOWNLOAD_STATE_FILE := "user://outpost_download_state.cfg"
const APK_MIME := "application/vnd.android.package-archive"
var _download_manager: Variant
var _android_runtime: Variant
var _download_id: int = -1
var _download_channel: String = ""
var _download_code: int = 0
var _download_url: String = ""
var _download_complete: bool = false
var _poll_elapsed: float = 0.0

func _ready() -> void:
	if OS.has_feature("Android"):
		_restore_download()

func _process(delta: float) -> void:
	if _download_id < 0 or _download_complete:
		return
	_poll_elapsed += delta
	if _poll_elapsed >= 0.6:
		_poll_elapsed = 0.0
		_poll_android_download()

static func valid_asset_url(url: String, channel: String) -> bool:
	# Accept ONLY our two signed GitHub release download paths. No URL
	# parameters, fragments, alternate hosts, or user-supplied APK names.
	if channel not in ["stable", "alpha"]:
		return false
	var prefix: String = "outpost-alpha-v" if channel == "alpha" else "outpost-android-v"
	var filename_prefix: String = "Outpost-Alpha-v" if channel == "alpha" else "Outpost-Android-v"
	if not url.begins_with(DOWNLOAD_PREFIX):
		return false
	var rest: String = url.trim_prefix(DOWNLOAD_PREFIX)
	var parts: PackedStringArray = rest.split("/")
	if parts.size() != 2 or not parts[0].begins_with(prefix):
		return false
	var digits: String = parts[0].trim_prefix(prefix)
	return digits.is_valid_int() and int(digits) > 0 and parts[1] == filename_prefix + digits + ".apk"

func has_active_download() -> bool:
	return _download_id >= 0 and not _download_complete

func has_ready_download() -> bool:
	return _download_id >= 0 and _download_complete

func download_label() -> String:
	return "%s build %d" % [_download_channel.capitalize(), _download_code]

func start_apk_download(url: String, channel: String, code: int) -> bool:
	if not valid_asset_url(url, channel):
		status_changed.emit("Blocked an unrecognised APK URL.")
		return false
	if not OS.has_feature("Android"):
		status_changed.emit("In-game APK downloads require an Android device.")
		return false
	if has_active_download():
		status_changed.emit("An Outpost APK is already downloading.")
		return false
	if not _connect_android():
		status_changed.emit("Android downloads are unavailable on this device.")
		return false
	# The Android OS DownloadManager handles redirects, progress, notification
	# and persistence. This does NOT open Chrome and never silently installs.
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var Request = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
	var Environment = JavaClassWrapper.wrap("android.os.Environment")
	var request = Request.Request(Uri.parse(url))
	if request == null:
		status_changed.emit("Unable to create Android download request.")
		return false
	request.setTitle("Outpost " + channel.capitalize() + " build " + str(code))
	request.setDescription("Outpost update APK — install only if you approve")
	request.setMimeType(APK_MIME)
	request.setNotificationVisibility(1)
	var context = _android_runtime.getApplicationContext()
	var filename: String = url.get_file()
	# App-specific external Download folder: no broad storage permission.
	# The system DownloadManager provides an authorised content URI to the
	# Android package installer once the download has completed.
	request.setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, filename)
	var exception = JavaClassWrapper.get_exception()
	if exception != null:
		status_changed.emit("Download storage isn't available: " + str(exception))
		return false
	var new_id = _download_manager.enqueue(request)
	exception = JavaClassWrapper.get_exception()
	if exception != null or int(new_id) <= 0:
		status_changed.emit("Android couldn't start this download.")
		return false
	_download_id = int(new_id)
	_download_channel = channel
	_download_code = code
	_download_url = url
	_download_complete = false
	_save_download()
	set_process(true)
	download_progress.emit(0, 0)
	status_changed.emit("Downloading %s inside Outpost… 0%%" % download_label())
	return true

func cancel_apk_download() -> void:
	if _download_id >= 0 and not _download_complete and _connect_android():
		_download_manager.remove(PackedInt64Array([_download_id]))
		JavaClassWrapper.get_exception()
	_clear_download()
	status_changed.emit("APK download cancelled.")

func install_downloaded_apk() -> bool:
	if not has_ready_download() or not _connect_android():
		status_changed.emit("No completed Outpost APK to install.")
		return false
	var uri = _download_manager.getUriForDownloadedFile(_download_id)
	var exception = JavaClassWrapper.get_exception()
	if exception != null or uri == null:
		status_changed.emit("Android cannot share this APK. Open Downloads to install it.")
		open_android_downloads()
		return false
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var intent = Intent.Intent(Intent.ACTION_VIEW)
	intent.setDataAndType(uri, APK_MIME)
	intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
	var activity = _android_runtime.getActivity()
	# Android owns the install confirmation and the Unknown Apps permission
	# dialog. No programmatic installation, channel overwrite or save copying.
	var launch = func() -> void:
		activity.startActivity(intent)
	activity.runOnUiThread(_android_runtime.createRunnableFromGodotCallable(launch))
	status_changed.emit("Approve installation in Android. Stable and Alpha install separately.")
	return true

func open_android_downloads() -> bool:
	if not _connect_android():
		return false
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var intent = Intent.Intent("android.intent.action.VIEW_DOWNLOADS")
	intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
	var activity = _android_runtime.getActivity()
	var launch = func() -> void:
		activity.startActivity(intent)
	activity.runOnUiThread(_android_runtime.createRunnableFromGodotCallable(launch))
	return true

func _connect_android() -> bool:
	if not OS.has_feature("Android"):
		return false
	if _android_runtime == null:
		_android_runtime = Engine.get_singleton("AndroidRuntime")
	if _android_runtime == null:
		return false
	if _download_manager == null:
		_download_manager = _android_runtime.getApplicationContext().getSystemService("download")
	return _download_manager != null

func _poll_android_download() -> void:
	if not _connect_android():
		return
	var Query = JavaClassWrapper.wrap("android.app.DownloadManager$Query")
	var query = Query.Query()
	query.setFilterById(PackedInt64Array([_download_id]))
	var cursor = _download_manager.query(query)
	var exception = JavaClassWrapper.get_exception()
	if exception != null or cursor == null:
		status_changed.emit("Could not read Android download progress.")
		return
	if not cursor.moveToFirst():
		cursor.close()
		status_changed.emit("Download missing from Android download manager.")
		_clear_download()
		return
	var downloaded: int = int(cursor.getLong(cursor.getColumnIndex("bytes_so_far")))
	var total: int = int(cursor.getLong(cursor.getColumnIndex("total_size")))
	var status: int = int(cursor.getInt(cursor.getColumnIndex("status")))
	cursor.close()
	download_progress.emit(downloaded, total)
	match status:
		8:  # DownloadManager.STATUS_SUCCESSFUL
			_download_complete = true
			_save_download()
			status_changed.emit("%s downloaded. Tap INSTALL APK to open Android's confirmation." % download_label())
			download_ready.emit(_download_channel, _download_code)
		16: # STATUS_FAILED
			_clear_download()
			status_changed.emit("APK download failed. Check storage or internet and retry.")
		4: # STATUS_PAUSED
			status_changed.emit("Android paused your APK download. Waiting for connection…")
		_:
			if total > 0:
				status_changed.emit("Downloading %s… %d%%" % [download_label(), clampi(int(100.0 * float(downloaded) / float(total)), 0, 100)])
			else:
				status_changed.emit("Downloading %s… %0.1f MB" % [download_label(), float(downloaded) / 1048576.0])

func _save_download() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("download", "id", _download_id)
	cfg.set_value("download", "channel", _download_channel)
	cfg.set_value("download", "code", _download_code)
	cfg.set_value("download", "url", _download_url)
	cfg.set_value("download", "complete", _download_complete)
	cfg.save(DOWNLOAD_STATE_FILE)

func _restore_download() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DOWNLOAD_STATE_FILE) != OK:
		return
	var url: String = str(cfg.get_value("download", "url", ""))
	var channel: String = str(cfg.get_value("download", "channel", ""))
	var id: int = int(cfg.get_value("download", "id", -1))
	if id <= 0 or not valid_asset_url(url, channel):
		return
	_download_id = id
	_download_url = url
	_download_channel = channel
	_download_code = int(cfg.get_value("download", "code", 0))
	_download_complete = bool(cfg.get_value("download", "complete", false))
	set_process(true)

func _clear_download() -> void:
	_download_id = -1
	_download_complete = false
	_download_channel = ""
	_download_code = 0
	_download_url = ""
	set_process(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOWNLOAD_STATE_FILE))


func installed_channel() -> String:
	return "alpha" if str(ProjectSettings.get_setting(CHANNEL_KEY, "stable")) == "alpha" else "stable"

func selected_channel() -> String:
	return target_channel if target_channel in ["stable", "alpha"] else installed_channel()

func set_target_channel(channel: String) -> void:
	if channel in ["stable", "alpha"]:
		target_channel = channel


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
	var channel: String = selected_channel()
	var current_code: int = installed_version_code() if channel == installed_channel() else 0
	var tag_prefix: String = ALPHA_TAG_PREFIX if channel == "alpha" else TAG_PREFIX
	var latest: Dictionary = find_newest_release(json as Array, current_code, tag_prefix)
	if latest.is_empty():
		status_changed.emit("No newer %s APK found (installed build %d)." % [channel.capitalize(), installed_version_code()] if channel == installed_channel() else "No published %s APK available yet." % channel.capitalize())
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
		if tag_prefix not in [TAG_PREFIX, ALPHA_TAG_PREFIX] or not tag.begins_with(tag_prefix):
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
			var expected_name: String = ("Outpost-Alpha-v" if tag_prefix == ALPHA_TAG_PREFIX else "Outpost-Android-v") + number + ".apk"
			if str(asset.get("name", "")) != expected_name or not url.begins_with(DOWNLOAD_PREFIX):
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
