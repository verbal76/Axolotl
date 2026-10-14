class_name Credits
extends RefCounted
## Licences and credits (studio audit 2026-10-12: Godot's MIT licence and its third-party notices must
## ship with the game). Built from the running engine itself (Engine.get_license_text,
## get_copyright_info, get_license_info), so the notices always match the engine in the build, on every
## platform; shown under About > Licences and written next to the desktop builds
## (tools/write_notices.gd -> THIRD_PARTY_NOTICES.txt).

## Assets in the game that are not the studio's own or the engine's.
const ASSETS := [
	["Controller button prompts: \"Input Prompts\" by Julio Cacko (JulioCacko)",
			"CC0 1.0 Universal (public domain dedication), per the pack's itch.io listing; no attribution required."],
]


static func text() -> String:
	var L: PackedStringArray = []
	L.append("Mote, by Hot Attic Games.")
	L.append("")
	for a in ASSETS:
		L.append("%s.\n  Licence: %s" % [a[0], a[1]])
	L.append("")
	L.append("This game uses Godot Engine (godotengine.org), available under the following licence:")
	L.append("")
	L.append(Engine.get_license_text())
	L.append("")
	L.append("Godot Engine includes these third-party components:")
	for c in Engine.get_copyright_info():
		var parts: PackedStringArray = []
		for p in c["parts"]:
			var who := ", ".join(PackedStringArray(p.get("copyright", [])))
			parts.append("%s%s" % [("(c) " + who + ". ") if who != "" else "", "Licence: " + str(p.get("license", "?"))])
		L.append("- %s: %s" % [c["name"], " / ".join(parts)])
	L.append("")
	L.append("Licence texts:")
	var info := Engine.get_license_info()
	var names: Array = info.keys()
	names.sort()
	for n in names:
		L.append("")
		L.append("== %s ==" % n)
		L.append(str(info[n]))
	return "\n".join(L)
