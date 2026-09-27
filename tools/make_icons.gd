extends SceneTree
## Crops the icon artwork (assets/icon/icon_source.png, a rounded-square render on black) into
## the launcher/app icons, and traces the axolotl in it into the themed-icon (monochrome) layer.
## Re-run after replacing the artwork:
##   godot --headless --path . -s tools/make_icons.gd

const SRC := "res://assets/icon/icon_source.png"


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	var n := img.get_width()
	# Inset past the rounded corners so no black shows; the face stays centred.
	var inset := int(n * 0.105)
	var sq := img.get_region(Rect2i(inset, inset, n - inset * 2, n - inset * 2))
	_save(sq, 1024, "res://assets/icon/icon_1024.png")
	_save(sq, 192, "res://assets/icon/icon_192.png")
	# Adaptive icon: the artwork is the background layer; launchers mask it to their shape
	# (the central ~66% is always visible). Foreground stays transparent.
	_save(sq, 432, "res://assets/icon/icon_adaptive_background_432.png")
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	fg.save_png(ProjectSettings.globalize_path("res://assets/icon/icon_adaptive_foreground_432.png"))
	_monochrome(sq).save_png(ProjectSettings.globalize_path("res://assets/icon/icon_adaptive_monochrome_432.png"))
	print("icons written from ", n, "px source, inset ", inset)
	quit()


func _save(src: Image, size: int, path: String) -> void:
	var im := src.duplicate() as Image
	im.resize(size, size, Image.INTERPOLATE_LANCZOS)
	im.save_png(ProjectSettings.globalize_path(path))


# --- Themed icon (Android 13+ "Themed icons") -----------------------------------------------
# Launchers draw this layer in one colour of their own, so it can only be a silhouette: the
# axolotl from the artwork (its pink body and gills), with the eyes and smile left open.
# Without it Godot ships its own robot logo here.
const M := 256


func _monochrome(art: Image) -> Image:
	var img := art.duplicate() as Image
	img.resize(M, M, Image.INTERPOLATE_LANCZOS)
	var m := PackedByteArray()
	m.resize(M * M)
	for y in M:
		for x in M:
			var c := img.get_pixel(x, y)
			m[y * M + x] = 1 if (c.r > 0.5 and c.r - c.g > 0.05 and c.r - c.b > 0.0) else 0
	m = _largest(m)
	# Fill background pockets smaller than an eye (between frond spikes, specks).
	var inv := PackedByteArray()
	inv.resize(M * M)
	for i in M * M:
		inv[i] = 1 - m[i]
	for comp in _components(inv):
		if comp.size() < 90:
			for i in comp:
				m[i] = 1
	m = _smooth(m, 2)
	var rect := _bounds(m)
	var mask := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for y in rect.size.y:
		for x in rect.size.x:
			var on := m[(rect.position.y + y) * M + rect.position.x + x] == 1
			mask.set_pixel(x, y, Color(1, 1, 1, 1.0 if on else 0.0))
	# Fit inside the central ~60% of the 432 canvas, where launchers keep themed glyphs.
	var s := 260.0 / maxf(rect.size.x, rect.size.y)
	var size := Vector2i(roundi(rect.size.x * s), roundi(rect.size.y * s))
	mask.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	out.fill(Color(1, 1, 1, 0))
	out.blit_rect(mask, Rect2i(Vector2i.ZERO, size), (Vector2i(432, 432) - size) / 2)
	return out


func _components(m: PackedByteArray) -> Array:
	var seen := PackedByteArray()
	seen.resize(M * M)
	var out := []
	for start in M * M:
		if m[start] != 1 or seen[start]:
			continue
		var comp := PackedInt32Array()
		var stack := [start]
		seen[start] = 1
		while not stack.is_empty():
			var i: int = stack.pop_back()
			comp.append(i)
			var x := i % M
			var y := i / M
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= M or ny >= M:
					continue
				var j := ny * M + nx
				if m[j] == 1 and not seen[j]:
					seen[j] = 1
					stack.append(j)
		out.append(comp)
	return out


func _largest(m: PackedByteArray) -> PackedByteArray:
	var best := PackedInt32Array()
	for comp in _components(m):
		if comp.size() > best.size():
			best = comp
	var r := PackedByteArray()
	r.resize(M * M)
	for i in best:
		r[i] = 1
	return r


func _smooth(m: PackedByteArray, rad: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(M * M)
	for y in M:
		for x in M:
			var on := 0
			var count := 0
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= M or ny >= M:
						continue
					on += m[ny * M + nx]
					count += 1
			r[y * M + x] = 1 if on * 2 > count else 0
	return r


func _bounds(m: PackedByteArray) -> Rect2i:
	var lo := Vector2i(M, M)
	var hi := Vector2i(-1, -1)
	for y in M:
		for x in M:
			if m[y * M + x] == 1:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
