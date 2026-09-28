class_name Completion
extends RefCounted
## THE completion catalog: every completion-bearing thing in Mote, with a stable id, and the one
## place that turns "what this save has earned" into a percentage. Gameplay scripts only report
## ids (Game._earn); no denominator or percentage lives anywhere else.
##
## Model (docs/COMPLETION.md):
## - Each entry belongs to one CATEGORY. A category's share of 100% is fixed; inside a category
##   every entry counts its weight (1 unless stated). Percent = sum over categories that have
##   entries of share x (earned weight / total weight), normalised by those categories' shares.
## - 100% only when every entry is earned (never rounded up); never more than 100%.
## - Ids are permanent. Content added by a later OTA adds entries (and bumps CATALOG_VERSION);
##   the denominator grows, so a save's percentage can go down while nothing it earned is lost.
##   Earned ids the catalog no longer lists are kept in the save but not counted.
## - Finishing the game (every moss ball restored) is separate from 100%.

## Bump whenever the set of entries changes.
const CATALOG_VERSION := 3

## id: [label, share of 100%]. Shares must sum to 100.
const CATEGORIES := {
	"restoration": ["Moss restored", 45.0],
	"caves": ["Hidden caves", 18.0],
	"blooms": ["Blooms found", 13.5],
	"milestones": ["Milestones", 13.5],
	"wildlife": ["Wildlife", 10.0],
}

## Milestone ids that are not tied to one node.
const ENDING_ID := "ending.all_clear"

## id -> {"category", "label", "weight"}
var entries := {}
## Ids in catalog order.
var order: Array[String] = []


func add(id: String, category: String, label: String, weight := 1.0) -> void:
	assert(CATEGORIES.has(category), "unknown completion category " + category)
	assert(not entries.has(id), "duplicate completion id " + id)
	entries[id] = {"category": category, "label": label, "weight": weight}
	order.append(id)


func has(id: String) -> bool:
	return entries.has(id)


func size() -> int:
	return order.size()


## Per category: {"label", "share", "done", "total", "done_w", "total_w"} (earned = id -> anything).
func categories(earned: Dictionary) -> Dictionary:
	var out := {}
	for c in CATEGORIES:
		out[c] = {"label": CATEGORIES[c][0], "share": CATEGORIES[c][1], "done": 0, "total": 0, "done_w": 0.0, "total_w": 0.0}
	for id in order:
		var e: Dictionary = entries[id]
		var c: Dictionary = out[e["category"]]
		c["total"] += 1
		c["total_w"] += e["weight"]
		if earned.has(id):
			c["done"] += 1
			c["done_w"] += e["weight"]
	return out


## Completion in percent, 0..100. Exactly 100 only when nothing remains.
func percent(earned: Dictionary) -> float:
	var cats := categories(earned)
	var share := 0.0
	var got := 0.0
	for c in cats.values():
		if c["total_w"] <= 0.0:
			continue
		share += c["share"]
		got += c["share"] * c["done_w"] / c["total_w"]
	if share <= 0.0:
		return 0.0
	if remaining(earned).is_empty():
		return 100.0
	# Below 100 whenever anything remains, however small its weight.
	return minf(got / share * 100.0, 99.99)


## The whole-number percentage players see: rounded down, so 99.6% never shows as 100%.
func percent_display(earned: Dictionary) -> int:
	return int(floor(percent(earned)))


func remaining(earned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in order:
		if not earned.has(id):
			out.append(id)
	return out


## Earned ids this catalog counts (unknown ids in the save are ignored here, not deleted).
func earned_known(earned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in order:
		if earned.has(id):
			out.append(id)
	return out


## Short lines for the pause menu: "Moss restored 40 / 64".
func summary_lines(earned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cats := categories(earned)
	for c in CATEGORIES:
		var d: Dictionary = cats[c]
		if d["total"] > 0:
			out.append("%s  %d / %d" % [d["label"], d["done"], d["total"]])
	return out


# --- The current game's catalog -----------------------------------------------------------

static func ball_tag(index: int) -> String:
	return "b%d" % (index + 1)


static func vortex_id(a: int, b: int) -> String:
	return "vortex.%s-%s" % [ball_tag(a), ball_tag(b)]


static func _fixed_ids(nodes: Array) -> Dictionary:
	var out := {}
	for nd in nodes:
		if nd.has_meta("fixed_id"):
			out[str(nd.get_meta("fixed_id"))] = true
	return out


## A node's id: its explicit one, or the next free number after `prefix`.
static func _id_for(nd: Object, prefix: String, counters: Dictionary, taken: Dictionary) -> String:
	if nd.has_meta("fixed_id"):
		return str(nd.get_meta("fixed_id"))
	var i: int = counters.get(prefix, 0)
	while taken.has("%s.%d" % [prefix, i]):
		i += 1
	counters[prefix] = i + 1
	return "%s.%d" % [prefix, i]


static func ball_restored_id(index: int) -> String:
	return "%s.restored" % ball_tag(index)


## Builds the catalog from the built world and stamps each completion-bearing node with its id
## (meta "completion_id"). Ids come from level data order, which is deterministic:
##   b1.<zone>.parasite.<n>, b1.<zone>.mote.<n>   restoration (n counts within the zone, from 0)
##   b1.cave.<n>                                   caves (health upgrades in hidden caves)
##   b1.bloom.<n>                                  blooms (checkpoints)
##   b5.crab.<n>, b5.eel.<n>, species.<name>       wildlife (Expansion 5)
##   b1.restored, vortex.b1-b2, ending.all_clear   milestones
##
## World expansion: authored content may carry an explicit id (meta "fixed_id"), and new worlds give
## every completion-bearing node one, so rebuilding or reordering a world never remaps an id a save
## has earned (the shipped ids are frozen in CatalogFrozen). Nodes without one get the positional
## id above, skipping any number an explicit id already holds.
static func build_from_world(balls: Array, vortices: Array) -> Completion:
	var cat := Completion.new()
	for b in balls:
		var tag := ball_tag(b.index)
		var taken := _fixed_ids(b.parasites + b.motes + b.upgrades + b.blooms)
		var n := {}
		for par in b.parasites:
			var id := _id_for(par, "%s.%s.parasite" % [tag, par.zone_id], n, taken)
			par.set_meta("completion_id", id)
			cat.add(id, "restoration", "Parasite cleared")
		for m in b.motes:
			var id := _id_for(m, "%s.%s.mote" % [tag, m.zone_id], n, taken)
			m.set_meta("completion_id", id)
			cat.add(id, "restoration", "Mote returned")
		for u in b.upgrades:
			var id := _id_for(u, "%s.cave" % tag, n, taken)
			u.set_meta("completion_id", id)
			cat.add(id, "caves", "Hidden cave")
		for bl in b.blooms:
			var id := _id_for(bl, "%s.bloom" % tag, n, taken)
			bl.set_meta("completion_id", id)
			cat.add(id, "blooms", "Bloom found")
	# Wildlife (Expansion 5): each species discovered, and each guardian crab and cave eel defeated.
	for b in balls:
		var tag := ball_tag(b.index)
		var threats: Array = b.critters.filter(func(c) -> bool: return c.species in ["crab", "eel"])
		var taken := _fixed_ids(threats)
		var n := {}
		for c in threats:
			c.threat_id = _id_for(c, "%s.%s" % [tag, c.species], n, taken)
			cat.add(c.threat_id, "wildlife", "Crab guardian defeated" if c.species == "crab" else "Cave eel defeated")
	for sp in Ecosystem.SPECIES:
		cat.add("species." + sp, "wildlife", "Species discovered: " + Ecosystem.SPECIES[sp])
	for b in balls:
		cat.add(ball_restored_id(b.index), "milestones", "Moss ball %d restored" % (b.index + 1))
	for v in vortices:
		var id := vortex_id(v.ball_a.index, v.ball_b.index)
		v.set_meta("completion_id", id)
		cat.add(id, "milestones", "Vortex opened")
	cat.add(ENDING_ID, "milestones", "Aquarium all clear")
	return cat
