extends RefCounted
## Open only Outpost's signed GitHub release URLs in the full Android browser.
## Android's generic OS.shell_open() may route via an app or embedded handler.
## Prefer a Chrome-only ACTION_VIEW Intent with NEW_TASK; fall back to Android's
## default browser when Chrome is not installed or the Android runtime is absent.
const ROOT: String = "https://github.com/Smurfis/outpost-rpg/releases/download/"
const CHROME_PACKAGE: String = "com.android.chrome"

static func is_trusted_release_apk(url: String) -> bool:
	if not url.begins_with(ROOT):
		return false
	var parts: PackedStringArray = url.trim_prefix(ROOT).split("/")
	if parts.size() != 2:
		return false
	var tag: String = parts[0]
	var file_name: String = parts[1]
	if tag.begins_with("outpost-android-v"):
		var number: String = tag.trim_prefix("outpost-android-v")
		return number.is_valid_int() and int(number) > 0 and file_name == "Outpost-Android-v%s.apk" % number
	if tag.begins_with("outpost-alpha-v"):
		var number: String = tag.trim_prefix("outpost-alpha-v")
		return number.is_valid_int() and int(number) > 0 and file_name == "Outpost-Alpha-v%s.apk" % number
	return false

static func open_apk_in_browser(url: String) -> Error:
	if not is_trusted_release_apk(url):
		return ERR_INVALID_PARAMETER
	if OS.has_feature("Android") and Engine.has_singleton("AndroidRuntime"):
		var runtime = Engine.get_singleton("AndroidRuntime")
		var activity = runtime.getActivity()
		if activity != null:
			var Intent = JavaClassWrapper.wrap("android.content.Intent")
			var Uri = JavaClassWrapper.wrap("android.net.Uri")
			var chrome_intent = Intent.Intent()
			chrome_intent.setAction(Intent.ACTION_VIEW)
			chrome_intent.addCategory(Intent.CATEGORY_BROWSABLE)
			chrome_intent.setData(Uri.parse(url))
			# No Custom Tabs extras: this targets Chrome's actual browser task.
			chrome_intent.setPackage(CHROME_PACKAGE)
			chrome_intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			activity.startActivity(chrome_intent)
			# If Chrome is missing, Android throws ActivityNotFoundException.
			# JavaClassWrapper exposes JNI exceptions without crashing Godot.
			if JavaClassWrapper.get_exception() == null:
				return OK
			push_warning("Google Chrome could not open the update; trying Android's default browser.")
	return OS.shell_open(url)
