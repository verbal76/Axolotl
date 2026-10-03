extends RefCounted
## Hot Attic Games application infrastructure (ledger row 38): OTA discovery on resume, the
## "Please wait, applying update" activation modal, About / Copy diagnostics and the studio splash.
## Runs inside the unit suite (--only=_test_hag_infra).

var t
var g: Game


func _init(runner) -> void:
	t = runner
	g = runner.g


func run() -> void:
	_test_resume_check_wall_clock()


## The resume check measures its gap on the wall clock (the engine clock stops while the phone
## sleeps), counts every earlier check, and survives a clock that went backwards or a bad stamp.
func _test_resume_check_wall_clock() -> void:
	var now := Time.get_unix_time_from_datetime_string("2026-10-03T12:00:00")
	var gap := 15 * 60
	var cases := [["", true], ["2026-10-03T11:59:00Z", false], ["2026-10-03T11:45:00Z", true],
			["2026-10-02T23:00:00Z", true], ["2026-10-03T12:30:00Z", true], ["garbage", true]]
	var bad: Array[String] = []
	for c in cases:
		if AutoUpdate.resume_check_due(now, c[0], gap) != c[1]:
			bad.append("%s -> %s" % [c[0], not c[1]])
	t.check("hag_resume_check_wall_clock", bad.is_empty(), ", ".join(bad))
