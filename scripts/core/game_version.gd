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


## Player-facing form shown on the title screen.
static func display() -> String:
	return "v" + GAME_VERSION


## Title treatment: MOTE.
static func title() -> String:
	return PRODUCT_NAME.to_upper()
