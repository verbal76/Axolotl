class_name StudioSplash
extends CanvasLayer
## GAME LAYER — the Hot Attic Games studio splash (docs/HOT_ATTIC_INFRA.md §4).
##
## Black, the canonical studio logo centred and contain-fitted (aspect kept), about 1.5 s, silent,
## on a genuine launch only: never after Return to Title / New Run (scene reloads) or an
## in-process update, never in automated test runs. It covers Mote's loading screen while the world
## builds underneath (it delays nothing: the stages run one per frame behind it) and needs no
## network. Shown only when the canonical asset exists in the build; otherwise skipped entirely
## (no placeholder art) and the reason is in the startup timeline.
## The engine boot splash before it (boot_splash/* in project.godot) is native and unchanged.

const LOGO_PATH := "res://branding/Hot_Attic_Games_Master_Logo.png"
## Engine metadata: this process already decided (survives scene reloads and soft restarts).
const META := "hag_studio_splash"
const SHOW_S := 1.25
const FADE_S := 0.25
## Fraction of the screen the logo may use on each side (contain-fit inside it).
const MARGIN := 0.12
const MISSING := "CANONICAL HOT ATTIC GAMES ASSET MISSING"
## Tests point this at another image.
static var logo_path := LOGO_PATH

var texture: Texture2D
var logo: TextureRect
var _t0 := -1


## "" when the splash should show now, otherwise why not. Pure (unit-tested).
static func decide(path: String, test_mode: String, already_decided: bool, soft_restarted: bool) -> String:
	if already_decided or soft_restarted:
		return "not a genuine launch (scene reload or in-process update)"
	if test_mode != "":
		return "automated test run"
	if path == "" or not ResourceLoader.exists(path):
		return "%s (%s)" % [MISSING, path]
	return ""


## Adds the splash under `parent` if this is a genuine launch and the logo exists; returns it or
## null. Decides once per process.
static func maybe_show(parent: Node, test_mode := "", soft_restarted := false) -> StudioSplash:
	var why := decide(logo_path, test_mode, Engine.has_meta(META), soft_restarted)
	if not Engine.has_meta(META):
		Engine.set_meta(META, why if why != "" else "shown")
		StartupTrace.mark("game: studio splash %s" % ("shown" if why == "" else "skipped: " + why))
	if why != "":
		return null
	var tex := load(logo_path) as Texture2D
	if tex == null:
		return null
	var s := StudioSplash.new()
	s.texture = tex
	parent.add_child(s)
	return s


func _ready() -> void:
	name = "StudioSplash"
	# Above Mote's loading screen (100). (The update modal, 101, only appears after the world is
	# built, when this has long gone; a soft restart frees it with the rest of the game anyway.)
	layer = 102
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.name = "Black"
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	logo = TextureRect.new()
	logo.name = "Logo"
	logo.texture = texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.anchor_left = MARGIN
	logo.anchor_top = MARGIN
	logo.anchor_right = 1.0 - MARGIN
	logo.anchor_bottom = 1.0 - MARGIN
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(logo)


## The rectangle the logo is actually drawn in (contain-fit, centred), in screen coordinates.
func drawn_rect() -> Rect2:
	var box := logo.get_global_rect()
	var ts := texture.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz := ts * k
	return Rect2(box.position + (box.size - sz) / 2.0, sz)


func _process(_dt: float) -> void:
	# Wall time from the first frame it was on screen: world-building frames are long, and the
	# splash must not outstay its time (it would delay the title) nor count frames.
	var now := Time.get_ticks_msec()
	if _t0 < 0:
		_t0 = now
	var t := (now - _t0) / 1000.0
	if t > SHOW_S:
		var a := clampf(1.0 - (t - SHOW_S) / FADE_S, 0.0, 1.0)
		(get_child(0) as CanvasItem).modulate.a = a
		if a <= 0.0:
			queue_free()
