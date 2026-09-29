class_name Tier2
extends RefCounted
## Gill's Tier-2 abilities (docs/TIER2.md): Water Cannon, Bubble Blast, Gill Rush. Tail Swipe stays the
## basic attack; these are extra options found by exploring, one per world, in a fixed order
## (World 3, World 5, World 7), each at a shrine at one of that world's landmarks.
##
## Rules:
## - Unlocks belong to the run (saved with it, reset by New Run, never completion entries).
## - Any number can be unlocked; exactly one is equipped (the first unlock is equipped at once).
## - One Tier-2 button fires the equipped one. After any use the button cools down for that
##   ability's COOLDOWN; the cooldown is shared, so swapping never skips it.
## - The cooldown is transient (not saved): a continued run starts ready.

const CANNON := "cannon"
const BUBBLE := "bubble"
const RUSH := "rush"
## In unlock order.
const ORDER := [CANNON, BUBBLE, RUSH]
const NAMES := {CANNON: "Water Cannon", BUBBLE: "Bubble Blast", RUSH: "Gill Rush"}
const BLURBS := {
	CANNON: "A focused jet at whatever you face.",
	BUBBLE: "A shockwave that pushes everything back.",
	RUSH: "Three quick lunges, one after another.",
}
## Ball index (0-based) whose shrine grants it: World 3, 5 and 7.
const WORLD := {CANNON: 2, BUBBLE: 4, RUSH: 6}
## Seconds before the button is ready again after a use.
const COOLDOWN := {CANNON: 5.0, BUBBLE: 8.0, RUSH: 9.0}

var unlocked: Array[String] = []
var equipped := ""
## Play time (RunClock.play_s) when the button is ready again, and the length of that cooldown.
var ready_at := 0.0
var cool_len := 0.0


func has(id: String) -> bool:
	return unlocked.has(id)


func any() -> bool:
	return not unlocked.is_empty()


## Unlocks `id` (false if unknown or already unlocked). The first one unlocked is equipped.
func unlock(id: String) -> bool:
	if not ORDER.has(id) or unlocked.has(id):
		return false
	unlocked.append(id)
	# Kept in the fixed order whatever order the shrines were reached in.
	unlocked.sort_custom(func(a, b): return ORDER.find(a) < ORDER.find(b))
	if equipped == "":
		equipped = id
	return true


## Equips an unlocked ability (false for a locked or unknown one). The cooldown carries over.
func equip(id: String) -> bool:
	if not unlocked.has(id):
		return false
	equipped = id
	return true


func is_ready(now: float) -> bool:
	return equipped != "" and now >= ready_at


## 0 when just used, 1 when ready.
func charge(now: float) -> float:
	if cool_len <= 0.0 or now >= ready_at:
		return 1.0
	return clampf(1.0 - (ready_at - now) / cool_len, 0.0, 1.0)


## Starts the cooldown of the equipped ability (called when it fires).
func start_cooldown(now: float) -> void:
	cool_len = COOLDOWN.get(equipped, 5.0)
	ready_at = now + cool_len


func to_dict() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "equipped": equipped}


## From a saved run (anything unknown or inconsistent is dropped, never guessed).
static func from_dict(d: Variant) -> Tier2:
	var t := Tier2.new()
	if d is Dictionary:
		for id in (d as Dictionary).get("unlocked", []):
			t.unlock(str(id))
		var eq := str((d as Dictionary).get("equipped", ""))
		if t.unlocked.has(eq):
			t.equipped = eq
	return t


## Smallest signed angle (radians, -PI..PI) from `from` to `to` about `axis`: +10 degrees and -10
## degrees (350) are both 10 degrees away, so a raw 0..360 comparison is never used.
static func signed_angle(from: Vector3, to: Vector3, axis: Vector3) -> float:
	var f := (from - axis * from.dot(axis)).normalized()
	var t := (to - axis * to.dot(axis)).normalized()
	return atan2(f.cross(t).dot(axis), f.dot(t))
