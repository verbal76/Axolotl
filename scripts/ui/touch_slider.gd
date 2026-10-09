class_name TouchSlider
extends HSlider
## A menu slider a finger cannot move by accident (phone audit 2026-09-30 §A: a swipe that started
## on the Body slider recoloured Gill). It takes hold only on its thumb or its track:
## - a drag that starts on the thumb moves it, once the finger has gone sideways (a finger that goes
##   up or down first never changes it);
## - a tap on the track (press and release without moving) jumps it there;
## - anything else, including a swipe that starts on the track away from the thumb, changes nothing.
## The mouse wheel never changes it. Controller and keyboard steps work as on any slider.

## How far either side of the thumb's centre a finger takes it (design px).
const THUMB_REACH := 30.0
## Half the height of the track's touch band, about its centre line (design px).
const TRACK_BAND := 20.0
## How far a finger moves before it counts as a drag, not a tap (design px).
const SLOP := 12.0

var _state := ""          # "", "thumb", "track" or "dead" while a press lasts
var _press := Vector2.ZERO
var _press_ratio := 0.0
var _moved := false


func _init() -> void:
	scrollable = false
	custom_minimum_size = Vector2(0, 56)


## The thumb's centre along the slider, in its own coordinates (as Slider draws it).
func thumb_x() -> float:
	var gw := _grab_w()
	return get_as_ratio() * (size.x - gw) + gw * 0.5


## The ratio (0..1) a tap at local `x` stands for.
func ratio_at(x: float) -> float:
	var gw := _grab_w()
	return clampf((x - gw * 0.5) / maxf(size.x - gw, 1.0), 0.0, 1.0)


func _grab_w() -> float:
	var gi := get_theme_icon("grabber")
	return float(gi.get_width()) if gi != null else 0.0


func _gui_input(e: InputEvent) -> void:
	# (Touches arrive as emulated mouse events too; they are handled once, from those.)
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		accept_event()
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_press_ratio = get_as_ratio()
				_moved = false
				if absf(mb.position.x - thumb_x()) <= THUMB_REACH:
					_state = "thumb"
				elif absf(mb.position.y - size.y * 0.5) <= TRACK_BAND:
					_state = "track"
				else:
					_state = "dead"
			else:
				if _state == "track" and not _moved:
					set_as_ratio(ratio_at(mb.position.x))
				_state = ""
		# (The wheel and other buttons: nothing.)
		accept_event()
	elif e is InputEventMouseMotion:
		if _state == "":
			return
		var d := (e as InputEventMouseMotion).position - _press
		if not _moved and d.length() > SLOP:
			_moved = true
			if _state == "thumb" and absf(d.y) > absf(d.x):
				_state = "dead"
		if _state == "thumb" and _moved:
			set_as_ratio(clampf(_press_ratio + d.x / maxf(size.x - _grab_w(), 1.0), 0.0, 1.0))
		accept_event()
