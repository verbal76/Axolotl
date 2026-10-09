class_name VitalityBar
extends Control
## Hard Mode's HUD (ledger row 12; §E and owner ruling D): top centre, 360 x 20 (scaled), DEAD with a
## grey tuft on the left, LIVING with a green sprout on the right, a track between them. The gold
## marker is the CURRENT sphere's area-weighted mean vitality; a small mint tick is his own zone, which
## glows and drifts while that zone is under pressure. Reduced HUD: a 3 px line with the marker only.
## There is no whole-aquarium bar (remote trouble is shown by the vortex network). Never shown in Normal.
## Updated four times a second by Game; drawing is a few rectangles and lines (well under 0.1 ms).

const W := 360.0
const H := 20.0
const DEAD_COL := Color(0.62, 0.62, 0.58)
const LIVING_COL := Color(0.42, 0.86, 0.38)

var k := 1.0
## The current sphere's mean V, his zone's V (< 0: outside every zone) and whether it is losing now.
var mean_v := 1.0
var zone_v := -1.0
var pressured := false
var _shown := 1.0
var _t := 0.0
var _a := 0.0
var want := false


func set_values(p_mean: float, p_zone: float, p_pressured: bool) -> void:
	mean_v = clampf(p_mean, 0.0, 1.0)
	zone_v = p_zone
	pressured = p_pressured


func _process(dt: float) -> void:
	if not want and _a <= 0.0:
		return
	_t += dt
	_shown = move_toward(_shown, mean_v, dt * 0.25)
	_a = move_toward(_a, 1.0 if want else 0.0, dt * 3.0)
	queue_redraw()


## The track's span in local coordinates (x from, x to) and its vertical centre.
func _track() -> Array:
	var lw := 70.0 * k
	return [lw, W * k - lw, H * k * 0.5]


func _draw() -> void:
	if _a <= 0.0:
		return
	var tr := _track()
	var x0: float = tr[0]
	var x1: float = tr[1]
	var cy: float = tr[2]
	var mx := lerpf(x0, x1, _shown)
	if Settings.reduced_hud:
		draw_line(Vector2(x0, cy), Vector2(x1, cy), Color(0.8, 0.9, 0.85, 0.35 * _a), 3.0 * k)
		draw_line(Vector2(x0, cy), Vector2(mx, cy), Color(UiStyle.MINT, 0.7 * _a), 3.0 * k)
		return
	var font := ThemeDB.fallback_font
	var fs := int(13 * k)
	# DEAD (grey tuft) on the left, LIVING (green sprout) on the right.
	draw_string(font, Vector2(2 * k, cy + fs * 0.36), "DEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(DEAD_COL, 0.9 * _a))
	var tx := 50.0 * k
	for i in 3:
		var a := deg_to_rad(-25.0 + 25.0 * i)
		draw_line(Vector2(tx, cy + 7 * k), Vector2(tx, cy + 7 * k) + Vector2(sin(a), -cos(a)) * 10.0 * k, Color(DEAD_COL, 0.9 * _a), 1.6 * k)
	var lx := W * k - 2 * k
	var ls := font.get_string_size("LIVING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(lx - ls, cy + fs * 0.36), "LIVING", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(LIVING_COL, 0.95 * _a))
	var sx := W * k - 62.0 * k
	draw_line(Vector2(sx, cy + 7 * k), Vector2(sx, cy - 6 * k), Color(LIVING_COL, _a), 1.8 * k)
	draw_circle(Vector2(sx - 3.5 * k, cy - 4 * k), 3.2 * k, Color(LIVING_COL, _a))
	draw_circle(Vector2(sx + 3.5 * k, cy - 6 * k), 3.2 * k, Color(LIVING_COL, _a))
	# The track, with arrowheads at both ends (DEAD <-- | --> LIVING).
	var back := Color(0.02, 0.1, 0.09, 0.55 * _a)
	draw_rect(Rect2(x0, cy - 4 * k, x1 - x0, 8 * k), back)
	var steps := 12
	for i in steps:
		var f0 := float(i) / steps
		var c := DEAD_COL.lerp(LIVING_COL, f0)
		draw_rect(Rect2(lerpf(x0, x1, f0), cy - 2 * k, (x1 - x0) / steps + 0.5, 4 * k), Color(c, 0.55 * _a))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 - 6 * k, cy), Vector2(x0, cy - 5 * k), Vector2(x0, cy + 5 * k)]), Color(DEAD_COL, 0.8 * _a))
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 6 * k, cy), Vector2(x1, cy - 5 * k), Vector2(x1, cy + 5 * k)]), Color(LIVING_COL, 0.8 * _a))
	# His zone's tick: drifts and glows while the zone is losing.
	if zone_v >= 0.0:
		var zx := lerpf(x0, x1, clampf(zone_v, 0.0, 1.0)) + (sin(_t * 2.1) * 2.0 * k if pressured else 0.0)
		if pressured:
			draw_circle(Vector2(zx, cy), 6.0 * k * (0.8 + 0.2 * sin(_t * 3.0)), Color(UiStyle.MINT, 0.25 * _a))
		draw_line(Vector2(zx, cy - 6 * k), Vector2(zx, cy + 6 * k), Color(UiStyle.MINT, (0.95 if pressured else 0.6) * _a), 2.0 * k)
	# The sphere's marker.
	draw_rect(Rect2(mx - 2.5 * k, cy - 9 * k, 5 * k, 18 * k), Color(UiStyle.GOLD, _a))
	draw_rect(Rect2(mx - 2.5 * k, cy - 9 * k, 5 * k, 18 * k), Color(0.1, 0.08, 0.02, 0.6 * _a), false, 1.0)
