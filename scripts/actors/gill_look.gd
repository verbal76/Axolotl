class_name GillLook
extends RefCounted
## The character's colours (owner request after the dev-000024 playtest): a real axolotl morph as a base,
## fine-tuned by a hue shift and brightness for his body and for his freckles. Chosen in the pause
## menu (scripts/ui/gill_page.gd), kept per device in user://settings.cfg (Settings), and applied
## to every AxolotlModel. Cosmetic only; the gill fronds keep their health colours.

## Each morph: body tones (base, back, belly), freckles, cheeks. "pink" is his original look
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


## The current choice (Settings): colours plus the pattern.
static func current() -> Dictionary:
	var t := tones(Settings.gill_morph, Settings.gill_body_hue, Settings.gill_body_bright, Settings.gill_dots_hue, Settings.gill_dots_bright)
	t["pattern"] = pattern_texture(Settings.gill_pattern)
	t["pattern_mode"] = Settings.gill_pattern_mode
	t["pattern_size"] = Settings.gill_pattern_size
	t["pattern_alpha"] = 1.0 if Settings.gill_pattern != UPLOAD else (1.0 if Settings.gill_pattern_alpha else 0.0)
	return t


# --- Patterns ---------------------------------------------------------------------------------

## Built-in patterns (drawn here, tileable), then the player's own upload.
const PATTERNS := [["none", "Freckles"], ["spots", "Spots"], ["stripes", "Stripes"], ["hearts", "Hearts"], ["stars", "Stars"], ["leopard", "Leopard"]]
const UPLOAD := "upload"
const UPLOAD_PATH := "user://gill_pattern.png"
const PATTERN_PX := 256
static var _cache := {}
## Built-in patterns drawn ahead on a worker thread (warm_patterns), waiting to become textures.
static var _drawn := {}
static var _drawn_lock := Mutex.new()


## Draws the built-in patterns on a worker thread once the game is up (drawing them pixel by pixel
## took about 2 s of every startup when the colours page was built); pattern_texture then only
## wraps the finished image. Safe to call more than once.
static func warm_patterns() -> void:
	WorkerThreadPool.add_task(_draw_all, false, "draw the pattern swatches")


static func _draw_all() -> void:
	for pat in PATTERNS:
		var id: String = pat[0]
		if id == "none":
			continue
		_drawn_lock.lock()
		var have := _drawn.has(id)
		_drawn_lock.unlock()
		if have:
			continue
		var img := draw_pattern(id)
		img.generate_mipmaps()
		_drawn_lock.lock()
		_drawn[id] = img
		_drawn_lock.unlock()


static func pattern_texture(id: String) -> Texture2D:
	if id == "none" or id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var img: Image = null
	if id == UPLOAD:
		if FileAccess.file_exists(UPLOAD_PATH):
			img = Image.load_from_file(UPLOAD_PATH)
	else:
		_drawn_lock.lock()
		img = _drawn.get(id, null)
		_drawn_lock.unlock()
		if img == null:
			img = draw_pattern(id)
	if img == null or img.is_empty():
		return null
	if not img.has_mipmaps():
		img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


## Takes a picture the player picked (any size or shape), keeps its centre square, shrinks it to
## PATTERN_PX and stores it in user:// as their pattern. Returns "" or what went wrong.
static func import_pattern(path: String) -> String:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return "That file could not be read as a picture."
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(PATTERN_PX, PATTERN_PX, Image.INTERPOLATE_LANCZOS)
	# Pictures with see-through parts use those as the markings; others use their dark parts.
	var see_through := false
	for y in range(0, PATTERN_PX, 4):
		for x in range(0, PATTERN_PX, 4):
			if img.get_pixel(x, y).a < 0.9:
				see_through = true
				break
		if see_through:
			break
	if img.save_png(UPLOAD_PATH) != OK:
		return "The picture could not be saved."
	_cache.erase(UPLOAD)
	Settings.gill_pattern_alpha = see_through
	return ""


static func has_upload() -> bool:
	return FileAccess.file_exists(UPLOAD_PATH)


## Draws a built-in pattern: tileable, coloured shapes on a clear background.
static func draw_pattern(id: String) -> Image:
	var n := PATTERN_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var shapes := []          # [centre, size, colour, angle]
	match id:
		"spots":
			for k in 16:
				shapes.append([Vector2(rng.randf() * n, rng.randf() * n), rng.randf_range(9.0, 22.0), Color(0.38, 0.14, 0.18), 0.0])
		"hearts":
			for k in 4:
				shapes.append([Vector2((k % 2) * n * 0.5 + (k / 2) * n * 0.25 + n * 0.25, (k / 2) * n * 0.5 + n * 0.25), 34.0, Color(0.95, 0.28, 0.45), 0.0])
		"stars":
			for k in 5:
				shapes.append([Vector2(rng.randf() * n, (k + rng.randf() * 0.6) * n / 5.0), rng.randf_range(22.0, 32.0), Color(1.0, 0.82, 0.28), rng.randf() * TAU])
		"leopard":
			for k in 12:
				shapes.append([Vector2(rng.randf() * n, rng.randf() * n), rng.randf_range(16.0, 26.0), Color(0.2, 0.11, 0.06), rng.randf() * TAU])
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			if id == "stripes":
				var f := sin((p.y / n) * TAU * 3.0 + sin(p.x / n * TAU) * 0.9)
				var a := smoothstep(0.25, 0.45, f)
				col = Color(0.3, 0.12, 0.16, a)
			for sh in shapes:
				var d: Vector2 = p - sh[0]
				d.x -= roundf(d.x / n) * n
				d.y -= roundf(d.y / n) * n
				var cov := _shape(id, d, sh[1], sh[3])
				if cov > 0.0:
					var sc: Color = sh[2]
					if id == "leopard":
						# A rosette: a broken dark ring round a tawny middle.
						var r := d.length() / float(sh[1])
						var ring := smoothstep(0.55, 0.7, r) * (1.0 - smoothstep(0.95, 1.05, r))
						ring *= 0.35 + 0.65 * smoothstep(-0.2, 0.3, sin(atan2(d.y, d.x) * 3.0 + float(sh[3])))
						var mid := (1.0 - smoothstep(0.5, 0.62, r)) * 0.55
						col = Color(0.62, 0.42, 0.2, maxf(col.a, mid)).lerp(Color(sc.r, sc.g, sc.b, 1.0), ring)
						col.a = maxf(mid, ring)
					else:
						col = Color(sc.r, sc.g, sc.b, maxf(col.a, cov))
			img.set_pixel(x, y, col)
	return img


## How much of shape `id` (size `s`, turned by `ang`) covers offset `d` from its centre (0..1).
static func _shape(id: String, d: Vector2, s: float, ang: float) -> float:
	match id:
		"spots":
			return 1.0 - smoothstep(s - 1.5, s + 0.5, d.length())
		"hearts":
			var q := Vector2(d.x, -d.y + s * 0.25) / s * 1.25
			var f := pow(q.x * q.x + q.y * q.y - 1.0, 3.0) - q.x * q.x * q.y * q.y * q.y
			return 1.0 - smoothstep(-0.02, 0.02, f)
		"stars":
			var r := d.length()
			var a := fposmod(atan2(d.y, d.x) + ang, TAU / 5.0) - TAU / 10.0
			var edge := s * 0.42 + (s - s * 0.42) * pow(1.0 - absf(a) / (TAU / 10.0), 1.6)
			return 1.0 - smoothstep(edge - 1.2, edge + 0.8, r)
		"leopard":
			return 1.0 if d.length() < s * 1.1 else 0.0
	return 0.0
