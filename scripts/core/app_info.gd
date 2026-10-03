class_name AppInfo
extends RefCounted
## GAME LAYER — the Hot Attic Games About / diagnostics standard (docs/HOT_ATTIC_INFRA.md §3).
##
## One plain-text report: app, device, OTA, Android / Google Play. Every value is read at runtime
## from what this build really exposes (Boot.identity(), Boot.core / Boot.updater, OS); what only
## the native layer could know and runtime r5 does not expose says so (NOT_EXPOSED) instead of
## being guessed. No secrets, no personal data, no save contents.

const NOT_EXPOSED := "not exposed by this build (next APK)"
## Google Play's target API requirement, read 2026-10-03 from
## https://developer.android.com/google/play/requirements/target-sdk : from 2026-08-31 new apps and
## app updates must target Android 16 (API 36) or higher (extension available to 2026-11-01).
const PLAY_TARGET_API := 36
const PLAY_RULE_CHECKED := "2026-10-03"
## What the APK build configuration implies (not read from the running APK): export_presets.cfg sets
## no target SDK, so Godot 4.7.2's default applies (its Android template: minSdk 24, targetSdk 36).
const BUILD_CONFIG_TARGET_SDK := 36
const BUILD_CONFIG_MIN_SDK := 24

static var _api_level := -2


# --- pure helpers (unit-tested) --------------------------------------------------------------

## The Android package id, from the app's private data directory (Godot's user:// on Android is
## Context.getFilesDir(): /data/user/<n>/<package>/files or /data/data/<package>/files). "" when
## the path does not have that shape.
static func package_from_data_dir(dir: String) -> String:
	var parts := dir.trim_suffix("/").split("/", false)
	if parts.size() >= 4 and parts[parts.size() - 1] == "files" and parts[0] == "data" \
			and (parts[1] == "user" or parts[1] == "data"):
		var pkg := parts[parts.size() - 2]
		if pkg.count(".") >= 1 and not pkg.contains(" "):
			return pkg
	return ""


## YES / NO / UNVERIFIED: does the target SDK meet Google Play's requirement? Unknown (< 0) is
## UNVERIFIED, never assumed.
static func play_api_compliant(target_sdk: int, required: int) -> String:
	if target_sdk < 0 or required <= 0:
		return "UNVERIFIED"
	return "YES" if target_sdk >= required else "NO"


static func _yn(b: bool) -> String:
	return "yes" if b else "no"


# --- runtime facts ------------------------------------------------------------------------------

## Android API level from the system property (getprop, run once per process, Android only);
## -1 when it cannot be read.
static func api_level() -> int:
	if _api_level != -2:
		return _api_level
	_api_level = -1
	if OS.get_name() == "Android":
		var out: Array = []
		if OS.execute("getprop", ["ro.build.version.sdk"], out) == 0 and not out.is_empty():
			var s := str(out[0]).strip_edges()
			if s.is_valid_int() and int(s) > 0 and int(s) < 1000:
				_api_level = int(s)
	return _api_level


static func package_id() -> String:
	if OS.get_name() != "Android":
		return "n/a (%s run)" % OS.get_name()
	var p := package_from_data_dir(OS.get_user_data_dir())
	return p if p != "" else NOT_EXPOSED


static func _event(name: String) -> String:
	if not Boot.ota_enabled or Boot.core == null:
		return "none"
	var e: Dictionary = (Boot.core.state["events"] as Dictionary).get(name, {})
	return ("%s  (%s)" % [e.get("time", "?"), e.get("result", "?")]) if not e.is_empty() else "none"


## Compact, honest: what the running code is and whether it is current.
static func update_state() -> String:
	return preload("res://scripts/core/update_activation.gd").current_phase()


# --- the report ----------------------------------------------------------------------------------

## The full plain-text report (Copy diagnostics puts it first, the native diagnostics after it).
static func report_text() -> String:
	var id: Dictionary = Boot.identity()
	var android := OS.get_name() == "Android"
	var ota: bool = Boot.ota_enabled and Boot.core != null
	var act: Dictionary = Boot.core.active if ota else {}
	var L: Array[String] = []
	L.append("%s ABOUT / DIAGNOSTICS" % str(id.get("product", "Mote")).to_upper())
	L.append("Captured at: %sZ (UTC)" % Time.get_datetime_string_from_system(true))
	L.append("")
	L.append("App")
	L.append("  App name: %s" % id.get("product", "?"))
	L.append("  Package id: %s" % package_id())
	L.append("  Version name: %s (game); app (APK) %s" % [id.get("game_version", "?"), id.get("native_version", "?")])
	L.append("  Version code: %s" % (str(id.get("native_build", "")) if android else "n/a (%s run; native build %s)" % [OS.get_name(), id.get("native_build", "local")]))
	L.append("  Native runtime: %s" % id.get("runtime_id", "?"))
	L.append("  Build identity: %s build, run %s" % [id.get("build_flavor", "?"), id.get("native_build_run", "local")])
	L.append("  Source SHA (running code): %s" % id.get("source_sha", "unknown"))
	L.append("  Channel: %s" % id.get("ota_channel", "none"))
	L.append("")
	L.append("Device")
	L.append("  OS: %s %s" % [OS.get_name(), OS.get_version()])
	var api := api_level()
	L.append("  API level: %s" % ((str(api) + " (system property)") if api > 0 else (NOT_EXPOSED if android else "n/a")))
	L.append("  Model: %s" % OS.get_model_name())
	L.append("  Locale: %s" % OS.get_locale())
	L.append("")
	L.append("OTA")
	L.append("  Updates enabled: %s" % (_yn(ota and not bool(Boot.core.state["disabled"])) + ("" if not ota or not Boot.core.state["disabled"] else " (disabled: bundled baseline mode)")))
	L.append("  Channel: %s" % id.get("ota_channel", "none"))
	var compat: String = Boot.updater.latest_compat if Boot.updater != null else ""
	L.append("  Runtime compatibility: %s" % ("not checked yet" if compat == "" else ("compatible" if compat == "compatible" else "NOT compatible: " + compat)))
	L.append("  Current OTA: %s" % (("%s (seq %s)" % [act["ota_id"], str(act.get("seq", "?"))]) if not act.is_empty() else "none"))
	L.append("  Running source: %s" % ("OTA package" if not act.is_empty() else "embedded (bundled in the app)"))
	L.append("  OTA source SHA: %s" % (str(act.get("source_sha", "")) if not act.is_empty() else "none"))
	L.append("  OTA PCK SHA-256: %s" % (str(act.get("pck_sha256", "")) if not act.is_empty() else "none"))
	L.append("  Last check: %s" % _event("check"))
	L.append("  Update state: %s" % update_state())
	L.append("")
	L.append("Android / Google Play")
	L.append("  Target SDK: %s (build configuration: Godot 4.7.2 default %d, min SDK %d; not read from this app)" % [NOT_EXPOSED, BUILD_CONFIG_TARGET_SDK, BUILD_CONFIG_MIN_SDK])
	L.append("  Play required target API: %d (developer.android.com, checked %s; in force since 2026-08-31)" % [PLAY_TARGET_API, PLAY_RULE_CHECKED])
	L.append("  PLAY API COMPLIANT: %s (target SDK not exposed at runtime; the build configuration implies %s)" % [play_api_compliant(-1, PLAY_TARGET_API), play_api_compliant(BUILD_CONFIG_TARGET_SDK, PLAY_TARGET_API)])
	if android:
		L.append("  Export: %s" % ("debug template (debuggable): Google Play does not accept it" if OS.is_debug_build() else "release template"))
		L.append("  Signing: signed (Android installs signed apps only); certificate fingerprint %s" % NOT_EXPOSED)
	else:
		L.append("  Export / signing: n/a (%s run)" % OS.get_name())
	return "\n".join(L)


## What Copy diagnostics puts on the clipboard: the report, then the native diagnostics (OTA
## slots and events, startup timeline, automatic updates). Plain text.
static func copy_text() -> String:
	return report_text() + "\n\n" + Boot.diagnostics_text() + "\n"


## The few lines the About page shows (the rest is under Technical).
static func about_lines() -> Array[String]:
	var id: Dictionary = Boot.identity()
	var active := str(id.get("ota_id", "none"))
	var api := api_level()
	var L: Array[String] = []
	L.append("%s %s  ·  app build %s  ·  running %s" % [id.get("product", "Mote"), id.get("game_version", "?"), id.get("native_build", "?"),
			active if active != "none" else "the bundled game"])
	L.append("Updates: %s  ·  channel %s  ·  %s" % [update_state(), id.get("ota_channel", "none"), id.get("runtime_id", "?")])
	L.append("%s %s%s  ·  %s  ·  %s" % [OS.get_name(), OS.get_version(), (" (API %d)" % api) if api > 0 else "", OS.get_model_name(), OS.get_locale()])
	return L
