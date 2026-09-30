# Skill tree and red starfish (release 00036-skill-tree)

Owner approval: ledger row 6 (2026-09-30), with the owner's rulings 1–13. Code:

| What | Where |
|---|---|
| The graph (data), tier values, effects text, the proof | `scripts/core/skill_tree.gd` (`SkillTree`) |
| Permanent progression, the loss-proof store | `scripts/core/gill_progress.gd` (`GillProgress`) |
| The 30 starfish (static table) | `scripts/core/starfish_table.gd` (`StarfishTable`) |
| A starfish (look, placement checks, relocation) | `scripts/actors/starfish.gd` (`Starfish`) |
| Placing them, touch pickup | `scripts/world/starfish_field.gd` (`StarfishField`) |
| Skills applied to movement; Glide | `scripts/actors/axolotl.gd` (`apply_skills`, the glide block) |
| Glide posture | `scripts/actors/axolotl_model.gd` (`glide` weight) |
| Mote Magnet | `scripts/actors/mote.gd` (`_magnet`, `startle`) |
| The page | `scripts/ui/skill_tree_page.gd` (`SkillTreePage`), opened from `pause_menu.gd` and `title_screen.gd` |
| HUD star chip | `scripts/ui/star_chip.gd`, `hud.gd` |
| Sounds | `tools/gen_audio.py` `skills()`: `sfx_starfish.wav`, `sfx_skill_unlock.wav` |
| Tests | `scripts/tests/skill_tests.gd` (called from `unit_tests.gd`) |
| Renders | `--test=shots --only=skilltree`, `--only=starfish`, `--only=glide`, `--only=perfstar` |

## 1. The tree (ruling 1)

The researched graph, exactly, shipped as data (`SkillTree.NODES`): 15 nodes, five families by
three tiers, costs 1 / 2 / 3 (30 in all), roots Lunge I, Quick Gill I and Water Burst I, and nine
cross-family prerequisites:

| Node | Cost | Requires |
|---|---|---|
| Lunge I: Long Lunge | 1 | — |
| Quick Gill I | 1 | — |
| Water Burst I: Strong Burst | 1 | — |
| Mote Magnet I | 1 | Lunge I |
| Glide I | 1 | Water Burst I |
| Lunge II: Steered Lunge | 2 | Lunge I, Quick Gill I |
| Quick Gill II | 2 | Quick Gill I |
| Water Burst II: Long Burst | 2 | Water Burst I |
| Mote Magnet II | 2 | Mote Magnet I |
| Glide II | 2 | Glide I, Water Burst II |
| Lunge III: Sure Lunge | 3 | Lunge II, Mote Magnet II |
| Quick Gill III | 3 | Quick Gill II, Lunge II |
| Water Burst III: Steered Burst | 3 | Water Burst II, Glide I |
| Mote Magnet III | 3 | Mote Magnet II, Lunge II |
| Glide III | 3 | Glide II, Quick Gill II |

`SkillTree.prove()` re-proves it on the shipped data in every test run (`skilltree_graph_proof`):
no cycles (Kahn), all 15 reachable, total 30, and no deadlock in any reachable purchase state
(exhaustive over the 2^15 subsets with 30 starfish: 272 reachable states, 0 deadlocks). The
checker's own negative tests: an injected cycle, and 29 starfish, are both caught.

## 2. The tiers (final values)

Every value is exactly the base constant at tier 0, so a player without skills moves exactly as
before (the seeded playthroughs are unchanged: section 8).

| Family | I | II | III |
|---|---|---|---|
| Quick Gill: ground run target | x1.06 (6.57 m/s) | x1.11 (6.88) | x1.16 (7.19) |
| Lunge | lunge 0.31 s (base 0.28): 2.96 m of travel instead of 2.71 | + the stick steers a lunge that is not homing (9 rad/s) | + catch radius +0.2 m (food 0.95 -> 1.15, Motes 0.9 -> 1.1) |
| Water Burst | directional 9.6 / 5.5 m/s (base 8.8 / 5.2); up-only unchanged 8.4 | + its push carries: air drag x0.35 for 0.45 s | + the stick bends its path during that carry (4 rad/s, speed unchanged) |
| Mote Magnet | range 2.5 m, 1.4 m/s² | 3.5 m, 2.2 m/s² | 4.5 m, 3.0 m/s² |
| Glide (section 3) | s0 3.0 m/s, tau 0.9 s, v 6.7 m/s | s0 2.5, tau 1.1, v 7.0 | s0 2.0, tau 1.35, v 7.4 |

Notes:
- **Quick Gill** scales the GROUND target only. In the air the target stays the base run, so a
  running jump is 5.63 m at every tier (x1.000 / 1.002 / 1.005 / 1.009 measured).
- **Treasure Hunt** keeps its own aim and reach (`TreasurePlay.REACH`, `AIM_RANGE`, `AIM_CONE`);
  a lunge aimed by it is never steered.
- **Water Burst and the ceiling.** The research set the up-only burst to 8.6 m/s from the analytic
  ceiling (1.849 + 1.849 = 3.70 m). Measured at 60 Hz the shipped game already reaches 3.76 m
  (Euler integration adds about 0.07 m per launch), and 8.6 would make it 3.85 m, 5 cm under the
  3.9 m ledges. So no tier raises the up-only burst: the highest he can ever reach is unchanged
  (base 3.76 m, Water Burst III 3.77 m, `burst_ceiling_under_ledges`), and the stronger directional
  burst peaks at 2.60 m.
- **Mote Magnet**: an available Mote in line of sight (a ray from the Mote to his body, re-read
  every 0.2 s), on his ball, not over a ravine and not while he is in one, drifts toward his head;
  its leash to its patch stretches by 1.0 / 1.8 / 2.6 m while drawn. It never captures (only a
  lunge does). A missed lunge startles every Mote within its range out of the pull for 2.5 s (the
  near-miss push is unchanged). It draws no random numbers, and with no Magnet it is never called.

## 3. Glide (rulings 2 and 3)

**Control.** Hold Jump in the air. He opens into the glide near the top of a jump (once rising
slower than 1.0 m/s) or at once when falling; letting go ends it. No new button. A tap of Jump
during a glide is the water burst, still once per air: the glide never resets it (only landing and
columns do); held on, he glides again after the burst's rise. A column, a current stream, a lunge, a
crawl, a hit or a Tier-2 move ends it.

**The physics: a tiring wing.** A glide's efficiency tires with time since it opened (a per-air
clock that runs on through bursts and releases, reset only by landing or a column):

    e    = exp(-t / tau)
    sink = s_end - (s_end - s0) * e        (fresh s0 -> tired s_end = 6.5 m/s)
    v    = v_end + (v - v_end) * e         (fresh v -> tired v_end = 3.5 m/s)

Above the sink he falls as ever; faster than it (opening from a fall) the spread body brakes him at
14 m/s². Forward speed eases toward `v` along the stick at 9 m/s².

**Why this model.** A fixed glide ratio (or quadratic drag) makes range grow linearly with the drop:
from the High Crown that is long-distance transport, whatever the ratio. A distance cap is
arbitrary. Here the glide is strongest for its first second and then settles into a slow
parachute: range grows only slowly with height, so it is local by construction.
- A held glide lands softly: the landing counts as the fall a free fall would need to reach the
  glide's descent speed, and 6.5 m/s is a 1.06 m fall. So a glide is also the controlled recovery
  toward reachable terrain the ruling describes.
- Letting go to fall on at full air speed is counted in every reach figure below (the best burst
  time and the best release time).

Compared with the research's tiers (reach in m from a running jump, best burst):

| Drop below takeoff | base | G-I | G-II | G-III | research G-III |
|---|---|---|---|---|---|
| 1.3 m | 9.7 | 11.4 | 12.1 | 12.9 | 16.0 |
| 4.6 m | 11.8 | 14.4 | 15.2 | 16.5 | ~24 |
| 9.7 m | 14.0 | 17.9 | 19.0 | 20.6 | 38 |
| 29 m (High Crown) | 19.9 | 28.9 | 30.4 | 32.5 | 88 |

(`glide_sim.py` / `sweep2.py` / `variants.py` in the scratchpad; the in-game measurements in the
next table agree.)

**Transfers on the real authored geometry** (`_test_glide_transfers`, and `_phase_glide_probe` for
every tier). Each try runs to the takeoff's edge and jumps (or rides a column up and bursts out),
stick on the target, over a set of burst times and release times; "reached" is a landing within
1.6 m of the target and 0.6 m of its height.

Intended (local traversal):

| Transfer | across / down | base | G-I | G-II | G-III |
|---|---|---|---|---|---|
| Undercut bridge crown -> the east bridge (platform to platform) | 11.6 / 2.7 m | no (lands 1.2 m below its end) | **yes**, soft | yes, soft | yes, soft |
| Undercut bridge crown -> the west bridge | 11.6 / 1.5 m | no | no | **yes**, soft | yes, soft |
| Grand Terraces crown -> the Twin Terrace bridge | 9.5 / 1.3 m | yes, hard landing | yes, soft | yes | yes |
| Twin Terrace bridge -> the Grand Terraces' second tier | 9.5 / 1.1 m | yes, hard | yes, soft | yes | yes |
| canopy crown leaf -> a jungle stem leaf 15 m below (canopy to a nearby leaf) | 14.5 / 15.5 m | yes, EXTREME landing (costs a frond) | yes, soft | yes, soft | yes |
| canopy bubble column top -> a lower canopy leaf (column top to a nearby perch) | 7.0 / 5.6 m | yes (leaf) | yes | yes | yes |
| jungle stem leaf -> a lower stem leaf 14 m on (leaf to leaf) | 12.7 / 7.4 m | yes, hard | yes, soft | yes, soft | yes, soft |

What the real world showed: the audited survey perches understate how wide the authored surfaces
are, so most of the research's "glide transfers" are already within a well-timed jump and burst.
Glide makes them easy and SAFE (a soft landing where the plain jump lands hard or extreme), and it
opens the platform-to-platform gaps just beyond a jump: the Undercut bridges need Glide I (east)
and Glide II (west). Two of the owner's examples do not exist as clean transfers in the geometry:
- **the Mesa column -> the Mesa's lower step**: every line from the column or the Mesa top to the
  lower step crosses the Mesa's own middle tiers, so any flight lands on those first;
- **column tops -> the next shelf**: a column top holds him with no run-up, so the burst out of it
  carries only 3.7 m (base) to 5.5 m (G-III, 2 m below). The fern and Hollows shelves are 8–11 m
  from the other column, and a spiral leaf 7.9 m from the canopy column is screened by the leaves
  between.

These are reported, not forced: widening the glide to make them would bring back the long-distance
transport the ruling removed.

Impossible (everything: Glide III, Water Burst III, Quick Gill III; every burst and release time):

IMPOSSIBLE_TABLE

Barriers (restoration gates shut; ten tries each: jump, up-only or directional burst at five times;
the skilled tries glide):

| Barrier | no skills | Glide III + Water Burst III + Quick Gill III |
|---|---|---|
| the Reed Wall (ball 5) | 0/10 | 0/10 |
| the Root Hollows curtain (ball 1) | **3/10** | 0/10 |
| the Glow Chamber boulder (ball 7) | 0/10 | 0/10 |

The Root Hollows curtain (3.1 m) can already be hopped with a jump and an up-only burst (3.76 m) in
the shipped game. That is pre-existing, not a skill's doing (the walls beside it also have their
authored over-the-top route), and it is queued as an old issue newly noticed. Glide never gains
height (`glide_never_gains_height`), so it cannot add a crossing.

## 4. Permanent progression: where it lives (ruling 4)

**Decision: its own file, `user://gill_progress.json` (`GillProgress`).** Not `run.json`, not
`settings.cfg`.

- **Semantics.** Starfish and skills belong to the profile, not to a run. `RunSave.start_new_run()`
  replaces the whole `run` on New Run (Tier 2 stays there, per run, as before). The progress file is
  never touched by New Run, a run save, or Return to Title.
- **settings.cfg is out.** `Settings.save()` rebuilds it from scratch in every build (the research
  found this); an older build would silently drop anything it did not know.
- **Rollback safety, verified in the code.** No build ever shipped writes or deletes this file: the
  b22 APK's bundled game (`1046057`) writes only `user://settings.cfg` and `user://ota/…`; later
  OTAs add `user://run.json` and `user://gill_pattern.png`; the OTA client only ever removes files
  under `user://ota`. A rollback to any older OTA leaves the file untouched, and the next update
  finds it intact. b22 installs (no RunSave at all) are fine: the file is created on the first
  starfish.
- **Mirror in run.json? No.** A copy inside `run.json` would add no real safety: it is the same
  disk, written by a different writer on a different cadence (so it would lag), and it would tie
  permanent progress to a file whose `run` part New Run replaces. The failures it could cover (both
  the main file and its backup damaged at once) are already covered by the write order below. The
  store keeps a rotating `.bak` and recovers from an interrupted `.tmp`.

**Format.** `{"format": 1, "kind": "mote.gill_progress", "seq": n, "collected": {id: {t, v}},
"purchased": {id: {cost, t, n}}, "written_by": {...}}`. The balance is NOT stored.

**Writing (atomic).** The whole document goes to `.tmp`, is flushed, read back and checked
(parses, same `seq`); the current main file is copied to `.bak`; `.tmp` is renamed over the main
file. POSIX rename replaces atomically, so the main file is always either the old document or the
new one, whole. A write that fails is reported, and a purchase whose write fails is undone
("spent but not unlocked" is impossible).

**Reading and recovery.** Every readable candidate (main, `.bak`, and a complete `.tmp` left by an
interrupted write) is MERGED by union. Both sets only ever grow (no respec, no refund), so the union
is the newest state; a damaged or older copy can add nothing wrong. An unreadable main file is kept
aside (`.unreadable-<n>`, never deleted) and the recovered state is written back at once. A file
from a newer format is read for play but never written.

**Reconcile on load (ruling 7).**
- An unknown starfish id is not counted. A well-formed one (`star.bN.NN`, from a newer table) is
  kept verbatim in the file, so a rollback never erases a newer build's record; garbage is dropped.
- A purchase is dropped only when provably invalid: a malformed record, or an id that is not a
  node id at all. A known node whose prerequisites are missing is never revoked. A node this build
  does not know keeps its recorded cost as spent, so a rollback can mint nothing.
- Spent over collected (a hand edit): the nodes are kept, the balance shows 0, and it is logged.

**The loss-proof matrix** (`progress_loss_proof_matrix`, all reconcile to a valid state):

| Case | Result |
|---|---|
| Normal: collect 3, buy Lunge I, reopen | 3 starfish, Lunge I, balance 2 (derived) |
| Truncated main + good .bak | recovered from .bak (5 starfish, 2 skills), main rewritten |
| Garbage main + good .bak | recovered (4 starfish, Water Burst I) |
| Main + older .bak | the union = the newer: 5 starfish, 2 skills, balance 3 |
| Interrupted between .tmp and rename | main had 2; the complete .tmp is merged: 3 starfish + Quick Gill I |
| .tmp truncated (a failed write) | the write reports failure; main keeps its 1 starfish; a stray broken .tmp is ignored |
| Unknown ids | counted 5 starfish, 1 skill, spent 3 (a newer node's cost counts); `star.b8.00` and `wings.1` kept in the file; garbage dropped |
| Hand-edited over-spend (15 nodes, 3 starfish) | all 15 kept, balance 0, over by 27, logged |
| Glide III without its prerequisites | kept (tier 3), balance 7 |
| Newer format | read-only: plays with its starfish; the file stays byte-identical |
| Unwritable disk | buying says "not saved"; nothing bought; balance unchanged |
| Touched but not yet written when the app died | not collected: it is still in the world |

## 5. The 30 red starfish (ruling 5)

Permanent ids `star.b<ball>.<nn>` in a static table (`StarfishTable.STARS`). All 30 need no skill;
restoration gates two of them the way the world already does (the Glow Chamber's boulder; the
Mesa's column is only one of its two ways up).

**Spot changes from the research table.** Every spot is checked with Treasure Hunt's own
validators for its kind (`TreasureHunt.target_ok` at a starfish's size, 0.45 m across) and must be
at least 1.5 m from every Mote anchor, bloom, Tier-2 shrine and cave reward. Thirteen research
spots were too close, most of them ON a route top's Mote (0.0–0.7 m). Each was moved on the same
feature to the nearest point with room (authored with 1.75 m where the surface allowed):

| Id | Research spot (clearance) | Now (clearance) | Why |
|---|---|---|---|
| star.b1.01 Meadow Stone | 20.0,-14.0 (0.0 m: its Mote) | 18.56,-15.51, 2.80 m (1.80 m) | same stone top, 1.8 m over |
| star.b1.02 Split Crack bridge | 64.8,-110.5 (0.03 m) | 64.73,-105.84, 3.78 m (1.81 m) | along the same bridge |
| star.b1.04 Fern shelf | -33.0,-65.7 (0.02 m) | -31.16,-65.32, 4.92 m (1.74 m) | the point of the small shelf with most room (a fine grid) |
| star.b2.01 Mesa top | 15.0,-20.0 (1.43 m) | 14.41,-20.60, 6.34 m (1.77 m) | 0.9 m over on the top |
| star.b2.02 Hollows high shelf | 12.0,30.0 (0.0 m) | 10.40,29.33, 3.44 m (1.80 m) | same shelf |
| star.b2.03 South tower | -56.5,-24.8 (0.06 m) | -54.37,-27.65, 3.60 m (2.81 m) | the tower's top holds only its Mote; the step just below it |
| star.b3.02 High Crown | 43.3,112.7 (0.08 m) | 42.23,113.30, 28.96 m (1.88 m) | same crown leaf |
| star.b4.00 Grand Terraces crown | 27.2,-64.1 (0.70 m) | 27.83,-62.34, 4.79 m (1.85 m) | same crown |
| star.b4.02 Arch top | -47.0,126.8 (0.02 m) | -49.62,126.80, 3.26 m (1.78 m) | along the arch |
| star.b5.01 Secret Clearing | 43.7,58.9 (0.71 m: the shrine/bloom) | 42.14,58.90, ground (1.77 m) | same clearing |
| star.b6.00 Low Garden | -45.5,103.3 (0.03 m) | -51.03,98.27, 2.45 m (4.15 m) | the tallest mound's top holds only its Mote; the middle mound |
| star.b7.00 High shelf | 9.9,121.4 (1.41 m) | 10.63,121.40, 2.78 m (2.01 m) | same shelf |
| star.b7.02 Glow Chamber | 40.0,-138.4 (0.58 m: the pearl) | 38.61,-136.63, floor (1.92 m) | same chamber floor |

The research's `star.b7.03` "FAILED" came from an older coordinate; the table's spot holds (10.6 m
clear). The other 16 are as researched.

At load, a spot that no longer holds is moved to the nearest valid point on the same feature
(the same collider), within 3 m, keeping its id (`Starfish.resolve`; `starfish_invalid_spot_
relocates_on_same_feature`). Today all 30 hold as authored, unrestored and restored.

**Presentation.** Clearly red (albedo 0.92/0.10/0.08, a red emission) with a soft local glow (the
Motes' own glow billboard, tinted), about 0.45 m across and lying flat on the surface, with only a
slow breath of its glow. The materials reuse set-ups already drawn in the first scene (the Mote
core's StandardMaterial3D features; `glow_billboard.gdshader`), so the first one in view compiles
no new pipeline (section 9). Touch pickup: his body centre within 0.9 m, on the ground or in the
air, no button, not while his controls are taken. A small red-and-gold burst, the starfish pops and
is gone, and its own sound: a rising bubble "bloop" into two bright kalimba plucks a fifth apart
(E6, B6) with a shimmer on top. That is plucked, not the Mote capture's bell nor the cave reward's
bell run, and its transient carries off-centre. It is synthesised by `tools/gen_audio.py` like the
other SFX (`--only=skills` writes just the two new files). The HUD chip (top left, under the run
timer) shows "12/30" and what there is to spend, for 3.6 s after a pickup.

**The sweep** (`_phase_starfish_sweep`): SWEEP_RESULT

## 6. Completion and finishes (rulings 8–10)

Starfish and skills are NOT in the completion catalog: the catalog stays v4 (348 ids) and its
pinned SHA test passes unchanged. The pause menu's run details and the title show "Red Starfish
n/30 · Skills n/15" separately. A finish records the skills owned (`run.finish.skills` and each
`records.finishes` entry) and shows "Finished in … · n% complete · Skills n/15" (older records
without it read as the current count). There is no skills-off mode, no respec and no refund.

## 7. The page (ruling 11)

`SkillTreePage`, a sibling of `GillPage` in `PauseMenu._root`, from the pause menu (Skills) and
from the title (Skills, straight to the page and back). The game stands still: from the pause menu
the tree is paused (the clock does not advance: `skill_page_from_pause_game_stands_still`); on the
title nothing runs.
- Families across (Magnet, Lunge, Quick, Burst, Glide, ordered to keep the cross links short),
  tiers down, the dependency links drawn as soft curves (gold when the prerequisite is owned).
- Node states: bought (the family colour, gold edge), can buy (bright edge, red star cost),
  too few starfish (dim, faded star), locked (dark, a lock).
- Tapping a node opens its card: its name, its state, what it does, and either its cost with the
  balance, the exact shortfall ("Needs 2 red starfish; you have 0. Find 2 more."), or exactly what
  is missing ("Unlock Lunge II and Mote Magnet II first."). Buying happens only from the card, applies
  at once, and answers with a ring, sparks, a scale pop, a chime (`sfx_skill_unlock`) and a haptic.
- Controller: up and down along a family, left and right across a tier, right of the last column
  to the card's button; Back or Pause closes it.
- Landscape: laid out from the viewport (1280x720 and a 19.5:9 phone, 1560x720, rendered).

## 8. Movement integration (ruling 12)

INTEGRATION

## 9. Qualification

QUALIFICATION
