class_name RunClock
extends RefCounted
## The run timer: accumulated in-game time, owned by the run save (never by the app session).
##
## Rules (docs/COMPLETION.md):
## - START: the first frame of play in a new run (Game.start_play on a run whose clock has not
##   started: Play/New Run from the title, or an automated run).
## - TIMED: every processed frame while the game is in play: moving, fighting, cinematics
##   (vortex travel, regeneration), all count.
## - NOT TIMED: the title screen, the pause menu (the tree is paused, so nothing ticks), the app in
##   the background (suspend/resume below), loading. The frame after a resume is discarded, and a
##   single frame counts at most MAX_FRAME_S, so a stall or a resume never adds hidden time.
## - FINISH: the frame the last moss ball becomes fully restored (Game._on_event_restored). The
##   finish time is frozen then; play afterwards only adds to play_s.
## - Time is the engine's frame delta summed in float64 seconds: never the wall clock, so device
##   clock and time-zone changes cannot affect it, and the same simulated play gives the same time
##   at any frame rate (to within one frame).

const MAX_FRAME_S := 0.25
## Bump if the timing rules above change (recorded with each finish).
const TIMER_MODEL := 1

var state := "not_started"   # not_started | running | finished
## Timed gameplay up to the finish (frozen once finished).
var run_s := 0.0
## All timed gameplay in this run, including after the finish.
var play_s := 0.0
## The frozen finish time (-1 until finished).
var finish_s := -1.0
var suspended := false
var _skip_next := false


func start() -> bool:
	if state != "not_started":
		return false
	state = "running"
	return true


func is_finished() -> bool:
	return state == "finished"


## One processed frame. `active`: the game is in play (not title, not paused).
func tick(dt: float, active: bool) -> void:
	if state == "not_started" or not active or suspended:
		return
	if _skip_next:
		_skip_next = false
		return
	var d := clampf(dt, 0.0, MAX_FRAME_S)
	play_s += d
	if state == "running":
		run_s += d


## Freezes the finish time. False when already finished (the first finish is the record).
func finish() -> bool:
	if state != "running":
		return false
	state = "finished"
	finish_s = run_s
	return true


## The app went to the background (or lost focus): stop counting.
func suspend() -> void:
	suspended = true


## Back in the foreground: count again from the frame after next.
func resume() -> void:
	if suspended:
		suspended = false
		_skip_next = true


## The time players see: the frozen finish time once finished, else the running time.
func shown_s() -> float:
	return finish_s if state == "finished" else run_s


func to_dict() -> Dictionary:
	return {"state": state, "run_s": run_s, "play_s": play_s, "finish_s": finish_s, "timer_model": TIMER_MODEL}


static func from_dict(d: Dictionary) -> RunClock:
	var c := RunClock.new()
	var st := str(d.get("state", "not_started"))
	c.state = st if st in ["not_started", "running", "finished"] else "not_started"
	c.run_s = maxf(0.0, float(d.get("run_s", 0.0)))
	c.play_s = maxf(c.run_s, float(d.get("play_s", c.run_s)))
	c.finish_s = float(d.get("finish_s", -1.0))
	if c.state == "finished" and c.finish_s < 0.0:
		c.finish_s = c.run_s
	return c


## "12.34", "4:05.67", "1:02:03.45" (hours grow as needed; centiseconds, truncated).
static func format(s: float, cs := true) -> String:
	if s < 0.0:
		return "--"
	var total_cs := int(floor(s * 100.0 + 1e-6))
	var c := total_cs % 100
	var secs := (total_cs / 100) % 60
	var mins := (total_cs / 6000) % 60
	var hours := total_cs / 360000
	var out := ""
	if hours > 0:
		out = "%d:%02d:%02d" % [hours, mins, secs]
	elif mins > 0:
		out = "%d:%02d" % [mins, secs]
	else:
		out = "%d" % secs
	return out + (".%02d" % c if cs else "")
