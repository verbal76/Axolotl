class_name FieldGuidePage
extends Control
## The Field guide (owner, 2026-10-08, the holistic tutorial pass): the permanent reference for what
## the lessons teach, opened from the pause menu at any time. One calm page, nothing to scroll and
## nothing to earn: what heals Gill, what heals the moss, what hurts, and how travel works. Each
## entry is a name (coloured by what it is to Gill) and one or two short lines. The Pearl's entry
## stays a mystery until one has been found (pearls are not food; docs/ONBOARDING.md).

signal done

const FOOD := Color(0.66, 1.0, 0.55)
const THREAT := Color(1.0, 0.56, 0.5)
const MOSS := Color(0.5, 0.95, 0.9)
const ITEM := Color(1.0, 0.85, 0.5)

## [name, colour, text]. Order: Gill, food, the moss, threats, travel, finds.
static func entries(pearl_found: bool) -> Array:
	var gill := GameVersion.CHARACTER_NAME
	return [
		["%s's fronds" % gill, FOOD, "His glowing fronds are his health. Food brings them back; they do not regrow on their own."],
		["Food: Shrimp, Water flea, Worm", FOOD, "Lunge at food to eat it: the lunge homes in on food just ahead. Shrimp heal 1 frond, water fleas 2, worms every frond."],
		["Motes", MOSS, "Glowing jellyfish. Lunge to catch them: each one helps the moss recover. They are not food."],
		["Restoring the moss", MOSS, "Every parasite removed and Mote caught brings a moss ball back to life. Its progress is in this menu."],
		["Parasites", THREAT, "They hurt %s and sicken the moss. Tail Swipe them to defeat them." % gill],
		["Spitters", THREAT, "Spit globs from afar. Tail Swipe as a glob reaches you to bat it back at them."],
		["Ravine ooze", THREAT, "The dark ooze at a ravine's bottom is deadly. Jump the gaps, or go round."],
		["Water tunnels", MOSS, "At 70% restored a ball's tunnels open and their pads turn green. Each tunnel keeps its colour, both ends: it is the way back."],
		["Red Starfish", ITEM, "Spend them on new abilities in Skills."],
		["Pearl", ITEM, "A rare pearl, found deep in a grotto. It refills every frond." if pearl_found else "Something rare is hidden in the grottoes..."],
	]

var _shade: ColorRect
var _backdrop: Panel
var _title: Label
var _grid: GridContainer
var _done: Button
var _cells: Array = []


func _ready() -> void:
	name = "FieldGuidePage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(0.0, 0.05, 0.05, 0.9)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_backdrop = Panel.new()
	_backdrop.name = "Backdrop"
	var bs := UiStyle._box(Color(UiStyle.PANEL, 0.97), Color(UiStyle.MINT, 0.22))
	bs.set_corner_radius_all(26)
	_backdrop.add_theme_stylebox_override("panel", bs)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "Field guide"
	_title.add_theme_color_override("font_color", UiStyle.GOLD)
	add_child(_title)
	_grid = GridContainer.new()
	_grid.name = "Entries"
	_grid.columns = 2
	add_child(_grid)
	_done = UiStyle.button("Done", func() -> void: done.emit())
	_done.name = "Done"
	add_child(_done)
	refresh()
	get_viewport().size_changed.connect(_layout)


func refresh() -> void:
	for c in _cells:
		c.queue_free()
	_cells.clear()
	for e in entries(pearl_found()):
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 2)
		var head := Label.new()
		head.name = "Name"
		head.text = e[0]
		head.add_theme_color_override("font_color", e[1])
		box.add_child(head)
		var body := UiStyle.note(e[2])
		body.name = "Text"
		box.add_child(body)
		_grid.add_child(box)
		_cells.append(box)
	_layout()


## Whether a pearl has been found this run (its entry is a mystery until then).
static func pearl_found() -> bool:
	var g := Game.inst
	if g == null:
		return false
	for b in g.balls:
		for u in b.upgrades:
			if u.get("kind") == "pearl" and bool(u.get("taken")):
				return true
	return false


func open() -> void:
	refresh()
	visible = true
	_done.grab_focus.call_deferred()


## Every entry's name and text, in order (tests).
func texts() -> Array[String]:
	var out: Array[String] = []
	for c in _cells:
		out.append((c.get_node("Name") as Label).text)
		out.append((c.get_node("Text") as Label).text)
	return out


func _layout() -> void:
	if _grid == null:
		return
	layout_in(UiStyle.safe_rect(get_viewport(), Vector4(24, 16, 24, 16)))


## Lays the page out in `area` (tests stand a phone's screen in with this).
func layout_in(area: Rect2) -> void:
	var vp := get_viewport_rect().size
	var s := clampf(area.size.y / 720.0, 0.7, 1.4)
	_shade.position = Vector2.ZERO
	_shade.size = vp
	_backdrop.position = area.position
	_backdrop.size = area.size
	var pad := Vector2(26, 18) * s
	_title.position = area.position + pad
	_title.add_theme_font_size_override("font_size", int(32 * s))
	var bh := 58.0 * s
	var bw := 220.0 * s
	_done.custom_minimum_size = Vector2(bw, bh)
	_done.size = Vector2(bw, bh)
	_done.add_theme_font_size_override("font_size", int(24 * s))
	_done.position = Vector2(area.end.x - pad.x - bw, area.position.y + pad.y * 0.6)
	var top := area.position.y + pad.y + bh + 6 * s
	_grid.position = Vector2(area.position.x + pad.x, top)
	_grid.size = Vector2(area.size.x - pad.x * 2, area.end.y - pad.y - top)
	_grid.add_theme_constant_override("h_separation", int(30 * s))
	_grid.add_theme_constant_override("v_separation", int(16 * s))
	var col_w := (_grid.size.x - 30 * s) / 2.0
	for c in _cells:
		c.custom_minimum_size = Vector2(col_w, 0)
		(c.get_node("Name") as Label).add_theme_font_size_override("font_size", int(25 * s))
		var t := c.get_node("Text") as Label
		t.add_theme_font_size_override("font_size", int(21 * s))
		t.custom_minimum_size = Vector2(col_w, 0)


## Whether every entry sits inside the page (nothing cut off, nothing to scroll; tests).
func fits() -> bool:
	var bottom := _backdrop.get_global_rect().end.y
	for c in _cells:
		if (c as Control).get_global_rect().end.y > bottom + 0.5:
			return false
	return true
