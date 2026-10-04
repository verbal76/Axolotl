class_name LoadingScreen
extends CanvasLayer
## Mote's first frame: drawn before the world is built, so launching never looks dead.
## Deliberately cheap: a colour, the owner's axolotl artwork, MOTE in the title-screen colours,
## and a line naming the stage actually being worked on. No percentages: the stages are not
## equal in length. It shows under the Hot Attic Games splash and is revealed when that fades
## (launch order: neutral native frame → studio splash → this). The r5 APK's engine boot splash
## still draws this same artwork first; from runtime r6 the boot frame is neutral black.

const BG := Color(0.04, 0.1, 0.1, 1.0)
const ART := preload("res://assets/icon/splash.png")
## The engine draws the boot splash at its own 320 px on the physical screen; the artwork here is
## sized to the same physical size on any screen, so the hand-over does not jump.
const SPLASH_PX := 320.0

var status_label: Label
## Every stage shown, in order (for the startup tests).
var stages: Array[String] = []
var _dots := 0.0
var _stage := ""
var _fade := -1.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var win := DisplayServer.window_get_size()
	var art_size := SPLASH_PX * get_viewport().get_visible_rect().size.y / float(win.y) if win.y > 0 else 213.0
	art_size = clampf(art_size, 150.0, 360.0)
	var art := TextureRect.new()
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_CENTER)
	art.offset_left = -art_size / 2.0
	art.offset_right = art_size / 2.0
	art.offset_top = -art_size / 2.0
	art.offset_bottom = art_size / 2.0
	bg.add_child(art)
	var title := Label.new()
	title.text = GameVersion.title()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.16, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	_around_art(title, -art_size / 2.0 - 130.0, -art_size / 2.0 - 16.0)
	bg.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.75))
	_around_art(status_label, art_size / 2.0 + 22.0, art_size / 2.0 + 60.0)
	bg.add_child(status_label)
	set_stage("Starting")


## A full-width band at a vertical offset from the screen centre.
func _around_art(c: Control, top: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_top = top
	c.offset_bottom = bottom


## Names the stage now running ("Growing moss ball 2 of 3"). Shown with a gentle ellipsis.
func set_stage(text: String) -> void:
	_stage = text
	stages.append(text)
	_dots = 0.0
	status_label.text = text + "..."


func stage() -> String:
	return _stage


## Fades out and frees itself (the world underneath is already drawn).
func finish() -> void:
	_fade = 0.0


func _process(dt: float) -> void:
	if _fade >= 0.0:
		_fade += dt
		var a := clampf(1.0 - _fade / 0.35, 0.0, 1.0)
		for c in get_children():
			(c as CanvasItem).modulate.a = a
		if a <= 0.0:
			queue_free()
		return
	# A cheap sign of life that starts with the very first frame.
	_dots = fmod(_dots + dt * 2.5, 4.0)
	status_label.text = _stage + ".".repeat(int(_dots))
