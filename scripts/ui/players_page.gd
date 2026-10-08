class_name PlayersPage
extends Control
## Who's playing? (owner, 2026-10-08; Players): opened from the title's player button. One row per
## player (up to Players.MAX): tap a name to play as them (their own run, Skills and colours; every
## character is still Gill), Rename, and Delete behind a confirm (never the first player, whose save
## is the original one). New player asks for a name. Nothing scrolls.

signal done

var _shade: ColorRect
var _panel: PanelContainer
var _list: VBoxContainer
var _new: Button
var _back: Button
## The name prompt (new player or rename): a line edit with OK / Cancel.
var _ask: VBoxContainer
var _ask_label: Label
var _edit: LineEdit
var _ask_id := ""
var _note: Label   # "" = a new player, else the player being renamed


func _ready() -> void:
	name = "PlayersPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.theme()
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.05, 0.05, 0.88)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Who's playing?"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_back = UiStyle.button("‹ Back", func() -> void: done.emit())
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(180, 60)
	head.add_child(_back)
	_note = UiStyle.note("Each player has their own run, Skills and colours. Everyone's axolotl is %s." % GameVersion.CHARACTER_NAME, 20)
	v.add_child(_note)
	# (The name prompt sits high on the page: the phone's keyboard covers the lower half.)
	_ask = VBoxContainer.new()
	_ask.name = "Ask"
	_ask.add_theme_constant_override("separation", 8)
	_ask.visible = false
	v.add_child(_ask)
	_ask_label = UiStyle.note("", 22)
	_ask.add_child(_ask_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_ask.add_child(row)
	_edit = LineEdit.new()
	_edit.name = "Name"
	_edit.max_length = Players.NAME_MAX
	_edit.placeholder_text = "Name"
	_edit.custom_minimum_size = Vector2(320, 60)
	_edit.add_theme_font_size_override("font_size", 26)
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.text_submitted.connect(func(_t: String) -> void: _on_ok())
	row.add_child(_edit)
	var ok := UiStyle.button("OK", _on_ok)
	ok.name = "OK"
	ok.custom_minimum_size = Vector2(120, 60)
	row.add_child(ok)
	var cancel := UiStyle.button("Cancel", _close_ask)
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(150, 60)
	row.add_child(cancel)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	_new = UiStyle.button("New player", func() -> void: _open_ask(""))
	_new.name = "NewPlayer"
	_new.custom_minimum_size = Vector2(0, 60)
	v.add_child(_new)
	visible = false
	get_viewport().size_changed.connect(_layout)


func open() -> void:
	_close_ask()
	refresh()
	visible = true
	_layout()
	_back.grab_focus.call_deferred()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var cur := Players.current()
	for e in Players.list():
		var id := str(e["id"])
		var row := HBoxContainer.new()
		row.name = "Row_" + id
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)
		var pick := UiStyle.button(("%s  (playing)" % e["name"]) if id == cur else str(e["name"]), func() -> void: _pick(id))
		pick.name = "Pick"
		pick.custom_minimum_size = Vector2(0, 60)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_theme_font_size_override("font_size", 26)
		row.add_child(pick)
		var ren := UiStyle.button("Rename", func() -> void: _open_ask(id))
		ren.name = "Rename"
		ren.custom_minimum_size = Vector2(140, 60)
		row.add_child(ren)
		if id != Players.MAIN:
			var del := UiStyle.confirm_button("Delete", "Delete %s and their saves for good?" % e["name"], "Delete", func() -> void: _delete(id))
			del.name = "Delete"
			(del.get_node("Ask") as Button).custom_minimum_size = Vector2(140, 60)
			row.add_child(del)
	_new.visible = Players.can_add()


func _pick(id: String) -> void:
	if id == Players.current():
		done.emit()
		return
	Game.inst.switch_player(id)


func _delete(id: String) -> void:
	var was_current := id == Players.current()
	Players.remove(id)
	if was_current:
		# (Their run is gone: back to the first player, from the title.)
		Settings.load_player_look()
		Settings.skip_title = false
		get_tree().reload_current_scene()
		return
	refresh()
	_layout()


func _open_ask(id: String) -> void:
	_ask_id = id
	_ask_label.text = "New player's name:" if id == "" else "New name for %s:" % Players.name_of(id)
	_edit.text = "" if id == "" else Players.name_of(id)
	_ask.visible = true
	_new.visible = false
	_layout()
	_edit.grab_focus.call_deferred()


func _close_ask() -> void:
	_ask.visible = false
	_new.visible = Players.can_add()
	_layout()


func _on_ok() -> void:
	var nm := Players.clean_name(_edit.text)
	if nm == "":
		_ask_label.text = "Please type a name."
		return
	if _ask_id == "":
		var id := Players.add(nm)
		if id != "":
			Game.inst.switch_player(id)
		return
	Players.rename(_ask_id, nm)
	_close_ask()
	refresh()
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	# (Sized here, not by anchors: it can open before its parent has a size.)
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	_shade.position = Vector2.ZERO
	_shade.size = vp
	var area := UiStyle.safe_rect(get_viewport(), Vector4(24, 16, 24, 16))
	var w := minf(area.size.x, 900.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	# (A wrapped line is measured at its width, never at zero: one word a line made the panel tall.)
	for l in [_note, _ask_label]:
		(l as Label).custom_minimum_size.x = w - 60.0
	_panel.size = Vector2(w, _panel.get_combined_minimum_size().y)
	_panel.position = Vector2(area.position.x + (area.size.x - w) * 0.5, area.position.y + maxf(0.0, (area.size.y - _panel.size.y) * 0.5))
	if visible and not _relaid:
		# (Wrapped lines settle a frame later.)
		_relaid = true
		_layout.call_deferred()
	else:
		_relaid = false


var _relaid := false
