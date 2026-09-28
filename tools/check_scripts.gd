extends SceneTree
## Loads every GDScript in the project so parse/compile errors are reported quickly.
## Usage: godot --headless --path . -s tools/check_scripts.gd

func _init() -> void:
	var bad := 0
	for path in _scripts("res://scripts"):
		var s: GDScript = load(path)
		if s == null or not s.can_instantiate() and not path.ends_with("levels.gd") and not path.ends_with("mesh_lib.gd") and not path.ends_with("ui_style.gd"):
			print("CHECK FAIL ", path)
			bad += 1
	print("CHECK DONE, failures: ", bad)
	quit(1 if bad > 0 else 0)


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
