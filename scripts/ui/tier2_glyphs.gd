class_name Tier2Glyphs
extends RefCounted
## The three Tier-2 glyphs (docs/TIER2.md), drawn with thick strokes so each reads by its silhouette
## at phone button size (never by colour):
## - Water Cannon: a nozzle ring firing a heavy beam that ends in an arrowhead and a droplet.
## - Bubble Blast: a solid core inside two expanding rings, the outer one broken into four arcs.
## - Gill Rush: a pointed head (a nose-first wedge) driving up-right, with three impact dots behind it.
## `s` is the half-size of the glyph box, `k` the HUD scale (line widths).

static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, k := 1.0) -> void:
	var w := maxf(2.0, s * 0.16)
	match id:
		Tier2.CANNON:
			# Nozzle ring on the left, beam to the right, arrowhead, a droplet ahead.
			ci.draw_arc(c + Vector2(-s * 0.72, 0), s * 0.24, 0, TAU, 20, col, w * 0.8, true)
			ci.draw_line(c + Vector2(-s * 0.46, 0), c + Vector2(s * 0.52, 0), col, w * 1.35, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.22, -s * 0.36), c + Vector2(s * 0.62, 0), c + Vector2(s * 0.22, s * 0.36)]), col, w, true)
			ci.draw_circle(c + Vector2(s * 0.92, 0), s * 0.13, col)
		Tier2.BUBBLE:
			ci.draw_circle(c, s * 0.26, col)
			ci.draw_arc(c, s * 0.56, 0, TAU, 32, col, w * 0.8, true)
			for q in 4:
				var a0 := TAU * q / 4.0 + 0.25
				ci.draw_arc(c, s * 0.94, a0, a0 + TAU / 4.0 - 0.5, 12, col, w, true)
		Tier2.RUSH:
			# A nose-first wedge pointing up-right (the head), with three impact dots trailing.
			var d := Vector2(1, -1).normalized()
			var n := Vector2(-d.y, d.x)
			var tip := c + d * s * 0.78
			var back := c + d * s * 0.02
			ci.draw_colored_polygon(PackedVector2Array([tip, back + n * s * 0.36, back + d * s * 0.2, back - n * s * 0.36]), col)
			for i in 3:
				ci.draw_circle(c - d * s * (0.3 + i * 0.3) + n * s * (0.1 if i == 1 else -0.08), s * (0.12 - i * 0.02), col)
		_:
			ci.draw_arc(c, s * 0.5, 0, TAU, 20, col, w, true)
