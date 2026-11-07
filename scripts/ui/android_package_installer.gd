extends Node
## Android's DownloadManager handles trusted APK transfers in-app (no Chrome).
## The player MUST explicitly approve an install in the Android system UI.
## Stable and Alpha remain two separately signed/installable application IDs.

signal status_changed(message: String)
signal download_progress(fraction: float)
signal install_ready(channel: String, code: int)

const DOWNLOAD_PREFIX := "https://github.com/Smurfis/outpost-rpg/releases/download/"
const APK_MIME := "application/vnd.android.package-archive"
const STATE_FILE := "user://outpost_apk_download.cfg"

var _android_runtime: Object
var _manager: Object
var _download_id: int = -1
var _download_code: int = 0
var _download_channel: String = ""
var _ready_uri: Object
var _active: bool = false
var _poll_elapsed: float = 0.0
var _last_progress: int = -1

static func expected_apk_url(channel: String, code: int) -> String:
	if channel not in ["stable", "alpha"] or code <= 0:
		return ""
	var base: String = "outpost-alpha-v" if channel == "alpha" else "outpost-android-v"
	var name: String = "Outpost-Alpha-v" if channel == "alpha" else "Outpost-Android-v"
	return DOWNLOAD_PREFIX + base + str(code) + "/" + name + str(code) + ".apk"

static func trusted_apk_url(url: String, channel: String, code: int) -> bool:
	# Full equality protects against malicious/renamed links, query strings,
	# traversal and other sites; the GitHub HTTPS redirect is OS-managed.
	return not url.is_empty() and url == expected_apk_url(channel, code)

func is_downloading() -> bool:
	return _active

func can_install() -> bool:
	return _ready_uri != null and _download_id > 0

func downloaded_channel() -> String:
	return _download_channel

func downloaded_code() -> int:
	return _download_code

func _ensure_android() -> bool:
	if not OS.has_feature("Android"):
		status_changed.emit("Built-in APK installation is only available in the Android app.")
		return false
	_android_runtime = Engine.get_singleton("AndroidRuntime")
	if _android_runtime == null:
		status_changed.emit("Android installer interface is unavailable in this build.")
		return false
	if _manager == null:
		var context: Object = _android_runtime.getApplicationContext()
		_manager = context.getSystemService("download")
	if _manager == null:
		status_changed.emit("Android Download Manager is unavailable.")
		return false
	return true

func start_download(url: String, channel: String, code: int) -> void:
	if not trusted_apk_url(url, channel, code):
		status_changed.emit("Rejected an unverified Outpost APK address.")
		return
	if _active:
		status_changed.emit("An Outpost APK is already downloading.")
		return
	if not _ensure_android():
		return
	_ready_uri = null
	_download_channel = channel
	_download_code = code
	var filename: String = url.get_file()
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var Request = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
	var req = Request.Request(Uri.parse(url))
	req.setTitle("Outpost " + channel.capitalize() + " " + str(code))
	req.setDescription("Outpost official GitHub release APK")
	req.setMimeType(APK_MIME)
	req.setNotificationVisibility(1) # Visible Android system download notification.
	req.setAllowedOverMetered(true)
	# App-scoped external Download directory requires no unrestricted file access.
	req.setDestinationInExternalFilesDir(_android_runtime.getApplicationContext(), "Download", filename)
	_download_id = int(_manager.enqueue(req))
	if _download_id <= 0 or JavaClassWrapper.get_exception() != null:
		_download_id = -1
		status_changed.emit("Unable to start the system download. Try again.")
		return
	_active = true
	_poll_elapsed = 0.0
	_last_progress = -1
	set_process(true)
	_remember_download()
	status_changed.emit("Downloading %s %d inside Outpost. You can leave Settings while Android downloads." % [channel.capitalize(), code])

func _ready_download() -> void:
	if _download_id <= 0 or _manager == null:
		return
	_ready_uri = _manager.getUriForDownloadedFile(_download_id)
	if _ready_uri == null:
		status_changed.emit("Download finished, but Android could not share the APK with its installer.")
		return
	_active = false
	set_process(false)
	_download_state("")
	download_progress.emit(1.0)
	status_changed.emit("%s build %d downloaded. Tap INSTALL to open Android's approval screen." % [_download_channel.capitalize(), _download_code])
	install_ready.emit(_download_channel, _download_code)

func _process(delta: float) -> void:
	if not _active:
		return
	_poll_elapsed += delta
	if _poll_elapsed < 0.65:
		return
	_poll_elapsed = 0.0
	if _manager == null:
		return
	var Query = JavaClassWrapper.wrap("android.app.DownloadManager$Query")
	var q = Query.Query()
	q.setFilterById(PackedInt64Array([_download_id]))
	var cursor = _manager.query(q)
	if cursor == null:
		return
	if not cursor.moveToFirst():
		cursor.close()
		return
	var state_col: int = int(cursor.getColumnIndex("status"))
	var loaded_col: int = int(cursor.getColumnIndex("bytes_so_far"))
	var total_col: int = int(cursor.getColumnIndex("total_size"))
	var status: int = int(cursor.getInt(state_col)) if state_col >= 0 else 0
	var loaded: int = int(cursor.getLong(loaded_col)) if loaded_col >= 0 else 0
	var total: int = int(cursor.getLong(total_col)) if total_col >= 0 else 0
	cursor.close()
	if status == 8: # DownloadManager.STATUS_SUCCESSFUL
		_ready_download()
		return
	if status == 16: # DownloadManager.STATUS_FAILED
		_active = false
		set_process(false)
		_download_state("")
		status_changed.emit("Android couldn't download that APK. Check your connection and try again.")
		return
	if total > 0:
		var percent: int = clampi(int(floor(loaded * 100.0 / float(total))), 0, 99)
		if percent != _last_progress:
			_last_progress = percent
			download_progress.emit(percent / 100.0)
			status_changed.emit("Downloading %s build %d: %d%%" % [_download_channel.capitalize(), _download_code, percent])

func install_downloaded() -> void:
	if not can_install():
		status_changed.emit("Download an APK before requesting installation.")
		return
	if not _ensure_android():
		return
	var activity: Object = _android_runtime.getActivity()
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var pm: Object = activity.getPackageManager()
	if pm != null and not bool(pm.canRequestPackageInstalls()):
		# Android 8+ grants unknown-source installation per app. We only send
		# the user to the official settings UI after tapping INSTALL.
		var Settings = JavaClassWrapper.wrap("android.provider.Settings")
		var permission_intent = Intent.Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
		permission_intent.setData(Uri.parse("package:" + str(activity.getPackageName())))
		activity.startActivity(permission_intent)
		status_changed.emit("Allow installs from Outpost in Android Settings, return, then tap INSTALL again.")
		return
	var intent = Intent.Intent(Intent.ACTION_VIEW)
	intent.setDataAndType(_ready_uri, APK_MIME)
	intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
	activity.startActivity(intent)
	if JavaClassWrapper.get_exception() != null:
		status_changed.emit("Android couldn't open the installer. Try your system Downloads app.")
	else:
		status_changed.emit("Android installer opened. Approve the APK there; Outpost does not install silently.")

func restore_download() -> void:
	if not _ensure_android():
		return
	var config := ConfigFile.new()
	if config.load(STATE_FILE) != OK:
		return
	_download_id = int(config.get_value("download", "id", -1))
	_download_code = int(config.get_value("download", "code", 0))
	_download_channel = str(config.get_value("download", "channel", ""))
	if _download_id <= 0 or _download_channel not in ["stable", "alpha"]:
		return
	_ready_uri = _manager.getUriForDownloadedFile(_download_id)
	if _ready_uri != null:
		status_changed.emit("%s build %d is already downloaded and ready to install." % [_download_channel.capitalize(), _download_code])
		install_ready.emit(_download_channel, _download_code)
	else:
		_active = true
		set_process(true)
		status_changed.emit("Resuming %s build %d download status." % [_download_channel.capitalize(), _download_code])

func _remember_download() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("download", "id", _download_id)
	cfg.set_value("download", "code", _download_code)
	cfg.set_value("download", "channel", _download_channel)
	cfg.save(STATE_FILE)

func _download_state(_unused: String) -> void:
	# Keep ID and metadata across sessions so Install can be resumed after
	# opening Android's allow-from-this-source settings screen.
	_remember_download()

func _ready() -> void:
	set_process(false)
