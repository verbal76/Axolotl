class_name StarfishTable
extends RefCounted
## The 30 red starfish (docs/SKILL_TREE.md): a static table with permanent ids star.b<ball>.<nn>.
## Every one is reachable with no skills (the no-upgrade sweep, _phase_starfish_sweep, collects all
## 30 physically). Each sits on an authored feature, at least CLEAR m from any Mote's anchor, bloom,
## shrine or cave reward, validated with Treasure Hunt's own spot checks (restored and unrestored).
## At load a spot that no longer holds is moved to the nearest valid point on the same feature,
## keeping its id (Starfish.resolve).
##
## ll: [latitude, longitude] of the spot; alt: the height of the surface it rests on above the ball's
## base terrain (the probe starts just above it); kind: ground | rock | leaf | cave (which of Treasure
## Hunt's validators applies).

const COUNT := 30
## Size of a starfish as a Treasure Hunt "scale" (1.3 m x scale across): about 0.45 m.
const SCALE := 0.35
const CLEAR := 1.5

const STARS := [
	{"id": "star.b1.00", "ball": 1, "ll": [70.6, 0.0], "alt": 0.0, "kind": "ground", "where": "Glade Upland, open moss near the first bloom"},
	{"id": "star.b1.01", "ball": 1, "ll": [18.56, -15.51], "alt": 2.8, "kind": "rock", "where": "top of the Meadow Stone"},
	{"id": "star.b1.02", "ball": 1, "ll": [64.73, -105.84], "alt": 3.78, "kind": "rock", "where": "the natural stone bridge over the Split Crack"},
	{"id": "star.b1.03", "ball": 1, "ll": [67.0, -160.0], "alt": 4.8, "kind": "rock", "where": "summit of Lookout Rock"},
	{"id": "star.b1.04", "ball": 1, "ll": [-31.16, -65.32], "alt": 4.92, "kind": "rock", "where": "the Fern Grove high shelf, at the top of its bubble column"},
	{"id": "star.b1.05", "ball": 1, "ll": [24.0, -100.4], "alt": 0.0, "kind": "cave", "where": "floor of the hidden moss cave by the West Stone Ridge"},
	{"id": "star.b2.00", "ball": 2, "ll": [1.9, -67.0], "alt": 0.0, "kind": "ground", "where": "the arrival meadow"},
	{"id": "star.b2.01", "ball": 2, "ll": [14.41, -20.6], "alt": 6.34, "kind": "rock", "where": "top of the Mesa"},
	{"id": "star.b2.02", "ball": 2, "ll": [10.4, 29.33], "alt": 3.44, "kind": "rock", "where": "the Undercut Hollows' high coral shelf"},
	{"id": "star.b2.03", "ball": 2, "ll": [-54.37, -27.65], "alt": 3.6, "kind": "rock", "where": "the south tower, its upper step"},
	{"id": "star.b2.04", "ball": 2, "ll": [68.7, 110.0], "alt": 0.0, "kind": "cave", "where": "floor of the north-cap cave"},
	{"id": "star.b3.00", "ball": 3, "ll": [25.7, -28.3], "alt": 8.8, "kind": "leaf", "where": "the spiral leaf where the canopy bubble column tops out"},
	{"id": "star.b3.01", "ball": 3, "ll": [19.3, -35.2], "alt": 17.4, "kind": "leaf", "where": "the last canopy leaf at the top of the giant spiral"},
	{"id": "star.b3.02", "ball": 3, "ll": [42.23, 113.3], "alt": 28.96, "kind": "leaf", "where": "the High Crown, the Great Trunk's top leaf"},
	{"id": "star.b3.03", "ball": 3, "ll": [58.2, 110.6], "alt": 7.2, "kind": "leaf", "where": "the top leaf of a jungle stem below the High Crown"},
	{"id": "star.b3.04", "ball": 3, "ll": [-65.8, -93.0], "alt": 0.0, "kind": "ground", "where": "the Root Tangle, under the arching roots"},
	{"id": "star.b4.00", "ball": 4, "ll": [27.83, -62.34], "alt": 4.79, "kind": "rock", "where": "crown of the Grand Terraces"},
	{"id": "star.b4.01", "ball": 4, "ll": [14.5, -65.2], "alt": 3.5, "kind": "rock", "where": "the Twin Terrace, over the stone bridge"},
	{"id": "star.b4.02", "ball": 4, "ll": [-49.62, 126.8], "alt": 3.26, "kind": "rock", "where": "top of the arch"},
	{"id": "star.b5.00", "ball": 5, "ll": [32.2, -116.0], "alt": 2.9, "kind": "rock", "where": "the canyon bridge over the reeds"},
	{"id": "star.b5.01", "ball": 5, "ll": [42.14, 58.9], "alt": 0.0, "kind": "ground", "where": "the Secret Clearing"},
	{"id": "star.b5.02", "ball": 5, "ll": [-29.5, 152.0], "alt": 1.4, "kind": "rock", "where": "Stalker Hollow, the mound without a Mote"},
	{"id": "star.b5.03", "ball": 5, "ll": [16.3, -52.1], "alt": 0.0, "kind": "cave", "where": "floor of the canyon-end cave"},
	{"id": "star.b6.00", "ball": 6, "ll": [-51.03, 98.27], "alt": 2.45, "kind": "rock", "where": "the Low Garden, its middle mound"},
	{"id": "star.b6.01", "ball": 6, "ll": [-12.4, -122.7], "alt": 13.8, "kind": "leaf", "where": "the Canopy Spire's second crown leaf"},
	{"id": "star.b6.02", "ball": 6, "ll": [35.3, 55.6], "alt": 29.9, "kind": "leaf", "where": "the Sky Spire, the leaf below the crown bloom"},
	{"id": "star.b7.00", "ball": 7, "ll": [10.63, 121.4], "alt": 2.78, "kind": "rock", "where": "the high shelf above the corridors"},
	{"id": "star.b7.01", "ball": 7, "ll": [1.2, 13.6], "alt": 6.0, "kind": "rock", "where": "the Shaft's ledge at the top of its bubble column"},
	{"id": "star.b7.02", "ball": 7, "ll": [38.61, -136.63], "alt": 0.0, "kind": "cave", "where": "the Glow Chamber floor (the boulder rolls away when the grotto heals)"},
	{"id": "star.b7.03", "ball": 7, "ll": [-32.9, 110.1], "alt": 3.9, "kind": "rock", "where": "crown of the eastern Undercut stone bridge"},
]


static func has(id: String) -> bool:
	return not entry(id).is_empty()


static func entry(id: String) -> Dictionary:
	for s in STARS:
		if s["id"] == id:
			return s
	return {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for s in STARS:
		out.append(s["id"])
	return out
