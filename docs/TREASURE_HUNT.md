# Treasure Hunt — the postgame search

A replayable search that opens once the run reaches **100%**. Fourteen ridiculous everyday
objects are hidden in the seven restored moss-ball worlds, two per world. Gill finds them **one at
a time, in order**, and collects each by **lunging** into it. The first hunt uses full-size
objects; every hunt after it uses **half-size** objects, and they never shrink further.

The objects have no story and no explanation. The joke is that they are there at all.

**Code:**
- `scripts/core/treasure_hunt.gd`: rules, state, generation, placement and recovery.
- `scripts/core/treasure_play.gd`: in play — the current object, pickup, celebration and advancing.
- `scripts/world/treasure_models.gd`: the fourteen objects.
- `scripts/ui/treasure_panel.gd`: the HUD card, notes and the finish card.
- `AxolotlModel.start_dance`: his happy dance.

## What it never touches

- **Completion is unchanged.** There are no completion ids, catalog v4 still has 348 ids, and
  the run's percentage and ending are the same.
- **The run clock is unchanged.** At 100% the run has already finished (100% includes the
  ending), so its time is frozen. Only the total play time counts on, as it does after any finish.
- **No random generator but its own.** Each hunt has its own seeded generator. The celebration
  effects use their own generators too. The global generator (gameplay, the seeded bot) and the
  cosmetic ones never move. The tests check this directly.
- **No new systems:** no XP, currency or inventory.

## Unlock

`TreasureHunt.eligible(percent)` returns true at exactly 100%.
- **Older saves:** an older save already at 100% qualifies with no migration step. The run save
  gains a `run["treasure"]` entry, and `RunSave.migrate` backfills it.
- **No version bump:** the run-save format and the settings save schema are unchanged.
- **Before 100%** nothing shows, anywhere.
- **At 100%:**
  - the title shows **Treasure Hunt**;
  - the pause menu shows a row: **Resume / Stop / New Treasure Hunt**.
- **New Run:** a new run starts a new record. Treasure Hunt then waits until that run reaches
  100%, because the hunt needs the restored worlds.

## A hunt

- **Order:** the fourteen objects are shuffled. The worlds visited are fourteen slots, two per
  world, shuffled so that no world appears twice in a row and never world by world.
- **Placement:** each object's spot is a short checked walk from a proven-reachable anchor in its
  world. Anchors are blooms (where he respawns), burrower holes and the arrival point.
- **Checks on every candidate spot:**
  - on the terrain surface, neither buried nor floating (within 0.5 m);
  - not in or on a ravine;
  - fairly level;
  - nothing solid where the object sits (a shape query);
  - head room to reach it;
  - inside the tank;
  - a walk from the anchor with no ravine, no step over 0.6 m and nothing solid in the way at
    body height.
- **Choosing among spots:** spots with a little cover are preferred, so the player has to look.
  A world's two objects sit apart, at least 35% of its radius. The previous hunt's spots are
  avoided.
- **Saved as generated:** the seed, order, positions and yaw are all saved. A reload reproduces
  the hunt exactly, and only **New hunt** generates again.
- **Recovery:** a saved spot that later fails the checks (the world changed, or the save was
  damaged) is replaced when shown. The replacement is a new valid spot in the same world for the
  same object, chosen from the hunt's seed. The order and progress are kept.

## Play

- **Only the current object exists** in the world. Future ones are just saved data, so they
  can't be found early, and there is only ever one extra mesh.
- **Pickup is the lunge only.** `Game.lunge_contact` asks `TreasurePlay.try_collect`.
  - The mouth's sweep must pass within the object's size × 0.4 + 0.55 m of its middle. That is
    forgiving on a phone without being automatic.
  - The lunge also aims toward the object when it is near and ahead, as it does for food.
  - Touching, Tail Swipe, Water Cannon, Bubble Blast, Gill Rush, fish and enemies can't collect
    it. It is never in `Game._strikeable`.
- **A find is saved before anything is shown.** One `TreasureHunt.collect` step, then the save.
  A quit at any moment keeps the find exactly once, and it can't count twice.
- **The celebration:**
  - a puff of confetti in five colours;
  - two small fireworks, five for the fourteenth. These use pooled water effects, so they are
    bounded and nothing is left behind.
  - Gill rises onto his back legs for a happy butt-and-tail wiggle (`Idle.DANCE`, 2.1 s). He is
    held still and invulnerable meanwhile, then control returns.
- **The HUD** (top left, under the run timer) shows only "TREASURE HUNT", a rendered picture of
  the current object, its name and "n / 14". There is no list, no world, no arrow and no distance.
- **After the fourteenth:** a short finale, then the finish card: TREASURE HUNT COMPLETE, 14 / 14
  found, with **New hunt** and **Later**. After the first hunt it adds "Next time, the treasures
  are smaller." The world waits while the card is up.
- **The aquarium experiences** never show the object and can't change the hunt.

## Size

| Hunt | Object size |
|---|---|
| First | Full, about 1–2 m across (he is about 1.2 m long) |
| Second and every later hunt | Exactly half (`TreasureHunt.HARD_SCALE`), never smaller |

## Performance

Nothing is built at startup. Models, placements and the HUD picture are made when a hunt is
played.
- **Generating a hunt:** about 0.2 s, only when a hunt starts.
- **In play:** one extra mesh of a few hundred to about two thousand triangles.

The measured startup, frame time and memory are in the release notes (ledger TH).

## Tests

The unit suite runs these after `_test_all_clear`, on worlds restored through play.
- **`_test_treasure_unlock`:**
  - locked below 100%, with no button anywhere;
  - open at 100%;
  - an old 100% save qualifies;
  - the catalog is unchanged.
- **`_test_treasure_generation`:**
  - 14 targets, all 14 kinds, two per world;
  - interleaved order;
  - the same seed gives the same hunt, a new seed a new one;
  - 168 spots over 12 hunts, all valid;
  - the gameplay RNG is untouched;
  - full size then half, for good.
- **`_test_treasure_play`:**
  - only the current object exists;
  - a reload gives the same hunt;
  - touching, the tail and all three Tier-2 abilities don't collect it;
  - a future object can't be taken;
  - the lunge collects it, and the find is saved at once;
  - the celebration runs, can't collect twice and ends cleanly;
  - the aquarium modes don't change the hunt;
  - a bad spot is recovered;
  - the whole first hunt is found by real lunges;
  - completion and the clock are untouched;
  - the second hunt is new and half size;
  - the third hunt is still half size;
  - a quit mid-celebration is safe.
- **Shots:**
  - `--only=treasures`: the fourteen objects;
  - `--only=treasurehunt`: HUD, finds in several worlds, the celebration, the dance, the finish
    card, the new hunt, full versus half size.
