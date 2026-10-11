class_name OnScreenKeyboard
extends VBoxContainer
## A controller keyboard for typing a name (owner, 2026-10-11: Steam Deck / Steam Machine
## requirements: text entry must work "using only a controller"). Shown under a name box while the
## controller is in use; the d-pad or left stick moves between keys, A types the key in focus,
## X deletes a letter, Y types a space, and the Done key confirms (B is Cancel, as on the page).
## A physical keyboard still types into the box as before. (With a Steam App ID, Steam's own
## keyboard API can open instead: SteamUtils.ShowGamepadTextInput.)

signal done

const ROWS := ["1234567890", "QWERTYUIOP", "ASDFGHJKL'", "ZXCVBNM-.!"]

var target: LineEdit
var upper := true
var _keys: Array[Button] = []
var _shift: Button


func _init(edit: LineEdit) -> void:
	target = edit
	name = "OnScreenKeyboard"
	add_theme_constant_override("separation", 6)
	for row in ROWS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(h)
		for ch in row:
			var b := _key(ch, func() -> void: _type(b_char(ch)))
			h.add_child(b)
			_keys.append(b)
	var last := HBoxContainer.new()
	last.add_theme_constant_override("separation", 6)
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(last)
	_shift = _key("abc", _toggle_case, 110)
	_shift.name = "Shift"
	last.add_child(_shift)
	var sp := _key("Space", func() -> void: _type(" "), 220)
	sp.name = "Space"
	last.add_child(sp)
	var bs := _key("⌫", _backspace, 110)
	bs.name = "Delete"
	last.add_child(bs)
	var ok := _key("Done", func() -> void: done.emit(), 140)
	ok.name = "Done"
	ok.theme_type_variation = "AccentButton"
	last.add_child(ok)


func _key(t: String, cb: Callable, w := 58) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	return b


func b_char(ch: String) -> String:
	return ch if upper else ch.to_lower()


func _type(s: String) -> void:
	if target == null:
		return
	if target.max_length > 0 and target.text.length() >= target.max_length:
		return
	target.text += s
	target.caret_column = target.text.length()
	# (After the first letter, lower case, as a phone keyboard does.)
	if upper and s != " ":
		_set_case(false)


func _backspace() -> void:
	if target != null and target.text != "":
		target.text = target.text.left(target.text.length() - 1)
		target.caret_column = target.text.length()
		if target.text == "":
			_set_case(true)


func _toggle_case() -> void:
	_set_case(not upper)


func _set_case(u: bool) -> void:
	upper = u
	var i := 0
	for row in ROWS:
		for ch in row:
			_keys[i].text = ch if upper else ch.to_lower()
			i += 1
	_shift.text = "abc" if upper else "ABC"


## The key the focus starts on.
func first_key() -> Button:
	return _keys[10]   # "Q"


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventJoypadButton) or not event.pressed:
		return
	var jb := event as InputEventJoypadButton
	if jb.button_index == JOY_BUTTON_X:
		_backspace()
		get_viewport().set_input_as_handled()
	elif jb.button_index == JOY_BUTTON_Y:
		_type(" ")
		get_viewport().set_input_as_handled()
