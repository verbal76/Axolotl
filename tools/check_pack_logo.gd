extends SceneTree
## Release gate (owner standing requirement, CLAUDE.md): the canonical Hot Attic Games logo is inside
## an OTA pack, unchanged. Checks the source file's SHA-256, then reads the logo's import and its
## compressed texture straight out of the pack (never the project's own copies), decodes it and
## compares what is displayed: alpha everywhere and colour wherever a pixel is visible. (The import's
## fix_alpha_border recolours only fully transparent pixels, to avoid dark fringes when filtered;
## those colours are never seen.)
##   godot --headless --path . -s tools/check_pack_logo.gd -- pck=<pack.pck>
## Prints "LOGO OK" or "LOGO FAIL: …" (exit code 1).

const LOGO := "res://Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png"
const LOGO_SHA256 := "e3d9bb5653eafb783eede827606e7ac73a4e45564a1c25b1ed13ad1429f48c4e"
const SIZE := Vector2i(1536, 1024)


func _init() -> void:
	var pck := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pck="):
			pck = a.substr(4)
	var why := _check(pck)
	print("LOGO OK" if why == "" else "LOGO FAIL: " + why)
	quit(0 if why == "" else 1)


## path -> bytes for every file in a Godot 4 pack (formats 2-3, unencrypted), as tools/pck_files.py.
static func pack_files(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 40 or b.slice(0, 4).get_string_from_ascii() != "GDPC":
		return {}
	var fmt := b.decode_u32(4)
	var base := b.decode_u64(24)
	var o: int = b.decode_u64(32) if fmt >= 3 else 32 + 16 * 4
	var n := b.decode_u32(o)
	o += 4
	var files := {}
	for _i in n:
		var ln := b.decode_u32(o)
		o += 4
		var p := b.slice(o, o + ln).get_string_from_utf8()
		o += ln
		var off := b.decode_u64(o)
		var size := b.decode_u64(o + 8)
		o += 16 + 16 + 4  # offset/size, md5, flags
		files[p] = b.slice(base + off, base + off + size)
	return files


## SHA-256 of the displayed pixels: RGBA8, with the (invisible) colour of fully transparent pixels zeroed.
static func _pixels_sha(img: Image) -> String:
	img.convert(Image.FORMAT_RGBA8)
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			d[i] = 0
			d[i + 1] = 0
			d[i + 2] = 0
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(d)
	return h.finish().hex_encode()


func _check(pck: String) -> String:
	if pck == "" or not FileAccess.file_exists(pck):
		return "no pack given (pck=%s)" % pck
	var file_sha := FileAccess.get_sha256(ProjectSettings.globalize_path(LOGO))
	if file_sha != LOGO_SHA256:
		return "source logo SHA-256 %s, expected %s (the canonical asset was changed)" % [file_sha, LOGO_SHA256]
	var src := Image.load_from_file(ProjectSettings.globalize_path(LOGO))
	if src == null or src.get_size() != SIZE or not src.detect_alpha():
		return "source logo is not %s RGBA with transparency" % SIZE
	var want := _pixels_sha(src)
	var files := pack_files(pck)
	if files.is_empty():
		return "%s is not a readable Godot pack" % pck
	var imp_name := LOGO.trim_prefix("res://") + ".import"
	if not files.has(imp_name):
		return "the pack has no %s" % imp_name
	var cfg := ConfigFile.new()
	if cfg.parse((files[imp_name] as PackedByteArray).get_string_from_utf8()) != OK:
		return "the pack's %s does not parse" % imp_name
	var ctex := str(cfg.get_value("remap", "path", "")).trim_prefix("res://")
	if not files.has(ctex):
		return "the pack has no %s (the imported logo)" % ctex
	# Decode the pack's own bytes from a scratch file, so no project copy can stand in.
	var tmp := "user://check_pack_logo.ctex"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_buffer(files[ctex])
	f.close()
	var tex := ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	if tex == null:
		return "the logo in the pack does not decode"
	var got_img := tex.get_image()
	if got_img == null or got_img.get_size() != SIZE:
		return "packed logo size %s, expected %s" % [got_img.get_size() if got_img else "none", SIZE]
	var got := _pixels_sha(got_img)
	print("LOGO source sha256 %s, %dx%d, displayed pixels %s; pack %s (%d bytes) displayed pixels %s" % [
			file_sha, SIZE.x, SIZE.y, want, ctex, (files[ctex] as PackedByteArray).size(), got])
	if got != want:
		return "the packed logo's displayed pixels differ from the canonical file"
	return ""
