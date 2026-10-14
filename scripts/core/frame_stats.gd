class_name FrameStats
extends Node
## Frame pacing on the device, kept apart for the title (the orbit round him) and play, for
## Diagnostics (owner 2026-10-01: the title orbit looks choppy on the phone while the orbit itself is
## smooth per frame on desktop; these numbers say whether frames arrive late or unevenly there).
## Also the main thread's own step time (the engine's process + physics time: scripts, physics,
## animation; not rendering) per frame (owner 2026-10-14, "sluggish"): a frame much longer than its
## step was waiting on drawing (the GPU or the render submission), not on game logic.

const KEEP := 600   # last ~10 s of frames per state

var g: Node
var _ms := {"title": PackedFloat32Array(), "play": PackedFloat32Array()}
var _step := {"title": PackedFloat32Array(), "play": PackedFloat32Array()}


func _process(dt: float) -> void:
	if g == null or not _ms.has(g.state) or get_tree().paused:
		return
	var a: PackedFloat32Array = _ms[g.state]
	a.append(dt * 1000.0)
	if a.size() > KEEP:
		a.remove_at(0)
	_ms[g.state] = a
	var s: PackedFloat32Array = _step[g.state]
	s.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	if s.size() > KEEP:
		s.remove_at(0)
	_step[g.state] = s


## "title: 58.9 fps, median 16.7 ms, p95 18.2 ms, worst 41.0 ms, 2% over 25 ms (600 frames);
## step median 7.1 ms, p95 9.0 ms".
func line(state: String) -> String:
	var a: PackedFloat32Array = (_ms[state] as PackedFloat32Array).duplicate()
	if a.size() < 30:
		return "%s: not enough frames yet" % state
	var total := 0.0
	var slow := 0
	for v in a:
		total += v
		if v > 25.0:
			slow += 1
	a.sort()
	var s: PackedFloat32Array = (_step[state] as PackedFloat32Array).duplicate()
	s.sort()
	return "%s: %.1f fps, median %.1f ms, p95 %.1f ms, worst %.1f ms, %d%% over 25 ms (%d frames); step median %.1f ms, p95 %.1f ms" % [state,
			1000.0 * a.size() / total, a[a.size() / 2], a[int(a.size() * 0.95)], a[a.size() - 1], roundi(100.0 * slow / a.size()), a.size(),
			s[s.size() / 2], s[int(s.size() * 0.95)]]
