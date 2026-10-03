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
| 1 | Terrain / threat | Ball 1's rim fights happen on the edge of lethal ooze | High (first ball) | Proposal P1 |
| 2 | Readability / progression | Nothing in play says how restored the current ball is or how near its tunnel is | High | Partly fixed (whole-ball view caption); proposal P2 |
| 3 | Readability | Arrivals on balls 4-7 show bare, dark ground with no landmark or lead | Medium | Proposal P3 |
| 4 | Pacing | Ball 3's last 3% sits on the 17 m canopy top; falls cost fronds and the bot loops there | Medium | Proposal P4 |
| 5 | Readability | Small parasites at 7-10 m are a few pinkish pixels, close to Gill's own colour | Medium | Proposal P5 (look stream) |
| 6 | UI | Treasure Hunt box text at 15 / 17 px (about 1.4 / 1.6 mm on a phone) | Low-medium | **Fixed** |
| 7 | UI | A starfish picked up during a Treasure Hunt drew its chip over the hunt box | Low | **Fixed** |
| 7b | Pacing / readability | Cave eels: all 5 left at every normal finish; most bot stuck time is in their grottos | Medium | Proposal P7 |
| 8 | Ecosystem | Creature threats are uneven: Reed Canyon has five kinds, Canopy Spire and Giant Stems almost none | Low | Proposal P6 |
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
the look stream's; listed so it is not lost.

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

## Proposals (not implemented: larger than a bounded local fix, or another stream's)

- **P1. Ooze edge on Ball 1's rim.** Either (a) move the three Great Ravine rim parasites' homes so
  their areas stop 2 m short of the rim (lat 57 → about 54-55 with the same 4 m radius; ids are not
  fixed, but the world hash and starfish/treasure clearances must be re-run), or (b) an edge assist: a
  lunge or swipe-turn that would carry him over a ravine rim stops at the rim (the player still falls
  if he walks in). (b) is gentler and covers every ball; (a) is smaller. Owner to choose.
- **P2. This ball's progress in the pause menu.** Replace "Moss restored N / 262" (run-wide) with
  "Mossy Meadow 42% · tunnel at 70%" in the run detail table (same line count, so the no-scroll fit
  is unchanged), keeping the run-wide counts in the completion lines.
- **P3. A lead on arrival.** On the first arrival at a ball, play the whole-ball view for about 3 s
  (the same shot as the tutorial reveal, now `BallView.shot`), or pre-arm the 90 s shimmer hint to
  start at once on arrival. Either uses existing pieces.
- **P4. Ball 3 canopy top.** Let the canopy parasites leave their leaves to chase him down the spiral
  (as ground parasites do), or move the last Mote and parasite one leaf lower (about 12 m), so the
  last 3% is not the tallest climb on the ball.
- **P5. Parasite read at distance** (look stream): a hue or value step away from Gill's pink in the
  murky state, or a faint rim/eye glow that reads at 10 m.
- **P7. Cave eels read and reach.** A faint glow or bubble trail from the eel's cleft once he is in its
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
