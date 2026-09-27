class_name UiStyle
## Small shared look for menus: soft translucent panels, rounded buttons, large touch targets.


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var normal := _box(Color(0.08, 0.22, 0.2, 0.72), Color(0.6, 1.0, 0.9, 0.35))
	var hover := _box(Color(0.12, 0.32, 0.28, 0.85), Color(0.7, 1.0, 0.92, 0.7))
	var pressed := _box(Color(0.2, 0.45, 0.38, 0.9), Color(0.8, 1.0, 0.95, 0.9))
	for cls in ["Button", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), Color(0.9, 1.0, 0.95, 0.9)))
		t.set_color("font_color", cls, Color(0.92, 1.0, 0.97))
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
	t.set_color("font_color", "Label", Color(0.9, 1.0, 0.96))
	var panel := _box(Color(0.03, 0.12, 0.12, 0.82), Color(0.5, 0.95, 0.85, 0.25))
	panel.content_margin_left = 34
	panel.content_margin_right = 34
	panel.content_margin_top = 26
	panel.content_margin_bottom = 26
	t.set_stylebox("panel", "PanelContainer", panel)
	var slider_bg := _box(Color(0.1, 0.25, 0.22, 0.9), Color(0, 0, 0, 0))
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := _box(Color(0.45, 0.95, 0.8, 0.9), Color(0, 0, 0, 0))
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 68)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b
