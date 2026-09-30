class_name SkillTreePage
extends Control
## The skill tree (docs/SKILL_TREE.md): a small landscape page beside the colours page in the pause
## menu, also opened from the title. The game stands still while it is open (the menu pauses play;
## on the title nothing runs). Families across, tiers down, the dependency links drawn between them.
## Each node shows its state: bought, can buy, too few starfish, or locked. Tapping one opens its
## card: what it does, what it costs, and exactly what is missing; buying happens only from the card,
## applies at once, and is answered with a small burst and a chime. No respec, no refunds.

signal done

## Column order (keeps the cross-family links short).
const COLUMNS := ["magnet", "lunge", "quick", "burst", "glide"]
const FAMILY_COLOURS := {
	"magnet": Color(0.62, 1.0, 0.55),
	"lunge": Color(0.98, 0.58, 0.68),
	"quick": Color(0.5, 0.97, 0.84),
	"burst": Color(0.45, 0.82, 1.0),
	"glide": Color(0.8, 0.68, 1.0),
}

var buttons := {}
var selected := ""
var tree_area: Control
var overlay: Control
var card: PanelContainer
var _card_title: Label
var _card_state: Label
var _card_effect: Label
var _card_need: Label
var _buy: Button
var _balance_label: Label
var _counts_label: Label
var _done: Button
var _header: HBoxContainer
## The last purchase's flourish: node id and time since.
var _flash_id := ""
var _flash_t := -1.0
var _sparks: Array = []
var last_result := ""


func _ready() -> void:
	name = "SkillTreePage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.05, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_header = HBoxContainer.new()
	_header.name = "Header"
	_header.add_theme_constant_override("separation", 18)
	add_child(_header)
	var title := Label.new()
	title.text = "Skills"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	_header.add_child(title)
	_balance_label = Label.new()
	_balance_label.name = "Balance"
	_balance_label.add_theme_font_size_override("font_size", 26)
	_balance_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.66))
	_balance_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_balance_label)
	_counts_label = UiStyle.note("", 20)
	_counts_label.name = "Counts"
	_counts_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counts_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_counts_label)
	tree_area = TreeArea.new()
	tree_area.name = "Tree"
	(tree_area as TreeArea).page = self
	add_child(tree_area)
	for f in COLUMNS:
		var cap := Label.new()
		cap.name = "Family_" + f
		cap.text = SkillTree.FAMILY_NAMES[f]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 19)
		cap.add_theme_color_override("font_color", Color(FAMILY_COLOURS[f], 0.95))
		tree_area.add_child(cap)
	for n in SkillTree.NODES:
		var id: String = n["id"]
		var b := Button.new()
		b.name = "Node_" + id.replace(".", "_")
		b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void: select(id))
		b.focus_entered.connect(func() -> void: select(id, false))
		tree_area.add_child(b)
		buttons[id] = b
	overlay = Overlay.new()
	overlay.name = "Overlay"
	(overlay as Overlay).page = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_area.add_child(overlay)
	card = PanelContainer.new()
	card.name = "Card"
	var box := UiStyle._box(Color(UiStyle.PANEL, 0.97), Color(UiStyle.MINT, 0.35))
	box.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", box)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	_card_title = Label.new()
	_card_title.name = "CardTitle"
	_card_title.add_theme_font_size_override("font_size", 27)
	_card_title.add_theme_color_override("font_color", UiStyle.GOLD)
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_card_title)
	_card_state = UiStyle.note("", 19)
	_card_state.name = "CardState"
	v.add_child(_card_state)
	_card_effect = Label.new()
	_card_effect.name = "CardEffect"
	_card_effect.add_theme_font_size_override("font_size", 22)
	_card_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_card_effect)
	_card_need = Label.new()
	_card_need.name = "CardNeed"
	_card_need.add_theme_font_size_override("font_size", 20)
	_card_need.add_theme_color_override("font_color", Color(1.0, 0.78, 0.6))
	_card_need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_card_need)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_buy = UiStyle.button("Unlock", _on_buy)
	_buy.name = "Unlock"
	_buy.theme_type_variation = "PrimaryButton"
	_buy.custom_minimum_size = Vector2(0, 62)
	v.add_child(_buy)
	_done = UiStyle.button("Done", func() -> void: done.emit())
	_done.name = "Done"
	_done.custom_minimum_size = Vector2(0, 58)
	v.add_child(_done)
	# Controller: up and down along a family, left and right across a tier; right of the last column
	# is the card's button.
	for n in SkillTree.NODES:
		var b: Button = buttons[n["id"]]
		var c := COLUMNS.find(n["family"])
		var tier := int(n["tier"])
		if tier > 1:
			b.focus_neighbor_top = b.get_path_to(buttons["%s.%d" % [n["family"], tier - 1]])
		if tier < 3:
			b.focus_neighbor_bottom = b.get_path_to(buttons["%s.%d" % [n["family"], tier + 1]])
		if c > 0:
			b.focus_neighbor_left = b.get_path_to(buttons["%s.%d" % [COLUMNS[c - 1], tier]])
		b.focus_neighbor_right = b.get_path_to(buttons["%s.%d" % [COLUMNS[c + 1], tier]]) if c < COLUMNS.size() - 1 else b.get_path_to(_buy)
	_buy.focus_neighbor_left = _buy.get_path_to(buttons["glide.1"])
	_done.focus_neighbor_left = _done.get_path_to(buttons["glide.3"])
	get_viewport().size_changed.connect(_layout)
	_layout()


## Lays the page out for the current landscape shape (1280x720 up to a narrow 19.5:9 phone).
func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := clampf(vp.y / 720.0, 0.75, 1.4)
	var m := Vector2(28, 18) * s
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x > 0 and safe.size.x > 0:
		m.x = maxf(m.x, safe.position.x * vp.x / win.x + 8)
	_header.position = m
	_header.size = Vector2(vp.x - m.x * 2, 50 * s)
	var card_w := clampf(vp.x * 0.3, 330 * s, 440 * s)
	var top := m.y + 60 * s
	card.position = Vector2(vp.x - m.x - card_w, top)
	card.size = Vector2(card_w, vp.y - top - m.y)
	card.custom_minimum_size = card.size
	tree_area.position = Vector2(m.x, top)
	tree_area.size = Vector2(vp.x - card_w - m.x * 3, vp.y - top - m.y)
	var cols := COLUMNS.size()
	var cw := tree_area.size.x / cols
	var rh := (tree_area.size.y - 40 * s) / 3.0
	var bw := minf(cw - 18 * s, 170 * s)
	var bh := minf(rh * 0.56, 92 * s)
	for c in cols:
		var cap: Label = tree_area.get_node("Family_" + COLUMNS[c])
		cap.position = Vector2(c * cw, 0)
		cap.size = Vector2(cw, 30 * s)
		cap.add_theme_font_size_override("font_size", int(19 * s))
	for n in SkillTree.NODES:
		var b: Button = buttons[n["id"]]
		var c := COLUMNS.find(n["family"])
		var r := int(n["tier"]) - 1
		b.size = Vector2(bw, bh)
		b.custom_minimum_size = b.size
		b.position = Vector2(c * cw + (cw - bw) * 0.5, 40 * s + r * rh + (rh - bh) * 0.5)
		b.pivot_offset = b.size * 0.5
		b.add_theme_font_size_override("font_size", int(clampf(bh * 0.27, 17, 26)))
	tree_area.queue_redraw()


func open() -> void:
	refresh()
	visible = true
	var first := selected if selected != "" else _first_focus()
	select(first, false)
	(buttons[first] as Button).grab_focus.call_deferred()


func _first_focus() -> String:
	var g := Game.inst
	for n in SkillTree.NODES:
		if g != null and g.gill != null and g.gill.node_state(n["id"]) == "available":
			return n["id"]
	return "lunge.1"


func _gp() -> GillProgress:
	return Game.inst.gill if Game.inst != null else null


func node_state(id: String) -> String:
	var gp := _gp()
	return gp.node_state(id) if gp != null else "locked"


func refresh() -> void:
	var gp := _gp()
	if gp == null:
		return
	_balance_label.text = "%d to spend" % gp.balance()
	_counts_label.text = "Red Starfish %d/%d  ·  Skills %d/%d" % [gp.stars(), StarfishTable.COUNT, gp.skills(), SkillTree.COUNT]
	for n in SkillTree.NODES:
		var id: String = n["id"]
		var b: Button = buttons[id]
		var st := node_state(id)
		var fam: Color = FAMILY_COLOURS[n["family"]]
		b.text = SkillTree.ROMAN[int(n["tier"])] + ("" if st == "purchased" else "   %d" % int(n["cost"]))
		b.set_meta("state", st)
		var bg: Color
		var edge: Color
		var ink := UiStyle.INK
		match st:
			"purchased":
				bg = fam.darkened(0.25)
				edge = UiStyle.GOLD
				ink = Color(0.1, 0.05, 0.02)
			"available":
				bg = Color(0.07, 0.24, 0.22, 0.95)
				edge = fam
			"unaffordable":
				bg = Color(0.05, 0.16, 0.16, 0.9)
				edge = Color(fam, 0.45)
				ink = Color(UiStyle.INK, 0.7)
			_:
				bg = Color(0.04, 0.09, 0.1, 0.85)
				edge = Color(0.5, 0.6, 0.6, 0.3)
				ink = Color(UiStyle.INK, 0.4)
		var normal := UiStyle._box(bg, edge, 3 if st == "available" or st == "purchased" else 2)
		for key in ["normal", "hover", "pressed", "hover_pressed", "focus_normal"]:
			b.add_theme_stylebox_override(key, normal)
		var hover := UiStyle._box(bg.lightened(0.08), UiStyle.GOLD, 3)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, ink)
	if selected != "":
		_fill_card(selected)
	tree_area.queue_redraw()


func select(id: String, sound := true) -> void:
	selected = id
	_fill_card(id)
	if sound:
		Sfx.play("ui_tap", null, -8.0)
	tree_area.queue_redraw()


## The card: the node's name, its state, what it does, and what is missing or what it costs.
func _fill_card(id: String) -> void:
	var gp := _gp()
	var st := node_state(id)
	var c := SkillTree.cost(id)
	_card_title.text = SkillTree.title(id)
	_card_effect.text = SkillTree.EFFECTS.get(id, "")
	_buy.visible = st != "purchased"
	_buy.disabled = st != "available"
	_buy.text = "Unlock  (%d)" % c
	match st:
		"purchased":
			_card_state.text = "Unlocked"
			_card_need.text = ""
		"available":
			_card_state.text = "Ready to unlock"
			_card_need.text = "Costs %d red starfish. You have %d to spend." % [c, gp.balance() if gp else 0]
		"unaffordable":
			_card_state.text = "Not enough red starfish"
			var have := gp.balance() if gp else 0
			_card_need.text = "Needs %d red starfish; you have %d. Find %d more." % [c, have, c - have]
		_:
			_card_state.text = "Locked"
			var names: Array[String] = []
			for r in SkillTree.missing(id, gp.purchased if gp else {}):
				names.append(SkillTree.title(r).get_slice(":", 0))
			_card_need.text = "Unlock %s first." % _join_and(names)
	if last_result != "" and st != "purchased":
		_card_need.text += "\n" + last_result


static func _join_and(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


func _on_buy() -> void:
	buy(selected)


## Buys the selected node (the card's button). Returns "" when bought, else why not.
func buy(id: String) -> String:
	var g := Game.inst
	var why := g.buy_skill(id) if g != null else "no game"
	last_result = "" if why == "" else ("Could not save; nothing was spent." if why == "not saved" else "")
	if why == "":
		_flash_id = id
		_flash_t = 0.0
		var b: Button = buttons[id]
		var c := b.position + b.size * 0.5
		var fam: Color = FAMILY_COLOURS[SkillTree.node(id)["family"]]
		for i in 26:
			var a := TAU * i / 26.0
			_sparks.append([c, Vector2(cos(a), sin(a)) * (140.0 + 60.0 * float(i % 3)), fam if i % 2 == 0 else UiStyle.GOLD])
		Sfx.play("skill_unlock", null, -3.0)
		Settings.haptic("heavy")
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(b, "scale", Vector2.ONE, 0.25)
	refresh()
	return why


func flash_amount() -> float:
	return 0.0 if _flash_t < 0.0 else clampf(1.0 - _flash_t / 0.9, 0.0, 1.0)


func _process(dt: float) -> void:
	if not visible:
		return
	if _flash_t >= 0.0:
		_flash_t += dt
		if _flash_t > 0.9:
			_flash_t = -1.0
			_sparks.clear()
		tree_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		done.emit()
		get_viewport().set_input_as_handled()


## The dependency links, drawn under the node buttons: a soft S from a prerequisite's foot to the
## node's head, or straight across between neighbours in the same tier. Gold once the prerequisite
## is owned; the selected node's links brighter.
class TreeArea extends Control:
	var page: SkillTreePage

	func _draw() -> void:
		var gp := page._gp()
		for n in SkillTree.NODES:
			var b: Button = page.buttons[n["id"]]
			for r in n["requires"]:
				var rb: Button = page.buttons[r]
				var owned := gp != null and gp.owns(r)
				var sel: bool = page.selected == n["id"] or page.selected == r
				var col := Color(UiStyle.GOLD, 0.9) if owned else Color(0.6, 0.8, 0.78, 0.4)
				if sel:
					col = col.lightened(0.25)
					col.a = 1.0
				var w := 5.0 if sel else 3.5
				var from: Vector2
				var to: Vector2
				var pts := PackedVector2Array()
				if absf(rb.position.y - b.position.y) < 1.0:
					var left := rb.position.x < b.position.x
					from = rb.position + Vector2(rb.size.x if left else 0.0, rb.size.y * 0.5)
					to = b.position + Vector2(0.0 if left else b.size.x, b.size.y * 0.5)
					pts = PackedVector2Array([from, to])
				else:
					from = rb.position + Vector2(rb.size.x * 0.5, rb.size.y)
					to = b.position + Vector2(b.size.x * 0.5, 0)
					var mid := (from.y + to.y) * 0.5
					for i in 17:
						var t := float(i) / 16.0
						var p0 := from.lerp(Vector2(from.x, mid), t)
						var p1 := Vector2(from.x, mid).lerp(Vector2(to.x, mid), t)
						var p2 := Vector2(to.x, mid).lerp(to, t)
						pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
				draw_polyline(pts, col, w, true)
				draw_circle(to, w * 1.1, col)
		if page.overlay != null:
			page.overlay.queue_redraw()


## Drawn over the node buttons: each node's red-star cost (bright when it can be bought, faded when
## there are too few), a lock on locked ones, and the unlock flourish (a ring and sparks).
class Overlay extends Control:
	var page: SkillTreePage

	func _draw() -> void:
		for n in SkillTree.NODES:
			var b: Button = page.buttons[n["id"]]
			var st := str(b.get_meta("state", "locked"))
			var r := b.size.y * 0.15
			var c := b.position + Vector2(b.size.x - r * 1.9, b.size.y * 0.5)
			if st == "purchased":
				continue
			if st == "locked":
				var lc := Color(0.75, 0.82, 0.8, 0.5)
				draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 1.1)), lc)
				draw_arc(c + Vector2(0, -r * 0.1), r * 0.5, PI, TAU, 10, lc, 2.0)
			else:
				StarChip.draw_star(self, c, r * 1.1, Color(0.95, 0.2, 0.16, 1.0 if st == "available" else 0.45))
		var k := page.flash_amount()
		if k > 0.0 and page.buttons.has(page._flash_id):
			var b: Button = page.buttons[page._flash_id]
			var c := b.position + b.size * 0.5
			var t := 1.0 - k
			draw_arc(c, b.size.x * (0.4 + 0.5 * t), 0, TAU, 40, Color(UiStyle.GOLD, k), 4.0 * k + 1.0)
			for sp in page._sparks:
				var p: Vector2 = sp[0] + (sp[1] as Vector2) * t * (1.0 - 0.4 * t)
				draw_circle(p, 5.0 * k + 1.0, Color(sp[2], k))
