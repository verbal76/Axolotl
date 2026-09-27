extends SceneTree
## Crops the icon artwork (assets/icon/icon_source.png, a rounded-square render on black) into
## the launcher/app icons. Re-run after replacing the artwork:
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
	print("icons written from ", n, "px source, inset ", inset)
	quit()


func _save(src: Image, size: int, path: String) -> void:
	var im := src.duplicate() as Image
	im.resize(size, size, Image.INTERPOLATE_LANCZOS)
	im.save_png(ProjectSettings.globalize_path(path))
