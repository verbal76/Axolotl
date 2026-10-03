class_name StarChip
extends Control
## The HUD's red starfish chip: a small rounded pill, a red star and "12/30" (and "3 to spend" when
## there is something to spend), shown for a few seconds after a pickup, then faded out. Drawn,
## not a panel, so it costs nothing while hidden.

const RED := Color(0.95, 0.2, 0.16)
const SHOW_S := 3.6

var k := 1.0
var text := ""
var sub := ""
var _t := -1.0
var _pop := 0.0


func _ready() -> void:
	modulate.a = 0.0
	size = Vector2(230, 64)


func show_count(n: int, total: int, balance: int) -> void:
	text = "%d/%d" % [n, total]
	sub = ("%d to spend" % balance) if balance > 0 else ""
	_t = 0.0
	_pop = 1.0
	queue_redraw()


func showing() -> bool:
	return _t >= 0.0


func _process(dt: float) -> void:
	if _t < 0.0:
		return
	_t += dt
	_pop = maxf(0.0, _pop - dt * 3.0)
	modulate.a = clampf(_t / 0.2, 0.0, 1.0) * clampf((SHOW_S - _t) / 0.6, 0.0, 1.0)
	if _t >= SHOW_S:
		_t = -1.0
		modulate.a = 0.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var font := get_theme_default_font()
	var fs := int(26 * k)
	var fs2 := int(17 * k)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x if sub != "" else 0.0
	var h := 46.0 * k
	var w := 58.0 * k + tw + (sw + 14.0 * k if sub != "" else 0.0) + 16.0 * k
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.1, 0.1, 0.6)
	box.border_color = Color(RED, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(h * 0.5))
	draw_style_box(box, Rect2(Vector2.ZERO, Vector2(w, h)))
	draw_star(self, Vector2(28 * k, h * 0.5), 15.0 * k * (1.0 + 0.3 * _pop), RED)
	draw_string(font, Vector2(52 * k, h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.94))
	if sub != "":
		draw_string(font, Vector2(52 * k + tw + 14 * k, h * 0.5 + fs2 * 0.36), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.84, 0.45, 0.95))


## A plump five-armed star (also the skill tree page's currency glyph).
static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot := -PI * 0.5) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := rot + TAU * i / 20.0
		var lobe := pow(absf(cos((a - rot) * 2.5)), 1.4)
		pts.append(c + Vector2(cos(a), sin(a)) * r * lerpf(0.42, 1.0, lobe))
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-0.15, -0.2) * r, r * 0.16, Color(1, 0.75, 0.7, 0.55))
