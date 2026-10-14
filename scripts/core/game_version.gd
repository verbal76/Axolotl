class_name GameVersion
extends RefCounted
## PRODUCT IDENTITY — the product name, the protagonist's name and the one canonical,
## human-facing version of Mote. Owner-ruled names; every player-facing consumer reads them.
##
## MAJOR.MINOR.PATCH, changed only by a deliberate product decision (see
## docs/VERSIONING.md). Never derived from CI runs, APK builds, OTA ids, git SHAs or the save
## schema, and never copied: every consumer (title screen, diagnostics, settings metadata,
## CI build info, OTA manifests) reads this constant. It lives in the game layer so an OTA
## can move the game forward without a new APK.

const GAME_VERSION := "0.1.0"
const PRODUCT_NAME := "Mote"
const CHARACTER_NAME := "Gill"


## PUBLIC VERSION (studio convention, owner 2026-10-04; docs/VERSIONING.md "Public version"): the one
## number the owner sees, "Mote v92". It is the sequence number of the delivered game build that is
## running: the active OTA's `seq` (each published OTA is a delivered playable build, numbered
## v1, v2, v3... by the publish workflow), or the number baked into an APK built from a published
## build (`res://public_version.txt`). 0 when unknown (a local or test run). GAME_VERSION stays the
## internal semantic version.
static func public_number() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var boot: Node = tree.root.get_node_or_null("Boot") if tree != null else null
	if boot != null and boot.get("core") != null:
		var active: Dictionary = boot.core.active
		if not active.is_empty() and int(active.get("seq", 0)) > 0:
			return int(active.get("seq", 0))
	if FileAccess.file_exists("res://public_version.txt"):
		return FileAccess.get_file_as_string("res://public_version.txt").strip_edges().to_int()
	return 0


## "Mote v92" (or just the product name when the number is unknown).
static func public_label() -> String:
	var n := public_number()
	return "%s v%d" % [PRODUCT_NAME, n] if n > 0 else PRODUCT_NAME


## Player-facing form shown on the title screen: "v92" (empty when unknown).
static func display() -> String:
	var n := public_number()
	return "v%d" % n if n > 0 else ""


## Title treatment: MOTE.
static func title() -> String:
	return PRODUCT_NAME.to_upper()
