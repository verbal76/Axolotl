class_name PadNav
extends Node
## Controller navigation for every menu page (owner, 2026-10-11: Steam Deck / Steam Machine
## requirements: "the default controller configuration must provide users with the ability to access
## all content", with no in-game setting needed). One rule set for all pages, so a page added later
## is navigable without its own controller code:
## - The first d-pad, stick or A press on a page where nothing has the focus puts the focus on that
##   page's first button (it does not also press it), and a page that opens while a controller is in
##   use takes the focus at once.
## - B goes back: it presses the topmost page's own back control ("‹ Back", "Back", "Close", "Cancel",
##   "Not now", "Done"), so it does exactly what tapping that does. In play with no menu open, B is
##   the Lunge, and on the bare title screen it does nothing (it never quits the game).
## (Focus moves between buttons by Godot's own ui_up/down/left/right, which the d-pad and left stick
## drive; the theme's gold ring shows where it is.)

const BACK_TEXTS := ["‹ back", "back", "close", "cancel", "not now", "done", "ok, got it"]

var game: Game
## For tests: what the last B press did ("" none, "pressed:<text>", "game_back", "ignored").
var last_back := ""
var _focus_t := 0.0


func _init(g: Game) -> void:
	game = g
	name = "PadNav"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(dt: float) -> void:
	# A page that opened while the controller is in use takes the focus without a first press.
	if Settings.input_mode != Settings.InputMode.PAD:
		return
	_focus_t -= dt
	if _focus_t > 0.0:
		return
	_focus_t = 0.15
	if not _focus_alive():
		var b := first_button()
		if b != null:
			b.grab_focus()


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if not event.is_pressed():
		return
	var nav := event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") \
			or event.is_action_pressed("ui_accept")
	if nav and not _focus_alive():
		var b := first_button()
		if b != null:
			b.grab_focus()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		if back():
			get_viewport().set_input_as_handled()


## Whether a visible control has the focus now.
func _focus_alive() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and f.is_visible_in_tree()


## B: the topmost page's own back control, else the game's back (never quitting from the title).
func back() -> bool:
	var b := back_button()
	if b != null:
		last_back = "pressed:" + b.text
		b.pressed.emit()
		return true
	if game == null:
		return false
	var menu_open := (game.pause_menu != null and game.pause_menu.visible) or (game.ball_view != null and game.ball_view.active) \
			or (game.presentation != null and game.presentation.active()) or (game.diagnostics != null and game.diagnostics.visible)
	if menu_open:
		last_back = "game_back"
		game._go_back()
		return true
	last_back = "ignored"
	return false


## Every visible, enabled, focusable button, in drawing order (later = on top).
func buttons() -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if game == null:
		return out
	_collect(game, out)
	out.sort_custom(func(a: BaseButton, b: BaseButton) -> bool: return _order(a) < _order(b))
	return out


func _collect(n: Node, out: Array[BaseButton]) -> void:
	for c in n.get_children():
		# (The 3D world holds no buttons: skipping it keeps this to the UI's few hundred nodes.)
		if c is Node3D or (c is CanvasItem and not (c as CanvasItem).visible):
			continue
		if c is BaseButton:
			var bb := c as BaseButton
			if bb.is_visible_in_tree() and not bb.disabled and bb.focus_mode != Control.FOCUS_NONE \
					and bb.mouse_filter != Control.MOUSE_FILTER_IGNORE and bb.get_global_rect().size.x > 0.0:
				out.append(bb)
		_collect(c, out)


## Sort key: canvas layer first, then position in the tree.
func _order(n: Node) -> Vector2:
	var layer := 0
	var p := n.get_parent()
	while p != null:
		if p is CanvasLayer:
			layer = (p as CanvasLayer).layer
			break
		p = p.get_parent()
	return Vector2(layer, _index_path(n))


func _index_path(n: Node) -> float:
	# (Depth-first position as one number: each level's index scaled under its parent's.)
	var chain: Array[int] = []
	var x := n
	while x != null and x != game:
		chain.push_front(x.get_index())
		x = x.get_parent()
	var v := 0.0
	var scale := 1.0
	for i in chain:
		scale /= 256.0
		v += (i + 1) * scale
	return v


## The page on top: the top-level control holding the topmost button.
func _page_of(b: Control) -> Node:
	var x: Node = b
	while x.get_parent() != null and not (x.get_parent() is CanvasLayer) and x.get_parent() != game:
		x = x.get_parent()
	return x


## The first button of the topmost page (a primary action if it has one).
func first_button() -> BaseButton:
	var all := buttons()
	if all.is_empty():
		return null
	var page := _page_of(all[-1])
	var first: BaseButton = null
	for b in all:
		if _page_of(b) != page:
			continue
		if b.theme_type_variation == "PrimaryButton":
			return b
		if first == null:
			first = b
	return first


## The topmost page's back control, or null.
func back_button() -> BaseButton:
	var all := buttons()
	if all.is_empty():
		return null
	var page := _page_of(all[-1])
	for i in range(all.size() - 1, -1, -1):
		var b := all[i]
		if _page_of(b) != page or not (b is Button):
			continue
		var t := (b as Button).text.strip_edges().to_lower()
		if t in BACK_TEXTS or t.begins_with("‹"):
			return b
	return null
