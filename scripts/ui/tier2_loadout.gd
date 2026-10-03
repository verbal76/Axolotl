class_name Tier2Loadout
extends HBoxContainer
## The pause menu's Tier-2 row (docs/TIER2.md): the three abilities as glyph buttons, with what is
## equipped beside them, all in one row (the landscape Settings panel, 00038). Found ones can be
## tapped to equip (exactly one is equipped: highlighted); ones not yet found are dim and locked.
## Equipping never resets the cooldown.

var _buttons := {}
var _name: Label


func _init() -> void:
	name = "Tier2Loadout"
	add_theme_constant_override("separation", 12)
	for id in Tier2.ORDER:
		var b := GlyphButton.new()
		b.ability = id
		b.name = "Tier2_" + id
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func(): _equip(id))
		add_child(b)
		_buttons[id] = b
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	add_child(words)
	var head := Label.new()
	head.text = "Tier 2 — tap to equip"
	head.add_theme_font_size_override("font_size", 20)
	words.add_child(head)
	_name = UiStyle.note("", 18)
	_name.name = "Tier2Name"
	words.add_child(_name)


func refresh() -> void:
	var g := Game.inst
	var t: Tier2 = g.tier2 if g != null else Tier2.new()
	visible = t.any()
	for id in _buttons:
		var b: GlyphButton = _buttons[id]
		b.unlocked = t.has(id)
		b.equipped = t.equipped == id
		b.disabled = not b.unlocked
		b.tooltip_text = Tier2.NAMES[id] if b.unlocked else "Not found yet"
		b.queue_redraw()
	if t.equipped != "":
		_name.text = "Equipped: %s — %s" % [Tier2.NAMES[t.equipped], Tier2.BLURBS[t.equipped]]


func _equip(id: String) -> void:
	var g := Game.inst
	if g == null or not g.tier2.equip(id):
		return
	g.save_run()
	Sfx.play("ui_tap", null, -6.0)
	refresh()


class GlyphButton extends Button:
	var ability := ""
	var unlocked := false
	var equipped := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		if equipped:
			draw_circle(c, r, Color(0.55, 0.9, 1.0, 0.28))
			draw_arc(c, r, 0, TAU, 40, Color(0.9, 1.0, 1.0, 0.95), 4.0, true)
		else:
			draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.35 if unlocked else 0.15), 2.0, true)
		var col := Color(1, 1, 1, 0.95) if unlocked else Color(1, 1, 1, 0.18)
		Tier2Glyphs.draw(self, ability, c, r * 0.5, col)
