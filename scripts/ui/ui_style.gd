class_name UiStyle
## Small shared look for menus: soft translucent panels, rounded buttons, large touch targets.


## Mote's visual language (owner, 2026-09-30; the Treasure Hunt panel is the reference): deep
## aquarium-teal rounded panels with a soft shadow, mint edges, warm gold for focus and press, the axolotl's
## pink for the one main action on a screen, and a heavier, friendlier weight of the type.
const INK := Color(0.95, 1.0, 0.97)
const MINT := Color(0.5, 0.97, 0.84)
const GOLD := Color(1.0, 0.84, 0.45)
const PINK := Color(0.95, 0.56, 0.64)
const PANEL := Color(0.03, 0.13, 0.13, 0.9)
const GEAR := preload("res://assets/ui/settings_gear.png")

static var _theme: Theme


static func font() -> Font:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.55
	f.spacing_glyph = 1
	return f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30
	var normal := _box(Color(0.05, 0.19, 0.18, 0.9), Color(MINT, 0.42))
	var hover := _box(Color(0.08, 0.27, 0.25, 0.94), Color(GOLD, 0.75))
	var pressed := _box(Color(0.12, 0.36, 0.32, 0.97), GOLD, 2)
	var disabled := _box(Color(0.05, 0.14, 0.14, 0.6), Color(MINT, 0.15))
	for cls in ["Button", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, _ring(GOLD))
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, Color(1, 0.96, 0.85))
		t.set_color("font_focus_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(INK, 0.4))
		t.set_color("font_outline_color", cls, Color(0.0, 0.08, 0.07, 0.6))
		t.set_constant("outline_size", cls, 4)
	# The one main action on a screen (Play / Continue): axolotl pink.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(PINK, Color(1.0, 0.86, 0.9, 0.9), 2, Color(0.35, 0.05, 0.12, 0.45)))
	t.set_stylebox("hover", "PrimaryButton", _box(PINK.lightened(0.1), GOLD, 3, Color(0.35, 0.05, 0.12, 0.45)))
	t.set_stylebox("pressed", "PrimaryButton", _box(PINK.darkened(0.12), GOLD, 3, Color(0.35, 0.05, 0.12, 0.3)))
	t.set_stylebox("hover_pressed", "PrimaryButton", t.get_stylebox("pressed", "PrimaryButton"))
	t.set_color("font_color", "PrimaryButton", Color(0.25, 0.04, 0.1))
	t.set_color("font_hover_color", "PrimaryButton", Color(0.2, 0.02, 0.08))
	t.set_color("font_pressed_color", "PrimaryButton", Color(0.2, 0.02, 0.08))
	t.set_color("font_focus_color", "PrimaryButton", Color(0.2, 0.02, 0.08))
	t.set_constant("outline_size", "PrimaryButton", 0)
	# A glyph on its own (the Settings gear): no box, just the picture, dimmed when pressed.
	t.set_type_variation("GlyphButton", "Button")
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "GlyphButton", none)
	t.set_stylebox("focus", "GlyphButton", _ring(GOLD, 999))
	t.set_color("icon_normal_color", "GlyphButton", Color(1, 1, 1, 0.95))
	t.set_color("icon_hover_color", "GlyphButton", Color(1.0, 0.97, 0.88))
	t.set_color("icon_pressed_color", "GlyphButton", Color(0.72, 0.8, 0.82))
	t.set_color("icon_focus_color", "GlyphButton", Color(1, 1, 1))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0.0, 0.08, 0.07, 0.55))
	t.set_constant("outline_size", "Label", 3)
	var panel := _box(PANEL, Color(MINT, 0.28), 2, Color(0, 0, 0, 0.4))
	panel.set_corner_radius_all(26)
	panel.content_margin_left = 34
	panel.content_margin_right = 34
	panel.content_margin_top = 26
	panel.content_margin_bottom = 26
	t.set_stylebox("panel", "PanelContainer", panel)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.1, 0.25, 0.23, 0.95)
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(MINT, 0.95)
	fill.set_corner_radius_all(6)
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = GOLD
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", _dot(22, Color(1, 1, 1)))
	t.set_icon("grabber_highlight", "HSlider", _dot(26, GOLD))
	# The menus' vertical scrollbar (dev-000025 phone test: too hard to grab with a finger). Its
	# touch area is SCROLL_TOUCH_W wide, inside the panel's right edge, while only the right-most
	# SCROLL_DRAW_W is drawn: a slim bar with a thumb-sized grip. (The container keeps that width
	# for it, so it never covers a button, toggle or slider.)
	t.set_stylebox("scroll", "VScrollBar", _scroll_box(Color(0.5, 0.95, 0.85, 0.12)))
	t.set_stylebox("scroll_focus", "VScrollBar", _scroll_box(Color(0.5, 0.95, 0.85, 0.12)))
	t.set_stylebox("grabber", "VScrollBar", _scroll_box(Color(0.6, 1.0, 0.9, 0.55)))
	t.set_stylebox("grabber_highlight", "VScrollBar", _scroll_box(Color(0.7, 1.0, 0.92, 0.8)))
	t.set_stylebox("grabber_pressed", "VScrollBar", _scroll_box(Color(0.85, 1.0, 0.96, 0.95)))
	_theme = t
	return t


## A round slider grip.
static func _dot(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var q := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - q, 0.0, 1.0)
			var edge := clampf(r - 2.5 - q, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.lerp(Color(0.02, 0.1, 0.1), 1.0 - edge), a))
	return ImageTexture.create_from_image(img)


## A focus ring: no fill, a gold outline just outside the control.
static func _ring(c: Color, radius := 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = c
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	s.set_expand_margin_all(4)
	return s


## How wide a menu scrollbar is to a finger, and how much of it is drawn (design pixels).
const SCROLL_TOUCH_W := 28
const SCROLL_DRAW_W := 8


## A scrollbar piece: full touch width, drawn only as a rounded strip along its right side.
static func _scroll_box(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = Color(0, 0, 0, 0)
	s.border_width_left = SCROLL_TOUCH_W - SCROLL_DRAW_W
	s.set_corner_radius_all(SCROLL_DRAW_W / 2)
	s.content_margin_left = SCROLL_TOUCH_W - SCROLL_DRAW_W
	s.content_margin_right = SCROLL_DRAW_W
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func _box(bg: Color, border: Color, bw := 2, shadow := Color(0, 0, 0, 0.35)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(24)
	s.shadow_color = shadow
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## The Settings gear (the owner's standard glyph, used as supplied): a finger-sized target around
## a smaller picture, no box behind it; it dims while pressed and has a gold focus ring.
static func gear_button(cb: Callable, touch := 96.0, glyph := 64) -> Button:
	var b := Button.new()
	b.name = "SettingsGear"
	b.theme_type_variation = "GlyphButton"
	b.icon = GEAR
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", glyph)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(touch, touch)
	b.tooltip_text = "Settings"
	b.focus_mode = Control.FOCUS_ALL
	if cb.is_valid():
		b.pressed.connect(cb)
	# (A small press: it sinks a little while held.)
	b.pivot_offset = Vector2(touch, touch) * 0.5
	b.button_down.connect(func() -> void: b.scale = Vector2.ONE * 0.9)
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	return b


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 68)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b


## A button that asks before acting: the first tap shows `question` with Yes/Cancel under it.
## Returns the container; `yes_text` confirms and calls `cb`.
static func confirm_button(text: String, question: String, yes_text: String, cb: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var ask := VBoxContainer.new()
	ask.name = "Confirm"
	ask.visible = false
	var q := Label.new()
	q.text = question
	q.add_theme_font_size_override("font_size", 22)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(340, 0)
	ask.add_child(q)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var yes := button(yes_text, cb)
	yes.custom_minimum_size = Vector2(200, 64)
	yes.name = "Yes"
	row.add_child(yes)
	var first := button(text, Callable())
	var no := button("Cancel", func(): ask.visible = false; first.visible = true; first.grab_focus())
	no.name = "Cancel"
	no.custom_minimum_size = Vector2(140, 64)
	row.add_child(no)
	ask.add_child(row)
	first.pressed.connect(func(): first.visible = false; ask.visible = true; no.grab_focus())
	first.name = "Ask"
	box.add_child(first)
	box.add_child(ask)
	return box


## Small dim text for run/progress lines.
static func note(text := "", size := 22) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A cut-out to stand in for a phone's (left, top, right, bottom, in design px), used by tests and
## renders: the menus lay themselves out as if the display's safe area excluded it.
static var test_inset := Vector4.ZERO


## The display's safe area in design pixels (the camera cut-out on a landscape phone), with at least
## `min_m` (left, top, right, bottom) all round.
static func safe_rect(vp: Viewport, min_m := Vector4(16, 14, 16, 14)) -> Rect2:
	var size := vp.get_visible_rect().size
	var m := min_m
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x > 0 and win.y > 0 and safe.size.x > 0 and safe.size.y > 0:
		m.x = maxf(m.x, safe.position.x * size.x / win.x)
		m.y = maxf(m.y, safe.position.y * size.y / win.y)
		m.z = maxf(m.z, (win.x - safe.end.x) * size.x / win.x)
		m.w = maxf(m.w, (win.y - safe.end.y) * size.y / win.y)
	m = Vector4(maxf(m.x, test_inset.x), maxf(m.y, test_inset.y), maxf(m.z, test_inset.z), maxf(m.w, test_inset.w))
	return Rect2(m.x, m.y, size.x - m.x - m.z, size.y - m.y - m.w)


## How far a finger may move on a button and still count as a tap (design px).
const TAP_SLOP := 16.0


## Makes `b` ignore a swipe: once a press has moved more than TAP_SLOP, `swiped(b)` stays true until
## the next press, and the button's handler does nothing (a finger dragged across the colour swatches
## never recolours him). The signal comes before the button's own handling, so the flag is set
## before `pressed`/`toggled` fire on release.
static func swipe_guard(b: BaseButton) -> void:
	b.set_meta("swiped", false)
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := e as InputEventMouseButton
			if mb.pressed:
				b.set_meta("press_at", mb.position)
				b.set_meta("swiped", false)
			elif b.has_meta("press_at") and mb.position.distance_to(b.get_meta("press_at")) > TAP_SLOP:
				b.set_meta("swiped", true)
		elif e is InputEventMouseMotion and b.has_meta("press_at") and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			if (e as InputEventMouseMotion).position.distance_to(b.get_meta("press_at")) > TAP_SLOP:
				b.set_meta("swiped", true))


## Whether the press that just ended on `b` was a swipe, not a tap (see swipe_guard); asking clears
## it. Keyboard and controller presses never are.
static func swiped(b: BaseButton) -> bool:
	var s := bool(b.get_meta("swiped", false))
	b.set_meta("swiped", false)
	return s
