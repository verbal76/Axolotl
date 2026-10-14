extends SceneTree
## Writes the game's licences and third-party notices (Credits.text(), from the running engine) to
## a text file shipped next to desktop builds: godot --headless --path . -s tools/write_notices.gd -- out=<file>

func _init() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	if out == "":
		push_error("usage: -- out=<file>")
		quit(2)
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % out)
		quit(1)
		return
	f.store_string(load("res://scripts/core/credits.gd").text() + "\n")
	f.close()
	print("NOTICES written: %s" % out)
	quit()
