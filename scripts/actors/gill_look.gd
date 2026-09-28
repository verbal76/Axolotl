class_name GillLook
extends RefCounted
## Gill's colours (owner request after the dev-000024 playtest): a real axolotl morph as a base,
## fine-tuned by a hue shift and brightness for his body and for his freckles. Chosen in the pause
## menu (scripts/ui/gill_page.gd), kept per device in user://settings.cfg (Settings), and applied
## to every AxolotlModel. Cosmetic only; the gill fronds keep their health colours.

## Each morph: body tones (base, back, belly), freckles, cheeks. "pink" is Gill's original look
## (the skin shader's own defaults), so an untouched setting changes nothing.
const MORPHS := [
	{"id": "pink", "name": "Pink", "base": Color(0.98, 0.58, 0.66), "back": Color(0.9, 0.48, 0.57), "belly": Color(1.0, 0.8, 0.77),
			"freckle": Color(0.72, 0.34, 0.44), "cheek": Color(1.0, 0.64, 0.68)},
	{"id": "golden", "name": "Golden", "base": Color(1.0, 0.8, 0.42), "back": Color(0.95, 0.68, 0.3), "belly": Color(1.0, 0.93, 0.74),
			"freckle": Color(1.0, 0.95, 0.78), "cheek": Color(1.0, 0.74, 0.5)},
	{"id": "wild", "name": "Wild", "base": Color(0.42, 0.4, 0.28), "back": Color(0.32, 0.31, 0.21), "belly": Color(0.66, 0.62, 0.48),
			"freckle": Color(0.2, 0.2, 0.13), "cheek": Color(0.5, 0.44, 0.32)},
	{"id": "melanoid", "name": "Melanoid", "base": Color(0.22, 0.2, 0.24), "back": Color(0.16, 0.14, 0.18), "belly": Color(0.36, 0.33, 0.38),
			"freckle": Color(0.1, 0.09, 0.12), "cheek": Color(0.3, 0.26, 0.3)},
	{"id": "copper", "name": "Copper", "base": Color(0.86, 0.55, 0.36), "back": Color(0.76, 0.44, 0.27), "belly": Color(0.98, 0.78, 0.62),
			"freckle": Color(0.55, 0.28, 0.16), "cheek": Color(0.95, 0.6, 0.45)},
	{"id": "lavender", "name": "Lavender", "base": Color(0.8, 0.74, 0.88), "back": Color(0.7, 0.63, 0.8), "belly": Color(0.93, 0.9, 0.96),
			"freckle": Color(0.36, 0.3, 0.46), "cheek": Color(0.9, 0.72, 0.84)},
	{"id": "gfp", "name": "Glow", "base": Color(0.74, 0.97, 0.62), "back": Color(0.6, 0.88, 0.48), "belly": Color(0.9, 1.0, 0.82),
			"freckle": Color(0.3, 0.68, 0.34), "cheek": Color(0.82, 0.98, 0.7)},
]


static func morph(id: String) -> Dictionary:
	for m in MORPHS:
		if m["id"] == id:
			return m
	return MORPHS[0]


## The colours for a morph after the fine-tuning: `*_hue` shifts the hue (-0.5..0.5 of a turn),
## `*_bright` scales the brightness (0.5..1.5; 1 = as the morph).
static func tones(morph_id: String, body_hue := 0.0, body_bright := 1.0, dots_hue := 0.0, dots_bright := 1.0) -> Dictionary:
	var m := morph(morph_id)
	var out := {}
	for k in ["base", "back", "belly", "cheek"]:
		out[k] = _tune(m[k], body_hue, body_bright)
	out["freckle"] = _tune(m["freckle"], dots_hue, dots_bright)
	return out


static func _tune(c: Color, hue: float, bright: float) -> Color:
	if is_zero_approx(hue) and is_equal_approx(bright, 1.0):
		return c
	var h := fposmod(c.h + hue, 1.0)
	# (A grey-ish morph still shows a hue when shifted: a little saturation comes with it.)
	var s := c.s if is_zero_approx(hue) else maxf(c.s, 0.3)
	return Color.from_hsv(h, s, clampf(c.v * bright, 0.04, 1.0))


## The current choice (Settings).
static func current() -> Dictionary:
	return tones(Settings.gill_morph, Settings.gill_body_hue, Settings.gill_body_bright, Settings.gill_dots_hue, Settings.gill_dots_bright)
