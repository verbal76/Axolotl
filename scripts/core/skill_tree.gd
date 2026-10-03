class_name SkillTree
extends RefCounted
## The skill tree (owner-approved graph, ledger row 6; docs/SKILL_TREE.md): 15 nodes, five families
## x three tiers, bought with red starfish. The graph is DATA (NODES below): ids are permanent, the
## costs are 1 / 2 / 3 by tier (30 in all), three roots (Lunge I, Quick Gill I, Water Burst I) and
## nine cross-family prerequisites. Nothing here is a completion entry (the 348-id catalog is
## unchanged); there is no respec and no refund.
##
## A node's effect is read by tier: each family's tier is the highest of its nodes owned
## (GillProgress.tier). The numbers each tier gives are TIERS (and the Glide model's in Axolotl).

const FAMILIES := ["lunge", "quick", "burst", "magnet", "glide"]
## Family display names (the character's name comes from its one canonical source).
const FAMILY_NAMES := {
	"lunge": "Lunge",
	"quick": "Quick " + GameVersion.CHARACTER_NAME,
	"burst": "Water Burst",
	"magnet": "Mote Magnet",
	"glide": "Glide",
}
const ROMAN := ["", "I", "II", "III"]

## The approved graph. `requires`: every one must be owned first. `col`/`row`: where the page draws
## it (families across, tiers down).
const NODES := [
	{"id": "lunge.1", "family": "lunge", "tier": 1, "cost": 1, "requires": [], "sub": "Long Lunge"},
	{"id": "burst.1", "family": "burst", "tier": 1, "cost": 1, "requires": [], "sub": "Strong Burst"},
	{"id": "quick.1", "family": "quick", "tier": 1, "cost": 1, "requires": [], "sub": ""},
	{"id": "magnet.1", "family": "magnet", "tier": 1, "cost": 1, "requires": ["lunge.1"], "sub": ""},
	{"id": "glide.1", "family": "glide", "tier": 1, "cost": 1, "requires": ["burst.1"], "sub": ""},
	{"id": "lunge.2", "family": "lunge", "tier": 2, "cost": 2, "requires": ["lunge.1", "quick.1"], "sub": "Steered Lunge"},
	{"id": "burst.2", "family": "burst", "tier": 2, "cost": 2, "requires": ["burst.1"], "sub": "Long Burst"},
	{"id": "quick.2", "family": "quick", "tier": 2, "cost": 2, "requires": ["quick.1"], "sub": ""},
	{"id": "magnet.2", "family": "magnet", "tier": 2, "cost": 2, "requires": ["magnet.1"], "sub": ""},
	{"id": "glide.2", "family": "glide", "tier": 2, "cost": 2, "requires": ["glide.1", "burst.2"], "sub": ""},
	{"id": "lunge.3", "family": "lunge", "tier": 3, "cost": 3, "requires": ["lunge.2", "magnet.2"], "sub": "Sure Lunge"},
	{"id": "burst.3", "family": "burst", "tier": 3, "cost": 3, "requires": ["burst.2", "glide.1"], "sub": "Steered Burst"},
	{"id": "quick.3", "family": "quick", "tier": 3, "cost": 3, "requires": ["quick.2", "lunge.2"], "sub": ""},
	{"id": "magnet.3", "family": "magnet", "tier": 3, "cost": 3, "requires": ["magnet.2", "lunge.2"], "sub": ""},
	{"id": "glide.3", "family": "glide", "tier": 3, "cost": 3, "requires": ["glide.2", "quick.2"], "sub": ""},
]
const TOTAL_COST := 30
const COUNT := 15

## What each tier of each family does (index 0 = none). Applied by Axolotl.apply_skills and Mote.
const TIERS := {
	# Ground run speed (the ground target only; the air target and so every jump is unchanged).
	"quick": {"run_scale": [1.0, 1.06, 1.11, 1.16]},
	# Lunge I: a longer lunge (0.28 s -> 0.31 s, 2.3 m -> 2.6 m of travel). II: the stick steers it.
	# III: a surer catch (food and Motes within a larger radius of the mouth's sweep).
	"lunge": {"time": [0.28, 0.31, 0.31, 0.31], "steer": [0.0, 0.0, 9.0, 9.0], "catch": [0.0, 0.0, 0.0, 0.2]},
	# Water Burst I: a stronger DIRECTIONAL burst (further, and a little higher, but never above the
	# up-only burst's height). The up-only burst is unchanged at every tier, so the highest he can
	# ever reach stays exactly the shipped game's (3.76 m at 60 Hz, feet above the takeoff; the
	# research's 8.6 would have made it 3.85 m, 5 cm under the 3.9 m ledges). II: its speed carries
	# longer (air drag x0.35 for 0.45 s). III: the stick bends its direction during that carry.
	"burst": {"h": [8.8, 9.6, 9.6, 9.6], "up": [5.2, 5.5, 5.5, 5.5], "up_only": [8.4, 8.4, 8.4, 8.4],
			"carry": [0.0, 0.0, 0.45, 0.45], "carry_k": [1.0, 1.0, 0.35, 0.35], "steer": [0.0, 0.0, 0.0, 4.0]},
	# Mote Magnet: an available Mote in line of sight within `range` drifts toward him (accel m/s^2).
	# It never captures; a missed lunge startles Motes out of it for `startle` seconds.
	"magnet": {"range": [0.0, 2.5, 3.5, 4.5], "accel": [0.0, 1.4, 2.2, 3.0], "leash": [0.0, 1.0, 1.8, 2.6], "startle": [0.0, 2.5, 2.5, 2.5]},
	# Glide ("tiring wing", docs/SKILL_TREE.md): fresh sink s0 and forward speed v, tiring with time
	# constant tau toward a parachute sink s_end and a slow drift v_end.
	"glide": {"s0": [0.0, 2.7, 2.3, 2.0], "tau": [0.0, 1.0, 1.2, 1.35], "v": [0.0, 6.9, 7.2, 7.4]},
}
## Shared by every glide tier: tired sink (a soft landing: 6.5 m/s is a 1.06 m fall), tired drift,
## how quickly the forward speed eases to the target, and how hard a faster fall is braked.
const GLIDE_S_END := 6.5
const GLIDE_V_END := 3.5
const GLIDE_ACCEL := 9.0
const GLIDE_BRAKE := 14.0
## He opens into the glide near the top of a jump: once rising slower than this (m/s).
const GLIDE_ENTER := 1.0

## One line per node for the page's card: what buying it changes.
const EFFECTS := {
	"lunge.1": "Your lunge reaches further (about 2.6 m instead of 2.3 m).",
	"lunge.2": "Steer your lunge with the stick while it flies.",
	"lunge.3": "A surer catch: food and Motes are caught from a little further.",
	"quick.1": "Run a little faster on the ground (+6%).",
	"quick.2": "Run faster on the ground (+11%).",
	"quick.3": "Run fastest on the ground (+16%). Jumps stay the same.",
	"burst.1": "A stronger water burst: a little further and higher.",
	"burst.2": "The burst's push carries on for longer.",
	"burst.3": "Bend the burst's path with the stick as it carries you.",
	"magnet.1": "Nearby Motes drift gently toward you.",
	"magnet.2": "Motes drift toward you from further away.",
	"magnet.3": "Motes drift toward you from further still, and faster.",
	"glide.1": "Hold Jump in the air to glide a short way. Let go to drop.",
	"glide.2": "Glide further and descend more slowly.",
	"glide.3": "Your best glide: a long, gentle descent to nearby ground.",
}


static func node(id: String) -> Dictionary:
	for n in NODES:
		if n["id"] == id:
			return n
	return {}


static func has(id: String) -> bool:
	return not node(id).is_empty()


static func ids() -> Array[String]:
	var out: Array[String] = []
	for n in NODES:
		out.append(n["id"])
	return out


static func title(id: String) -> String:
	var n := node(id)
	if n.is_empty():
		return id
	var t: String = FAMILY_NAMES[n["family"]] + " " + ROMAN[int(n["tier"])]
	return t + (": " + str(n["sub"]) if str(n["sub"]) != "" else "")


static func cost(id: String) -> int:
	var n := node(id)
	return int(n.get("cost", 0))


## Prerequisites of `id` not in `owned` (id -> anything).
static func missing(id: String, owned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r in node(id).get("requires", []):
		if not owned.has(r):
			out.append(r)
	return out


## "purchased" | "available" (prerequisites owned, affordable) | "unaffordable" (prerequisites owned,
## too few starfish) | "locked" (a prerequisite is missing).
static func state(id: String, owned: Dictionary, balance: int) -> String:
	if owned.has(id):
		return "purchased"
	if not missing(id, owned).is_empty():
		return "locked"
	return "available" if balance >= cost(id) else "unaffordable"


## The proof the owner asked to keep as a test: over the graph as data, no cycles, all 15 reachable,
## total 30, and no deadlock in any reachable purchase state (exhaustive over all 2^15 subsets, with
## `stars` starfish available: a state is reachable if some order of purchases, each affordable
## when made, builds it; a reachable state other than "everything" is a deadlock if nothing more can
## be bought). Returns {"ok", "acyclic", "reachable", "total", "states", "deadlocks", "roots", "cross"}.
static func prove(stars := 30, nodes: Array = NODES) -> Dictionary:
	var n := nodes.size()
	var ix := {}
	for i in n:
		ix[nodes[i]["id"]] = i
	var req: Array[int] = []
	var costs: Array[int] = []
	var bad_ref := false
	for nd in nodes:
		var m := 0
		for r in nd["requires"]:
			if not ix.has(r):
				bad_ref = true
				continue
			m |= 1 << int(ix[r])
		req.append(m)
		costs.append(int(nd["cost"]))
	# Acyclic: Kahn's algorithm over the prerequisite edges.
	var indeg: Array[int] = []
	for i in n:
		var c := 0
		for j in n:
			if req[i] >> j & 1:
				c += 1
		indeg.append(c)
	var queue: Array[int] = []
	for i in n:
		if indeg[i] == 0:
			queue.append(i)
	var seen := 0
	while not queue.is_empty():
		var i: int = queue.pop_front()
		seen += 1
		for j in n:
			if req[j] >> i & 1:
				indeg[j] -= 1
				if indeg[j] == 0:
					queue.append(j)
	var total := 0
	for c in costs:
		total += c
	var full := (1 << n) - 1
	var spent := func(s: int) -> int:
		var k := 0
		for i in n:
			if s >> i & 1:
				k += costs[i]
		return k
	var reach := PackedByteArray()
	reach.resize(1 << n)
	reach[0] = 1
	var frontier: Array[int] = [0]
	var states := 1
	var deadlocks := 0
	while not frontier.is_empty():
		var nxt: Array[int] = []
		for s in frontier:
			var sp: int = spent.call(s)
			var any := false
			for i in n:
				if s >> i & 1 or (req[i] & s) != req[i] or sp + costs[i] > stars:
					continue
				any = true
				var t := s | 1 << i
				if reach[t] == 0:
					reach[t] = 1
					states += 1
					nxt.append(t)
			if not any and s != full:
				deadlocks += 1
		frontier = nxt
	var roots: Array[String] = []
	var cross := 0
	for nd in nodes:
		if (nd["requires"] as Array).is_empty():
			roots.append(nd["id"])
		for r in nd["requires"]:
			if str(r).get_slice(".", 0) != nd["family"]:
				cross += 1
	var ok: bool = not bad_ref and seen == n and reach[full] == 1 and total == TOTAL_COST and deadlocks == 0 and n == COUNT
	return {"ok": ok, "acyclic": seen == n, "reachable": reach[full] == 1, "total": total, "states": states,
			"deadlocks": deadlocks, "roots": roots, "cross": cross, "bad_ref": bad_ref}
