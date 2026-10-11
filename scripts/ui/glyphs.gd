class_name Glyphs
extends RefCounted
## Controller button glyphs (owner, 2026-10-11: Steam Deck / Steam Machine requirements: "on-screen
## glyphs must match the inputs being used, whether it's Deck, Steam Controller, or Xbox glyphs").
## Drawn, not from a font, so every family renders the same everywhere:
## - "deck": Steam Deck and Steam Controller (Steam Input presents them as one virtual pad):
##   monochrome A/B/X/Y in the Xbox layout, the View and Menu buttons as their own icons;
## - "xbox": the same letters, each in its Xbox colour;
## - "ps": the PlayStation shapes (cross, circle, square, triangle) in the same positions.
## The button for an action is read from the InputMap, so a glyph can never name a different button
## than the one that works. (When Mote has a Steam App ID, Steam Input's own glyphs can replace these.)

const FAMILY_DECK := "deck"
const FAMILY_XBOX := "xbox"
const FAMILY_PS := "ps"

## Short labels for the game's actions, as the prompts show them.
const LABELS := {
	"jump": "Jump", "burst": "Burst", "swipe": "Tail swipe", "lunge": "Lunge", "special": "Skill",
	"pause": "Menu", "view_ball": "Whole ball", "move": "Move", "camera": "Look",
	"ui_accept": "Select", "ui_cancel": "Back",
}


## Which family to draw for the pad in use. On a Steam Deck (SteamOS sets SteamDeck=1) and for Steam's
## virtual pad, the Deck family; for a Sony pad, PlayStation shapes; otherwise Xbox letters.
static func family() -> String:
	if OS.get_environment("SteamDeck") == "1":
		return FAMILY_DECK
	var pads := Input.get_connected_joypads()
	var n := (Input.get_joy_name(pads[0]) if not pads.is_empty() else "").to_lower()
	return family_for_name(n)


static func family_for_name(n: String) -> String:
	n = n.to_lower()
	if n.contains("steam") or n.contains("valve") or n.contains("deck"):
		return FAMILY_DECK
	if n.contains("ps3") or n.contains("ps4") or n.contains("ps5") or n.contains("dualshock") or n.contains("dualsense") \
			or n.contains("sony") or n.contains("playstation"):
		return FAMILY_PS
	return FAMILY_XBOX


## The pad button bound to `action` in the InputMap (-1 if it has none; a stick action reports the
## stick: -2 left, -3 right).
static func button_for(action: String) -> int:
	match action:
		"move":
			return -2
		"camera":
			return -3
		"burst":
			action = "jump"
	if not InputMap.has_action(action):
		return -1
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return (ev as InputEventJoypadButton).button_index
	return -1


## The button's name for running text, in the family in use ("A" on Deck and Xbox, "Cross" on PlayStation).
static func button_name(b: int, fam := "") -> String:
	if fam == "":
		fam = family()
	if fam == FAMILY_PS:
		return {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
				JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Create"}.get(b, "?")
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View"}.get(b, "?")


## Draws the glyph for pad button `b` centred on `c`, `r` its radius, in `fam`, at opacity `a`.
static func draw(ci: CanvasItem, c: Vector2, r: float, b: int, fam: String, a: float, font: Font = null) -> void:
	var ink := Color(1, 1, 1, 0.95 * a)
	var disc := Color(0.02, 0.06, 0.06, 0.62 * a)
	var w := maxf(1.5, r * 0.16)
	match b:
		-2, -3:
			# A stick: a disc with a smaller cap and its letter.
			ci.draw_circle(c, r, disc)
			ci.draw_arc(c, r * 0.98, 0, TAU, 40, Color(1, 1, 1, 0.5 * a), w * 0.6, true)
			ci.draw_circle(c, r * 0.55, Color(1, 1, 1, 0.16 * a))
			_letter(ci, c, r, "L" if b == -2 else "R", ink, font)
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			var col := ink
			if fam == FAMILY_XBOX:
				col = {JOY_BUTTON_A: Color(0.45, 0.85, 0.3), JOY_BUTTON_B: Color(0.95, 0.35, 0.3),
						JOY_BUTTON_X: Color(0.3, 0.55, 1.0), JOY_BUTTON_Y: Color(1.0, 0.82, 0.25)}[b]
				col.a = 0.95 * a
			ci.draw_circle(c, r, disc)
			ci.draw_arc(c, r * 0.98, 0, TAU, 40, Color(col.r, col.g, col.b, 0.85 * a), w * 0.6, true)
			if fam == FAMILY_PS:
				_ps_shape(ci, c, r * 0.5, b, a, w)
			else:
				_letter(ci, c, r, {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"}[b], col, font)
		JOY_BUTTON_START:
			# Menu (Deck, Xbox) / Options (PlayStation): three lines.
			ci.draw_circle(c, r, disc)
			for k in 3:
				var y := c.y + (k - 1) * r * 0.32
				ci.draw_line(Vector2(c.x - r * 0.42, y), Vector2(c.x + r * 0.42, y), ink, w, true)
		JOY_BUTTON_BACK:
			# View (Deck, Xbox) / Share: two overlapping frames.
			ci.draw_circle(c, r, disc)
			var s := Vector2(r * 0.62, r * 0.46)
			ci.draw_rect(Rect2(c - s * 0.5 + Vector2(-r * 0.14, -r * 0.12), s), ink, false, w)
			ci.draw_rect(Rect2(c - s * 0.5 + Vector2(r * 0.14, r * 0.12), s), ink, false, w)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var rect := Rect2(c - Vector2(r * 1.25, r * 0.7), Vector2(r * 2.5, r * 1.4))
			ci.draw_rect(rect, disc, true)
			ci.draw_rect(rect, Color(1, 1, 1, 0.6 * a), false, w * 0.6)
			var t := ("L1" if b == JOY_BUTTON_LEFT_SHOULDER else "R1") if fam == FAMILY_PS else ("LB" if b == JOY_BUTTON_LEFT_SHOULDER else "RB")
			if fam == FAMILY_DECK:
				t = "L1" if b == JOY_BUTTON_LEFT_SHOULDER else "R1"
			_letter(ci, c, r * 0.8, t, ink, font)
		_:
			ci.draw_circle(c, r, disc)
			_letter(ci, c, r, "?", ink, font)


static func _letter(ci: CanvasItem, c: Vector2, r: float, t: String, col: Color, font: Font) -> void:
	var f := font if font != null else ThemeDB.fallback_font
	var fs := int(r * (1.15 if t.length() == 1 else 0.85))
	var sz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ci.draw_string(f, c + Vector2(-sz.x * 0.5, f.get_ascent(fs) * 0.5 - f.get_descent(fs) * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _ps_shape(ci: CanvasItem, c: Vector2, s: float, b: int, a: float, w: float) -> void:
	match b:
		JOY_BUTTON_A:   # cross
			var col := Color(0.55, 0.7, 1.0, a)
			ci.draw_line(c + Vector2(-s, -s) * 0.75, c + Vector2(s, s) * 0.75, col, w * 1.3, true)
			ci.draw_line(c + Vector2(-s, s) * 0.75, c + Vector2(s, -s) * 0.75, col, w * 1.3, true)
		JOY_BUTTON_B:   # circle
			ci.draw_arc(c, s * 0.8, 0, TAU, 32, Color(1.0, 0.45, 0.45, a), w * 1.2, true)
		JOY_BUTTON_X:   # square
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), Color(1.0, 0.55, 0.85, a), false, w * 1.2)
		JOY_BUTTON_Y:   # triangle
			var pts := PackedVector2Array([c + Vector2(0, -s * 0.85), c + Vector2(s * 0.85, s * 0.6), c + Vector2(-s * 0.85, s * 0.6), c + Vector2(0, -s * 0.85)])
			ci.draw_polyline(pts, Color(0.45, 0.95, 0.75, a), w * 1.2, true)


## A row of prompt chips (glyph + label) centred at `bottom_center`, for the actions in `actions`.
## Returns the drawn rect (for layout tests).
static func draw_row(ci: CanvasItem, bottom_center: Vector2, actions: Array, k: float, a: float, font: Font) -> Rect2:
	var fam := family()
	var fs := int(22 * k)
	var r := 17.0 * k
	var gap := 22.0 * k
	var widths: Array[float] = []
	var total := 0.0
	for act in actions:
		var label: String = LABELS.get(act, act)
		var w := r * 2.0 + 8.0 * k + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0 * k
		widths.append(w)
		total += w
	total += gap * maxf(0, actions.size() - 1)
	var x := bottom_center.x - total * 0.5
	var y := bottom_center.y - r - 6.0 * k
	var rect := Rect2(Vector2(x - 8 * k, y - r - 6 * k), Vector2(total + 16 * k, r * 2.0 + 12 * k))
	ci.draw_rect(rect, Color(0.0, 0.04, 0.04, 0.45 * a), true)
	for i in actions.size():
		var act: String = actions[i]
		var c := Vector2(x + r, y)
		draw(ci, c, r, button_for(act), fam, a, font)
		ci.draw_string(font, Vector2(x + r * 2.0 + 8.0 * k, y + fs * 0.36), LABELS.get(act, act), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92 * a))
		x += widths[i] + gap
	return rect
