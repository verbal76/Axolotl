# Tier 2 — Water Cannon, Bubble Blast, Gill Rush

Tail Swipe stays Gill's basic attack. Tier 2 adds three extra abilities, each found by exploring
one world. Code: `scripts/core/tier2.gd` (rules and save), `scripts/core/tier2_combat.gd` (execution),
`scripts/actors/tier2_shrine.gd`, `scripts/actors/practice_target.gd`, `scripts/ui/tier2_glyphs.gd`,
`scripts/ui/tier2_loadout.gd` and the HUD button in `scripts/ui/hud.gd`.

## Owner decisions

These were answered before implementation:

- **Unlocks are per run.** They are saved with the run and reset by New Run. They are never
  completion entries, so the catalog stays v4 (348 entries).
- **Where they are found:** landmark shrines, in a fixed order.
  - **World 3, High Crown:** Water Cannon.
  - **World 5, Secret Clearing:** Bubble Blast.
  - **World 7, Glow Chamber:** Gill Rush.
- **Loadout:** a row on the pause-menu page.
  - Any number of abilities can be unlocked, but exactly one is equipped at a time.
  - The first ability unlocked is equipped straight away.
- **Pufferfish:** they can be beaten with ordinary combat (3 hits). No new ids were added. See
  `docs/ECOSYSTEM.md`.

## Rules

- **One Tier-2 button.** It sits above-left of Jump (L key, controller Y) and is hidden until the
  first shrine.
  - It shows the equipped ability's glyph.
  - A radial fill refills during the cooldown, with a flash when the ability is ready again.
- **Cooldown after use:**

  | Ability | Cooldown |
  |---|---|
  | Water Cannon | 5 s |
  | Bubble Blast | 8 s |
  | Gill Rush | 9 s |

  - The cooldown is shared, so swapping abilities never skips it.
  - It is not saved, so a continued run starts ready.
- **Which targets count.** Valid targets are `Game._strikeable`: live parasites, active hittable
  creatures (crab, eel, stalker, pufferfish) and practice targets.
  - Ambient fish, shrimp, snails, food and Motes are never targets.
  - Ties are broken by distance, then by instance id, so every choice is deterministic.
- **What a Tier-2 action blocks.** While one runs, it blocks the other actions and his idles.
- **What cancels one.** A cinematic, death or opening the aquarium cancels it.
- **Practice targets.** Taking a shrine also sets out harmless practice targets nearby.
  - They pop in one hit.
  - They leave after 90 s, or when Gill is more than 30 m away or on another ball.

## The three abilities

| | Water Cannon | Bubble Blast | Gill Rush |
|---|---|---|---|
| Target choice | The valid hostile closest to his facing, by the **shortest signed angle** (`Tier2.signed_angle`, atan2 about his up; +10° and −10° are equally close; 350° counts as −10°). It must be within 10 m, inside a 70° cone and in sight. | Every valid hostile inside the volume, each hit **once** | 1–3 different hostiles. The first is the best one ahead of him (7 m, 80° cone). Each next one is the nearest *reachable* hostile from the last impact, never almost straight back (≤165° turn). |
| Motion | A quick, smooth turn to the target, a brace, a jet fired at 0.24 s (speed 30) | A 0.14 s brace, then the shockwave | He **really travels** each leg (13 m/s, lunge pose): impact, redirect, impact |
| Effect | 2 stages plus knockback | 1 stage. The volume is the upper hemisphere of radius 4.2 round his body centre, plus 0.4 below the ground plane. Plants are blown radially **outward** (`Wake.add_blast`) and settle over about 2.6 s. | 1 stage per impact |
| Safety | No target: he fires straight ahead, harmlessly | Nothing is hit through terrain | A leg ends if its path is blocked, crosses a ravine, leaves the tank or runs more than 0.75 s. The chain then ends and he keeps his footing. |

## Glyphs

Each glyph is drawn in code (`Tier2Glyphs.draw`). They share one visual language and differ in
silhouette, so they read at phone size.

| Ability | Glyph |
|---|---|
| Water Cannon | a jet arrow |
| Bubble Blast | concentric rings round a dot |
| Gill Rush | a dashed, stepped arrow |

Renders: `--test=shots --only=tier2` shows each ability in its ready, mid-action and cooling-down
states, plus the loadout page.

## Tests

- `_test_tier2_rules` (9 checks): the unlock order, equip, cooldown, save round-trip and dropping
  unknown ids, the signed angle and its wraparound, cannon selection, the bubble volume and the rush
  plan.
- `_test_tier2_world` (9 checks):
  - shrines in Worlds 3, 5 and 7;
  - nothing before a shrine;
  - taking a shrine: unlock, equip, the button and the practice targets;
  - each ability in the world, driven by the Tier-2 button;
  - a rush ends safely.
- `_test_tier2_loadout`: the page is hidden until an ability is found. Tapping a found ability equips
  it and saves the run without touching the cooldown. Unfound abilities stay locked, and the row is
  hidden when the menu is opened from the title.
