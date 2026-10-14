# Whole-game cohesion audit (E6h), 2026-10-02

Scope: progression and pacing across the seven balls, readability (where to go, what is a threat,
what is collectable), ecosystem coherence, terrain and collision, and player-facing UI on a
landscape phone held with two thumbs. Runtime performance, startup and materials/look belong to
other streams and are only noted where they touch readability.

Evidence used (Rule 7: the minimum that settles each point):
- Five earlier bot playthroughs to 100% (`e_pt`, `l_pt`, `c_pt`, `t_pt`, `d_pt3`, all 24/24) and one
  new one on this branch with stuck-spot logging added to the bot (`audit_pt1`, see §T1).
- A new read-only probe, `_phase_cohesion_probe` (run by name: `--test=unit --only=_phase_cohesion_probe`):
  for each ball, parasites whose home area takes in ravine floor, and collectables within 2 m of it.
- Screenshots through the ordinary follow camera with the touch HUD: the arrival on every ball, two
  headings each (`--test=shots --only=cohesion`; sheets `arrivals_b1-b4.jpg`, `arrivals_b5-b7.jpg`),
  threat vs collectable at play distance (`--only=cohesion2`), and the new whole-ball view
  (`--only=ballview`; `ballview_ball5.jpg`, `pause_menu_whole_ball.jpg`).
- The existing tests and docs (ledger rows 17, 20, 25, 26, 32; `docs/ECOSYSTEM.md`, `docs/SKILL_TREE.md`).

Bot evidence is a floor, not a forecast: the bot is a careful but literal player. Where a finding
rests on the bot, the human-facing reason is stated and the size is hedged.

## Findings, ranked by player impact

| # | Area | Finding | Impact | Status |
|---|---|---|---|---|
| 1 | Terrain / threat | Ball 1's rim fights happen on the edge of lethal ooze | High (first ball) | **Fixed** (P1, 2026-10-04) |
| 2 | Readability / progression | Nothing in play says how restored the current ball is or how near its tunnel is | High | **Fixed** (whole-ball view caption; P2 built 2026-10-04: pause menu line) |
| 3 | Readability | Arrivals on balls 4-7 show bare, dark ground with no landmark or lead | Medium | **P3 built** 2026-10-04 (first-arrival whole-ball view); the murk itself stays the look stream's |
| 4 | Pacing | Ball 3's last 3% sits on the 17 m canopy top; falls cost fronds and the bot loops there | Medium | **Fixed** (P4, 2026-10-04) |
| 5 | Readability | Small parasites at 7-10 m are a few pinkish pixels, close to Gill's own colour | Medium | **Fixed** (P5, 2026-10-04) |
| 6 | UI | Treasure Hunt box text at 15 / 17 px (about 1.4 / 1.6 mm on a phone) | Low-medium | **Fixed** |
| 7 | UI | A starfish picked up during a Treasure Hunt drew its chip over the hunt box | Low | **Fixed** |
| 7b | Pacing / readability | Cave eels: all 5 left at every normal finish; most bot stuck time is in their grottos | Medium | **Fixed** (P7, 2026-10-04) |
| 8 | Ecosystem | Creature threats are uneven: Reed Canyon has five kinds, Canopy Spire and Giant Stems almost none | Low | **Fixed** (P6, 2026-10-04) |
| 9 | Docs | The ravine-fall comment and WORLD_EXPANSION.md still described "one frond, back on the rim" | Low (maintainers) | **Fixed** |
| 10 | UI | Pause button 56 px (about 5.3 mm; 7.2 mm with its touch margin), under Android's 48 dp | Low | Note; deliberate (no accidental pauses) |

What held up well (no action): the camera invariant (0 unsafe frames in 210,526 audited in a whole
playthrough), every ball reached and restored by play in all six runs, 100% reachable by play, the
skill tree's 30-star budget matching the 30 starfish exactly, HUD action buttons (r 54-64 px, 10-12 mm),
the pause menu fitting landscape at its fullest with no scroll (now with the new "Whole ball" button),
and restoration hints (90 s shimmer, 180 s guide, 300 s count).

### 1. Ball 1's rim fights sit on the edge of lethal ooze (High)

Every ooze fall is a death (owner ruling, ledger row 32). On Ball 1 (Mossy Meadow, the first ball
after the tutorial) the bot dies 16-24 times per run; on every other ball 0-6. Of the 31 deaths in
`e_pt`, 26 were ravine falls, almost all on Ball 1 during "kill rim" and "route" (the Great Ravine
rims and the stepping stones). The probe says why: all three Great Ravine rim parasites, and one at
the Split Crack, have ravine floor inside their home area (16%, 13%, 5% and 12% of it). No other ball
has more than one such parasite (each 2-5%). A fight there is a lunge or a swipe-turn at the very edge,
and a lunge carries him forward. For a human the ravine is visible, so the rate will be far lower than
the bot's, but it is the first place a new player fights near a hazard, on the ball they meet first.

Collectables are mostly fine: 2 of 34 motes (one is the stepping-stone mote, placed over the ravine on
purpose), 3 of 21 food and 1 of 6 starfish on Ball 1 lie within 2 m of ooze; every other ball has 0-1.

### 2. No in-play readout of the current ball's restoration (High)

A tunnel opens when its ball is 70% restored (`Vortex.CONNECT_AT`), and that is the main goal on each
ball. The HUD is minimal by design and the pause menu shows run-wide catalog counts ("Moss restored
0 / 262"), not the current ball's percentage, so a player cannot tell whether they are at 40% or 68%.
**Fixed in part:** the whole-ball view's caption (ledger row 21, built in this stream) reads
"Mossy Meadow · 42% restored · a water tunnel opens at 70%" (the last part only while a tunnel out of
the ball is still shut). Proposal P2 covers the pause menu.

### 3. Bare arrivals on balls 4-7 (Medium)

Through the ordinary camera at each arrival point (`arrivals_b5-b7.jpg`, and the bottom row of
`arrivals_b1-b4.jpg`), balls 4-7 open on dark, near-empty curved ground: no landmark, no lead toward a
first parasite or Mote. Balls 1-3 show a mound, plants or stems to walk toward. The restoration hints
only start after 90 s of searching. The murk itself is the look stream's; the missing lead is not.

### 4. Ball 3's canopy top (Medium)

The last 3% of Giant Stems is a Mote and two parasites on the leaves at the top of the giant spiral,
17-18 m up. In `audit_pt1` the bot reached 97% at 2,424 s and was still looping there 700 s later: it
climbs, reaches the top, falls (each fall a hard landing costing a frond, "hurt ... nearest threat
none" about 10 s after "top of spiral"), and waits at the stem's foot for the parasite to come down
(it never leaves its leaf: "fight timed out: canopy ... 17.6 m up"). Earlier runs show the same wait
(`e_pt` 1440-1560 s at the same spot). For a human the climb is fair, but a 97% that will not finish
reads as a bug, and the parasite never comes to him.

### 5. Small parasites read like Gill at distance (Medium; look stream)

At 7-10 m in the murky (unrestored) water a small parasite is a few pinkish pixels, close in hue to
Gill himself (pink) and to food glows; the threat reads only once it moves. Materials and colour are
the look stream's; listed so it is not lost. **Fixed (P5, 2026-10-04)**: see "P5 and P7, done" below.

### 6. Treasure Hunt box text too small (Low-medium) — fixed

The hunt's small box (top left, in play) used 15 px for "TREASURE HUNT" and 17 px for the count. On a
720-design-px-tall landscape phone a design pixel is about 0.094 mm, so that is 1.4 / 1.6 mm, below
Android's 12 sp floor (about 1.9 mm). Now 18 and 20 px (`hud_hunt_box_text_legible`). The pause
menu's startup line and the diagnostics page (17 px) are informational, not play, and were left.

### 7. Starfish chip over the Treasure Hunt box (Low) — fixed

The starfish chip and the hunt box both sat at the safe area's top left + (6, 40). Starfish are
permanent progress, not part of the run's 100%, so one can still be picked up mid-hunt; its chip drew
over the box for 3.6 s. Now it shows just below the box while a hunt shows
(`hud_starfish_chip_clear_of_hunt_box`).

### 8. Uneven creature threats (Low)

From `docs/ECOSYSTEM.md`: Reed Canyon has stalkers ×2, a crab, an eel, a puffer and a spitter; Giant
Stems one stalker; Canopy Spire only ambient creatures (snails, hoppers, shrimp). Probably intended
(Canopy Spire is the vertical ball), but Reed Canyon is a spike: `d_pt3` had 6 deaths there.

### 9. Stale ravine-fall wording (Low) — fixed

`Axolotl` said a ravine floor costs "one frond, and he is put back at its edge", and
`docs/WORLD_EXPANSION.md` twice described the old rule. Both now point to ledger row 32.

### 10. Pause button size (note)

56 × 56 design px (about 5.3 mm; 76 px with its 10 px touch margin, about 7.2 mm) at the top right.
Under the 48 dp guideline (about 7.6 mm) but well clear of the right thumb's buttons, which is the
point. No change proposed.

## Terrain and collision

The existing gates already cover holes and floating pieces (`_test_terrain_grounded`,
`_test_no_floating_platforms`, `_test_route_audit`, `_test_view_clearances`) and all pass. Invisible
walls were not probed directly; the bot's stuck spots are the nearest evidence.

### T1. Where the bot gets stuck (`audit_pt1`, 24/24, 100% by play)

The bot now logs each stuck recovery's place (ball, lat/lon to 2°) and each fallback's place and
activity. Top spots (recoveries): Reed Canyon (24, -50) ×89, Hollow Grotto (-8, 158-160) ×65,
Current Hollows mesa (10..20, -14..-24) ×84 in all, Hollow Grotto (40, 12) ×45, Current Hollows
north-cap cave (72, 94-96) ×27. By activity:

- **Eel grottos (most of it).** Every top spot except the mesa is a cave eel's grotto, during the
  completionist phase ("100%: b5.eel.0", "b7.eel.0/1"). The eel sits in a cleft on the side away from
  the ledges and its front is often "blocked" from where he stands; the bot pushes into the grotto wall
  between strikes. All 5 eels were still undefeated at the normal finish in all six runs, and the eel
  phase was most of the 4,550 s between the normal finish and 100% here. For a human this is the
  "which wall is it in, and how do I hit it" question: a **readability/pacing finding (Medium)**,
  proposal P7.
- **The Mesa on Current Hollows (Low-medium).** 15 goto timeouts at its foot ("mesa", "on mesa top:
  false"): the living platforms up the mesa are hard to mount from the side the bot approaches; it got
  up in the end on every run. Worth a look in play, not a collision defect on this evidence.
- **Ball 1 rims** (74, 0) "kill rim": finding 1 again.
- **Ball 3 canopy foot** (20..30, -28..-36): finding 4 again.

No stuck spot points to a hole or an invisible wall in open ground.

Pacing note: this run's normal finish was 4,691 s against 3,233-3,699 s in the five earlier runs; the
difference is the Ball 3 canopy loop (finding 4), about 700 s.

## P2 and P3, built (owner-approved, 2026-10-04)

**P2. This ball's progress in the pause menu.** The run panel's detail opens with one line for the
ball he is on, above the run-wide table (whose counts, "Moss restored N / 262" and the rest, are kept):

| State | Line |
|---|---|
| below 70%, one tunnel out | `Terrace Steps  ·  42% restored  ·  tunnel opens at 70%` |
| 70% or more (or the tunnel already open) | `Terrace Steps  ·  74% restored  ·  tunnel open` |
| two tunnels out (Mossy Meadow, Current Hollows) | `…  ·  tunnels open at 70%` / `…  ·  tunnels open` |
| no tunnel out (Reed Canyon, Canopy Spire, Hollow Grotto) | `Reed Canyon  ·  42% restored` |

The % is the ball's restoration rounded down (as everywhere), so 100% shows only when the ball is
fully restored; the line never says "complete" or "done": 70% only opens the way on, and finishing
still needs every ball at 100%. "Open" uses the game's own rule (`Vortex.CONNECT_AT`, the same
epsilon as `Game._check_vortex_connections`), or a tunnel the save already has open. Not shown from
the title's Settings or in the aquarium experiences (no ball is being played); nothing is added to
the play HUD. To keep the menu at its fullest inside 720 px with nothing to scroll, the right
column's spacing went from 12 to 10 px: the fullest panel is 687 px tall (was 677; limit 696).
Code: `BallView.progress_line`, `PauseMenu.ball_line`. Tests: `_test_pause_ball_progress`
(`pause_ball_line_*`, `pause_menu_shows_this_ball`), and `_test_menus_no_scroll` unchanged.

**P3. First-arrival establishing view.** The first time in a run that a tunnel lands him on a ball,
the whole-ball view (`BallView`, the tutorial reveal's shot) opens by itself as the landing ends:
it eases out from the landing camera (0.8 s), holds the slowly circling shot with the caption (ball,
% restored, "a water tunnel opens at 70%" while one out is shut, "Tap anywhere to skip"), and after
2.2 s blends back to the follow camera behind him (0.8 s): about 3 s in all (measured 3.03 s).
Any touch, click, key or button after the first 0.35 s skips it; Android back closes it too. The
run is held exactly as for the on-demand view (tree paused: no damage, no threats, no current, no
clock), the HUD's held stick/buttons are let go, and control comes back exactly where the landing
left it. The camera safety invariant runs throughout.

Rules:
- Once per ball per run. The ball counts as seen the moment he lands, whatever happens next (the
  view skipped, or not possible), and the landing's save writes it at once, so it never plays again
  after a death, a reload, an app restart, an OTA restart or a later trip back. A New Run starts a
  fresh set (like the tutorial reveal, which is per run too).
- Never on Ball 1: its establishing view is the tutorial's reveal (no double play). Never during a
  Treasure Hunt (postgame). A view that cannot open within 1.5 s of play (a lesson card or tunnel
  shot took the moment, the pause menu, the aquarium) is dropped, never shown late.
- Only a tunnel landing is an arrival: Continue, respawns and the title never play it, so startup,
  the update check, the studio splash and the title are untouched.
- Saved as `run.world.balls_seen` (sorted ball tags, "b2"...). The run save format is unchanged;
  an older save simply lacks the key.
- **Older saves** (no `balls_seen`): worked out from where the run shows he has been, erring towards
  "seen": Ball 1, the ball the run is on, the last tunnel arrival, every ball with anything earned on
  it (completion ids "bN.…"), and both ends of each tunnel ride in its stats. A ride is stored only by
  its "from" ball, so for Mossy Meadow and Current Hollows (two tunnels out each) both far ends count;
  a branch ball never actually visited may then miss its view, which is the safe side. A brand-new run
  has seen nothing. (`Game.seen_from_save`.)
- Off in automated unit / shots / perf runs (`Game.arrival_views`; their tests travel freely and expect
  control straight back); on in play and in the playthrough bot; `_test_arrival_view` turns it on.

Code: `Game._arrived`, `Game._update_arrival_view`, `Game.seen_from_save`, `BallView.open(auto)`.
Tests: `_test_arrival_view` (`arrival_*`: plays on the first arrival, about 3 s, run held, smooth
camera, control restored and he walks off at once; not on Ball 1, not a second time, not after a
death or a reload; skipped by a touch; saved round trip; old-save migration, pure and live; dropped
outside play; camera never drawn unsafe). Shots: `--test=shots --only=ballprogress`
(`docs/screenshots/ballprogress_pause_b4_42.jpg`, `ballprogress_pause_b2_74.jpg`, `ballprogress_arrival_b2.jpg`, `ballprogress_arrival_back.jpg`; the pause shots set the ball's % for the picture, so the run-wide counts below read 0).

## Proposals (not implemented: larger than a bounded local fix, or another stream's)

(P1, P4 and P6 were approved by the owner and implemented on 2026-10-04: see "Remediation" at the end.)

- **P1. Ooze edge on Ball 1's rim.** Either (a) move the three Great Ravine rim parasites' homes so
  their areas stop 2 m short of the rim (lat 57 → about 54-55 with the same 4 m radius; ids are not
  fixed, but the world hash and starfish/treasure clearances must be re-run), or (b) an edge assist: a
  lunge or swipe-turn that would carry him over a ravine rim stops at the rim (the player still falls
  if he walks in). (b) is gentler and covers every ball; (a) is smaller. Owner to choose.
- **P2 (built 2026-10-04, above). This ball's progress in the pause menu.** Replace "Moss restored N / 262" (run-wide) with
  "Mossy Meadow 42% · tunnel at 70%" in the run detail table (same line count, so the no-scroll fit
  is unchanged), keeping the run-wide counts in the completion lines.
- **P3 (built 2026-10-04, above: the whole-ball view option). A lead on arrival.** On the first arrival at a ball, play the whole-ball view for about 3 s
  (the same shot as the tutorial reveal, now `BallView.shot`), or pre-arm the 90 s shimmer hint to
  start at once on arrival. Either uses existing pieces.
- **P4. Ball 3 canopy top.** Let the canopy parasites leave their leaves to chase him down the spiral
  (as ground parasites do), or move the last Mote and parasite one leaf lower (about 12 m), so the
  last 3% is not the tallest climb on the ball.
- **P5. Parasite read at distance** (look stream): a hue or value step away from Gill's pink in the
  murky state, or a faint rim/eye glow that reads at 10 m. **Done** (below).
- **P7. Cave eels read and reach.** **Done** (below; eels stay in the catalog). A faint glow or bubble trail from the eel's cleft once he is in its
  grotto (it already has glowing eyes when alert), and keep its strike line clear of the grotto's
  ledges so a hit is always possible from a ledge he can stand on; or drop eels from the completion
  catalog's "wildlife" and keep them as optional fights (owner's call, catalog appends only).
- **P6. Threat spread.** Move one Reed Canyon threat (the second stalker or the puffer) to Giant Stems'
  jungle floor.

## Fixed in this stream (with tests)

| Change | Files | Test |
|---|---|---|
| Whole-ball view on demand (ledger row 21) | `scripts/core/ball_view.gd`, `game.gd`, `pause_menu.gd`, `settings.gd` | `_test_ball_view` (7 balls), `ball_view_*` |
| Whole-ball view caption: % restored and the tunnel threshold | `ball_view.gd` | `ball_view_caption` |
| Treasure Hunt box text 15/17 → 18/20 px | `scripts/ui/treasure_panel.gd` | `hud_hunt_box_text_legible` |
| Starfish chip below the hunt box during a hunt | `scripts/ui/hud.gd`, `treasure_panel.gd` | `hud_starfish_chip_clear_of_hunt_box` |
| Ravine-fall wording | `scripts/actors/axolotl.gd`, `docs/WORLD_EXPANSION.md` | (docs) |
| Bot logs where it gets stuck; probe; audit shots | `playthrough_bot.gd`, `unit_tests.gd`, `shots.gd` | (tooling) |

## Remediation 2026-10-04: P1, P4, P6 (owner-approved)

| Proposal | Change | Files | Tests |
|---|---|---|---|
| P1 (a) | Ball 1's three Great Ravine rim parasites (57/-40, 57/35, 68/45 → 51.8/-40, 51.8/35, 72.3/40) and two Split Crack parasites (69/-95, 59/-126 → 69/-80.5, 59/-129) moved back; same 4° areas, order and kinds, so the same ids. Every area now stops 2.1-2.4 m short of the cut (the top of the ravine wall) | `scripts/world/levels.gd` | `rim_fights_clear_of_ooze`, `ball1_no_parasite_home_on_ooze` |
| P1 (b) | Edge assist (`Axolotl._edge_stop`): a lunge or tail swipe made on the ground, or a hit's knock-back, stops at a ravine's rim; walking, running, jumping, bursting and gliding are untouched (walking or jumping in is still a death), and a lunge along a bridge, log or stepping stone goes on (footing under it). Bounded: read only during those moves, near a ravine | `scripts/actors/axolotl.gd` | `edge_lunge_stops_at_rim`, `edge_knockback_held_at_rim`, `edge_walking_in_still_falls`, `edge_jumping_in_untouched`, `edge_lunge_along_bridge_unchanged` |
| P4 | Ball 3's canopy medium parasite and the Mote it guards moved from C2 (17.3 m, across two stems from the spiral's top) to the giant spiral's 13th leaf (12.8 m, `Levels.CANOPY_GUARD_LEAF`); same ids (`b3.canopy.parasite.0`, `b3.canopy.mote.0`). C2 is still the extreme drop's leaf. The parasite still never leaves its leaf on its own; it is now on the climb itself, so it fights him there (it hit the bot on both runs) | `levels.gd`, bot `canopy()` | `canopy_guard_on_spiral_leaf`, `canopy_guard_reached_and_beaten_by_play` (plain jumps up 13 leaves, beaten by swipes on the leaf), `canopy_guard_mote_taken_from_leaf`; existing `canopy_*`, `climbs_with_plain_jumps`, route audit |
| P6 | Reed Canyon's second canyon stalker now hunts Giant Stems' western jungle floor (-20, -75). Stalkers carry no completion id and are never saved, so no id or save changes (catalog hash unchanged); Reed Canyon's crab keeps its seed. Details in `docs/ECOSYSTEM.md` "Threat spread" | `scripts/world/ecosystem.gd` | `threat_spread_stalker_on_giant_stems`, `eco_*` |

Also: the bot logs each death with its ball, place and cause (`DEATH n at t: ball N (lat, lon), ooze|hurt (activity; nearest threat)`).

**Evidence.** Playthrough bot, default seed, same machine and day; "before" is the base of this branch
(`f5720c6` plus the death logging only), "after" is this change. Deaths per ball:

| Run | Ball 1 | 2 | 3 | 4 | 5 | 6 | 7 | Total | Ball 3 clear (s) | ALL CLEAR (s) | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|
| before (`before_pt1`) | **25** (all ooze; 23 during "kill rim") | 0 | 2 | 0 | 2 | 0 | 2 | 31 | 611 | 3,743 | 100% phase crashed in the engine (signal 11, a worker-thread notification; also seen in other runs under load) |
| after 1 | **7** (6 ooze; 1 "kill rim") | 2 | 0 | 1 | 0 | 0 | 0 | 10 | 408 | 3,234 | 24/24, 100% by play |
| after 2 | **5** (all ooze; 0 "kill rim") | 0 | 0 | 3 | 1 | 0 | 1 | 10 | 381 | 3,080 | 24/24, 100% by play |

Earlier runs on older builds (deaths attributed by heartbeat, so approximate): Ball 1 16-24, Ball 3
clearing 554-927 s (`audit_pt1`: 653 s to 97%, then two more visits).

- Before, 23 of Ball 1's 25 deaths came in "kill rim" loops: walking to a rim parasite grazing at the
  lip, the bot went round the Great Ravine's west end and the Split Crack's south end and fell in,
  re-formed at the start and tried again (9 at (62, -64) alone). With the areas back from the cut the
  target is inland and the loop is gone (1 and 0). What is left on Ball 1 is the skilled climbs the bot
  walks: the Split Crack's stone bridge (3 + 1 per run) and the stepping stones (1 per run).
- Home-area ooze floor (deterministic rings-and-spokes sampling, `[RIM]` log; the cohesion probe
  agrees): Ball 1 before 4 parasites (16%, 13%, 5%, 12%), after 0 of 30. Other balls unchanged and not
  in scope: Terrace Steps field 2%, Reed Canyon far 4%, Hollow Grotto undercut 4% (each 2-5% before).
- Knock-back, measured: a hit throws him about 0.8 m; from 0.1 m or more short of the lip he never
  reaches the ooze even without the assist, and with it he is held on the lip itself. A parasite's reach
  is 1.5-1.8 m and its area stops 2.1 m or more short of the cut, so where a rim parasite can hit him he
  is clear of the lip: no enemy can push him into a death loop there.
- Ball 3: the canopy routine finished in one pass on both runs (about 100 s from the foot of the spiral
  to the drop; the guard parasite hit him once in run 2 and knocked him a leaf down once), and the ball
  was 100% on the first visit both times (408 / 381 s against 611 s before and 554-927 s earlier).
- World hash: geometry hash changes (moved parasites, Mote and stalker); completion catalog hash
  (`9bf9a8d5…`, 348 ids) and starfish placement hash (`4d2b6438…`, 30 stars) identical before and after.

## P5 and P7, done (owner-approved, 2026-10-04)

### P5. Small parasites read apart from Gill at 7-10 m

- **Value step.** The small parasite's body went from a bright pink-to-orange (0.95, 0.2, 0.62) →
  (1.0, 0.62, 0.12) to a dark wine-magenta-to-burgundy (0.55, 0.05, 0.3) → (0.4, 0.05, 0.12):
  luminance 0.17 / 0.13 against Gill's 0.72, and no longer the food's peach. Its green markings,
  shape, size, motion and the medium and large palettes are unchanged.
- **Eye glow.** Every parasite's eyes now glow faintly sulphur yellow (1.0, 0.85, 0.3; energy 1.6),
  the threat colour of the eel's eyes, about 60° in hue from Gill's pink (his eyes are dark). They
  flare in the wind-up (up to 4.0) and go out as the parasite is drained (the death drift is grey).
- **Rejected: a fresnel rim.** Tried first (shader rim in the same yellow): on a body this thin,
  most of what shows at 10 m is grazing surface, so even a faint rim turned the whole parasite into
  a yellow-gold blob that read like a collectable. Removed.
- **Cost.** No new nodes, lights or draw calls (the eyes existed; their material now emits). Same
  draw calls and primitives in all three frames (399 / 359 / 361).
- **Evidence.** `--test=shots --only=p5read` (new): Ball 1 unrestored, ordinary camera, Gill in
  frame, a small parasite 7, 8.5 and 10 m ahead (11-14 m from the camera) and a food beside it.
  `p5_parasite_7-10m.jpg`: full frame at 8.5 m, then ×3 crops, before | after. Before, a pink smear
  of Gill's colour; after, a dark body with two bright yellow points. Measured on those frames: the
  parasite's body pixels sit 0.23-0.33 below Gill's in HSL lightness (before 0.20-0.25), and its
  brightest pixel is the eyes' yellow at lightness 0.73-0.78 (before the green marking at 0.54-0.63).
  The parasite is 60-110 pixels at 1280×720, so per-pixel hue on the body is mostly the murk's.
- **Tests** (`_test_parasite_readability`): `parasite_small_darker_than_gill`,
  `parasite_small_not_food_coloured`, `parasite_eyes_glow_away_from_gill_and_food`,
  `parasite_eyes_flare_in_windup_out_when_drained`, `parasite_eye_materials_own`.

### P7. Cave eels read and reach

Measured first (`_test_eel_reach` run on the old code): from the spot straight out in front of the
crevice (where a player, and the bot, would stand), 3 of the 5 eels could not be hit. From there
`b5.eel.0` and `b7.eel.1` never saw him at all (the grotto's tallest ledge, a pillar on the eel's
side, stands between the crevice and the floor), so they never came out; for `b7.eel.0` the spot
was not clear floor that can be walked to from the door. Every eel did have some spot it could be hit from (86-135 in a fan of candidates), which
the old bot found only by chance.

- **Placement.** On the first physics frame each eel now tries its given wall position, then up to
  8 steps of 8° either way round the grotto (never within 55° of the door), and settles on the
  first where: the floor straight out in front (2.8-3.3 m) is standable with room round him and
  walkable from the door; it sees him there; its whole 2.3 m strike line is clear of rock and the
  ledges; its head fully out is inside his swipe without touching him; and it cannot see him on any
  of the climb's ledges (so it still never knocks him off the optional climb). That spot is
  `CaveEel.stand`. Result: four eels moved 8°, `b7.eel.2` stayed. Ids, hit points, timings, reach
  and the "never through rock" rules are unchanged.
- **Read.** Once he is in its grotto, the cleft's lip (a thin ring flat on the rock) glows faintly
  in the eyes' colour with a slow breath, and a couple of small bubbles rise from it every ~2.4 s
  while it hides. Dark when he is away or it is beaten. One small mesh per eel, no light; no random
  draws (cosmetic only). `p7_eel_clefts.jpg`: three grottos from a step behind the stand spot,
  before | after (before, a ledge pillar fills the view in front of `b2.eel.0` and `b5.eel.0`).
- **Bot.** The 100% eel tactic goes to `CaveEel.stand` (was: straight out at 2.75 m, unchecked),
  and travels back to the eel's ball first after being knocked out (it used to spend the remaining
  rounds on another ball).
- **Tests** (`_test_eel_reach`): `eel_hittable_from_standable_spot`, `eel_stand_spot_strikes_clear`,
  `eel_never_sees_him_on_its_ledges`, `eel_swipe_lands_from_its_spot` (live, through the real swipe
  input: all 5), `eel_cleft_glows_when_he_is_in_its_grotto`, `eel_cleft_dark_when_he_is_away`.

Playthrough (`--test=playthrough`, 24/24 both, 100% by play both), before → after:

| | before | after |
|---|---|---|
| Eel phase of the 100% run (heartbeats on "100%: bN.eel.M") | 860 s | 300 s |
| Rounds to beat the 5 eels (2 is the minimum each) | 15 | 10 |
| Hurt near an eel / knocked out by one | 2 / 1 | 0 / 0 |
| Stuck recoveries in eel grottos (of all) | 137 of 187 | 0 of 123 |
| `--start=eels` scenario (each eel from outside its grotto, fresh world) | 3 of 5 beaten, 40 rounds | 4 of 5, 8 rounds + `b7.eel.2` |

(`b7.eel.2` fails the debug scenario before and after alike: on a fresh world its grotto's chamber
gate is still shut; in the playthrough it is beaten in 2 rounds both times.) The 5 eels are still
left at the normal finish: the bot's main route does not fight optional eels; they are the 100%
phase's. The normal finish itself (3221 s before, 4315 s after, 31 / 58 knock-outs) is the bot's
run-to-run spread: the base code diverges from itself at the same place, Ball 1's ravine rim at
about 225 s (finding 1), with none of the extra knock-outs near an eel.

| Change | Files | Test |
|---|---|---|
| P5: small parasite palette, glowing eyes | `scripts/actors/parasite.gd` | `_test_parasite_readability` |
| P7: eel placement and stand spot, cleft cue, bubbles | `scripts/actors/critters/cave_eel.gd`, `scripts/world/ecosystem.gd`, `scripts/world/water_fx.gd` | `_test_eel_reach` |
| Bot uses the stand spot; returns to the eel's ball | `scripts/tests/playthrough_bot.gd` | playthrough |
| Shots `p5read`, `p7eel` | `scripts/tests/shots.gd` | (tooling) |
