# Open Issue #3: Organic Enemy Movement — design, decisions, results

Released as `00035-enemy-movement` (dev-000035).

Self-contained: nothing references `axolotl.gd`, `axolotl_model.gd`, Gill's follow/traction code or
the playthrough bot's traversal. Tests place the axolotl by teleport and give him no input.

## 1. Architecture before the change (file:line at d087e0d)

| Creature | Intent (AI) | Movement / avoidance | Body / visuals | Hit tests | Determinism |
|---|---|---|---|---|---|
| Parasite S/M/L (+spitter) `scripts/actors/parasite.gd` | `_physics_process` :315 state machine: graze/chase/windup/attack/recover/knocked/flung/retreat/dying/drifting. `_update_crawl` :450 (sight, notice, flank, SMALL dart phase :518, MEDIUM circle :521, graze targets :546-552), `_spitter_move` :583, `_update_retreat` :772, `_update_charge` :628 | `_move` :565: `_face(dir, dt*5)` then step along heading; ledge/wall/ravine test → **instant `heading = -heading`** :572-576; home leash :558 overrides dir; `_snap_ground` :852 (no ravine floor, never buried) | `_update_segments` :884 trail spine + distance-phased body wave; `_push_body` tube shader | `closest_body_point` :298 (segment positions), charge contact :644 | own `_rng` seeded :142; **graze used the GLOBAL randf :548-551** |
| Reed stalker `critters/reed_stalker.gd` | prowl → stalk → telegraph → pounce → recover / flee :109-177 | `_walk_to` :185 steps **straight along target direction at constant speed**; patch/rock check → new target | 6-segment trail (MultiMesh) :209; head node | `closest_body_point` :254 (trail) | critter `rng` (ecosystem.gd:41) |
| Pufferfish `critters/pufferfish.gd` | calm/puffed :202 | velocity lerp to target_v :245 (rng wander every 2-4 s, home pull, current, altitude P-control). **No wall test** | shader inflate; basis from velocity `_pose` :260 | sphere of `radius()` :280 | critter `rng` |
| Crab guardian `critters/crab_guardian.gd` | rest / warn / charge / retreat / stunned :211 | `_move_toward` :269 straight line; charge `_blocked` | `_rig` (claws/legs anim) :292 | fixed point :318 | critter `rng` (unused for motion) |
| Cave eel `critters/cave_eel.gd` | hidden / alert / strike / hold / retract / cooldown :121 | fixed mouth; `ext` along `_dir` | `_pose` :208, ripple restarted with `state_t` :223 | segment mouth→tip :253 | — |
| Parasite glob | straight projectile | — | — | — | kept rigid (readability contract) |

Ticking: parasites only on the axolotl's ball within 55 m (Game.ACTIVE_RADIUS); critters within 38 m
(Ecosystem). Everything in `_physics_process`/`tick` at fixed 60 Hz.

Tests touching movement: `_test_parasite_locomotion` (drives `_update_segments` directly; wave peak,
jitter, spacing, 30/60 fps), `_test_parasite_body_and_death`, `_test_parasite_combat` (dart speeds,
circling, heavy charge, dodge, retreat, pack alert, spacing, budget, determinism, cost),
`_test_parasite_never_buried`, `_test_ecosystem` (+crab/eel/stalker/puffer; `eco_leaves_gameplay_rng_alone`,
`eco_tick_cheap`). Bot reads `closest_body_point`, LARGE windup, crab warn/charge, eel alert,
stalker telegraph, puffer puffed.

## 2. Baseline motion (captured before any gameplay change)

`_phase_organic_trace` (scripts/tests/organic_tests.gd) steps creatures synchronously at 60 Hz for
120 s and writes top-down traces. Baseline: `ut_base/trace_base.csv`, plots `plots_base/`.
What it showed (honestly):
- Parasites grazing: textbook waypoint scribble — straight legs, sharp corners every 1.5-3.5 s,
  and 10-23 instant 180° reversals per minute (the wall/ledge flip and the home-leash snap).
  Constant speed (speed CV 0.02-0.05). `plots_base/paths_par_*.png`, `series.png`.
- Stalkers: straight lines at constant speed with sharp corners (a polygon star). `paths_stalker.png`.
- Pufferfish: kinked random walk (new wander vector every 2-4 s); acceptable but stiff.
- Crab: completely still at rest; straight line walking home.
- Eel: still head; ripple restarts at each state change.

## 3. Design

`scripts/actors/organic_motion.gd` — `OrganicMotion` (RefCounted), one per creature, global switch
`OrganicMotion.enabled`.
- Seeded from the creature's own stable seed (`Parasite._rng.seed`, `Critter.rng.seed`), read
  only; per-individual phases (20), two tempos (0.8-1.25×) and a start time (0-600 s) via
  `hash([seed, k, …])`. **No random draws anywhere.**
- Outputs (absolute functions of accumulated simulated time; weights eased by `1-exp(-3 dt)`, so
  frame-rate independent): `yaw` (heading offset: slow drift = 3 sines at 1:φ:silver with a 0.013 Hz
  amplitude "breath", plus a 2-sine weave), `speed` (2 sines at plastic ratio, minus hesitation),
  `turn` (momentum factor), `lift` (vertical / sidestep, 2 sines), `look`/`nod` (visual, 3+1 sines,
  larger while hesitating), `hes` (hesitation: two slow sines at a silver ratio thresholded with a
  smoothstep — rare, brief, never on a timer), `wander2()` (bounded 2-D drift in metres and its
  analytic derivative, for velocity-steered swimmers), `warp()` (tempo-drifting rhythm phase).
- Individual time warp: every channel runs on τ = t + D·(0.6 sin + 0.4 sin) — the creature's tempo
  wanders ±20% over about a minute, which is what stops fast rhythms from looping.
- Weights per state (caller supplies path/speed/look weights; `cut=true` zeroes path and speed at
  once for committed states; look fades in 0.1 s).
- Cost: ~2.5 µs per creature per frame (desktop), measured.

### Per-creature hooks (only INPUTS to the existing move/collision steps change)
- **Parasite** (`parasite.gd`): `_express` sets weights: graze 1/1/1; chase path 0.45 (circling 0; no hesitations while hunting),
  speed 0.5, look 0.35, all × smoothstep(1.2·reach, 2.6·reach, d) → 0 inside reach; retreat speed
  only (0.5); windup/attack/recover/knocked/flung/dying/drifting cut. Graze dir bent by `yaw`
  (straight in within ~1 m of the spot), chase/spitter dir bent after all intent/separation, speed
  scaled; `_move` turns at `5·turn` (small 0.6, medium 0.5, large 0.32, spitter 0.55); near the home
  edge (70-100% of radius) the expression fades so the leash turns it back briskly. **Grazing only**:
  a blocked step turns it away in a curve (aims ±115° and holds still until clear) instead of the
  instant reversal; a leash/target straight behind it comes round in a curve. Every other state
  keeps the original flip. Head segment rotated by `look` after `_update_segments` (rotation only:
  segment positions, hit tests and the body tube are unchanged). SMALL dart phase now
  `_org.warp(_clock, 1.7)` (tempo wanders; burst/pause speeds unchanged).
- **Stalker**: prowl 1/1/1 and "glide" (walks where its head points, head turns at 4·0.5/s: curves,
  never corners; falls back to the straight line if the curve would leave the patch or hit rock);
  stalk 0.3/0.35/0.5; flee speed 0.4; telegraph/pounce/recover cut. Head bob and scan visual only
  (trail = hit tests untouched).
- **Pufferfish**: drift via `wander2()` velocity (bounded ~1.1 m), `want_alt += lift` (±0.22 m <
  0.3), roll/pitch visual; all × (1 − inflate).
- **Crab**: rest: rig yaw ±8° (visual) and short sidesteps following a spot ≤0.22 m along the post
  (hysteresis 12 cm / 3 cm → discrete little steps); retreat: arc ≤0.3 rad fading within 1.6 m of the
  post, never into rock (`_blocked`); warn/charge/stunned cut.
- **Eel**: cosmetic only — hidden/cooldown head sway ±11°, nod, 0-5 cm peek; continuous ripple clock.
  `_dir`, `ext`, `reach`, timing untouched.
- **Glob**: untouched (rigid by contract).

### Per-species profiles (organic_motion.gd consts)
| Profile | drift rad @Hz | weave | speed ±/Hz | hesitation Hz/thr/depth | look | turn |
|---|---|---|---|---|---|---|
| Parasite small (nervous) | 0.38 @0.07 | 0.20 @0.42 | 0.24 @0.31 | 0.11/0.70/0.85 | 0.30 @0.55 | 0.6 |
| Parasite medium | 0.50 @0.045 | 0.13 @0.26 | 0.18 @0.16 | 0.06/0.76/0.8 | 0.22 @0.33 | 0.5 |
| Parasite large (heavy) | 0.58 @0.027 | 0.07 @0.15 | 0.14 @0.085 | 0.035/0.8/0.7 | 0.14 @0.19 | 0.32 |
| Spitter (watchful) | 0.42 @0.05 | 0.12 @0.30 | 0.20 @0.18 | 0.07/0.72/0.8 | 0.30 @0.28 | 0.55 |
| Stalker (slinks, stop-go) | 0.45 @0.03 | 0.10 @0.19 | 0.30 @0.075 | 0.05/0.66/0.9 | 0.20 @0.22 (+bob 3.5 cm) | 0.5 |
| Pufferfish (floats) | 0.9 m @0.028 | 0.22 m @0.10 | — | — | roll 0.07 @0.12 (+lift 0.22 m) | — |
| Crab (guards) | 0.30 @0.09 (retreat arc) | 0.08 @0.3 | 0.15 @0.2 | glance only | 0.13 @0.08 (+sidestep 0.22 m) | 1 |
| Eel (cosmetic) | — | — | — | glance only | 0.20 @0.07 (+peek 4 cm) | — |

## 4. The graze-RNG decision

Parasite grazing drew its next spot from the **global** `randf()` on a position-based arrival test.
Any change to graze paths (the whole point) changes when those draws happen and so shifts the global
sequence that the seeded playthrough bot also draws from. Gating the layer near the spot cannot keep
arrival timing (the path before it changes). **Decision: migrate graze to the parasite's own `_rng`
(parasite.gd graze branch) and re-baseline the playthroughs once.** Consequences: grazing no longer
touches the gameplay sequence at all (a strict improvement: `organic_leaves_gameplay_rng_alone`),
and the bot's seeded runs differ from before; both seeds must (and do — see results) still reach 100%.
`_init_on_ground` (one heading draw at start-up) and `_detach` (death spin) still use the global
generator exactly as before (unchanged timing).

## 5. Risk table

| Risk | Mitigation | Evidence |
|---|---|---|
| Unfair dodging / arbitrary misses | weight → 0 within reach; cut from wind-up on; strikes/pounces/charges untouched | `organic_committed_attacks_identical` (S/M/L, stalker, crab, eel bit-identical on vs off) |
| Encounter escapes / slower pursuit | chase weight ≤0.45 and fading | `organic_pursuit_still_reaches` (time on/off 1.01, 1.01, 1.00) |
| Leaving home/patch/territory, walls, ravines, burial | layer only bends the input; `_move`/`_walk_to`/`_blocked`/leash/snap unchanged; edge fade | `organic_bounded_by_the_world_5_minutes` |
| Hitbox changes | visual articulation is rotation only (parasite head segment, stalker head, crab rig, puffer basis, eel head) | locomotion + combat tests unchanged and passing |
| Determinism / bot RNG | no draws in layer; graze on own `_rng` | `organic_deterministic`, `organic_leaves_gameplay_rng_alone`, `parasite_decisions_deterministic`, `eco_leaves_gameplay_rng_alone` |
| Synchronised individuals / loops | hashed phases, tempos, start times; time warp | `organic_individuals_not_in_step`, `organic_no_short_period_repetition` |
| Frame-rate dependence | absolute functions of time, exponential easing | `organic_signal_frame_rate_independent` (0 diff), `organic_paths_frame_rate_independent` |
| Cost | ~17 sines, branches skip unused channels; load-tolerant check (ABBA-interleaved slices, medians, on/off ratios, layer cost in units of a calibration kernel, one retry; `--only=_phase_organic_cost` runs it alone) | `organic_cost_bounded` |
| Puffer has no wall test | drift is a bounded positional function (velocity = its derivative), fades when puffed | bounds test (height/home vs layer off) |


## 6. Results

### Tests (`_test_organic_motion`, 10 checks, all pass; `ut_org2.log`)
- individuals not in step: mean |pairwise corr| over 3 min: small 0.08, medium 0.14, large 0.18,
  spitter 0.12, stalker 0.17, puffer 0.25, crab 0.25, eel 0.14 (max single pair 0.36-0.77).
- no short-period repetition (worst self-match, 3 min, lags 5-60 s; a steady rhythm scores ~1.0):
  small 0.42, medium 0.57, large 0.71, spitter 0.63, stalker 0.50, puffer 0.72, crab 0.72, eel 0.51.
  (Before the time warp and third drift sine, fast channels scored 0.9+: they would have looped.)
- signal frame-rate independent: 30 vs 60 Hz outputs identical (0.0). Paths 30 vs 60 Hz over 8 s:
  medium parasite 0.021 m on vs 0.020 off; stalker 0.039 m on vs 0.017 off (under the 0.25 m bound).
- global RNG untouched; determinism: twin 20 s paths (small, large, stalker) differ by 0.0 m.
- 5 simulated minutes per type: parasites home ≤1.10 of radius (off 1.06; the 1.10 is the one
  living on a 3 m plant), never below the moss, no ravine floor, no wall crossings; stalkers 0° past
  patch, no rock; puffers height/home as without the layer; crab ≤0.18 m from post, body turn ≤14°;
  eel head ≤0.12 m from its mouth.
- committed attacks bit-identical on vs off: small 75, medium 83, large 192 frames; stalker 171; crab
  98; eel 150.
- pursuit: commits 4/4 on and off for each size; time on/off 1.01 / 1.01 / 1.00.
- cost: layer 2.3-2.5 µs/creature/frame (≈17 sines); whole-tick deltas ≈ +2..5 µs per grazing
  parasite and ≈ +4..11 µs per critter (the curved paths also meet patch edges/rocks at other
  moments, i.e. extra rays; stalker's glide). With the 55 m / 38 m activity ranges (5-12
  parasites, 2-8 critters) that is well under 0.1 ms per frame.

### Existing tests
- `_test_parasite_locomotion, _test_parasite_body_and_death, _test_parasite_combat,
  _test_parasite_never_buried, _test_ecosystem` (+crab/eel/stalker/puffer): 75/75 pass.
- Full suite (first run): 515 passed, 1 failed — `resume_points_safe` (a small parasite just
  outside the bloom pulse's 6 m knock radius, now placed differently by the re-seeded grazing, struck
  as the re-formed axolotl's grace ran out). Reproduced with the layer OFF (so caused by the RNG
  migration, not the expression); fixed in parasite.gd/game.gd (shaken out to 10 m) and re-verified.
  In that run the organic test ran last, after all parasites were cleared, so it hit script errors;
  it now runs right after the parasite combat test.
- Second full suite: 516/3 — organic pursuit (medium 1.16: hesitations while hunting, circling
  bends; phase-dependent) and cost (puffer set its basis twice), and `eco_species_in_their_habitats`
  (test artefact: the 5-minute puffer run's ground height was not restored). All three fixed in
  f6ebcda (no hesitation while hunting, no bend while circling, 8 bearings; single basis set;
  fuller snapshot).
- **Final full suite at HEAD f6ebcda: 519 passed, 0 failed** (`full3.log`), including
  `_test_organic_motion` 10/10: pursuit on/off 1.05 / 0.99 / 1.00 (8/8 commits each), layer
  2.28 µs, grazing parasite 46.5 vs 41.8 µs, critters 31.1 vs 22.9 µs (stalker 44.7/33.0, puffer
  22.0/15.7, eel 21.1/17.9) — desktop, on a machine shared with other workstreams' playthroughs.

### Playthroughs (100% required)
| run | result | all-clear | 100% at | deaths | hurts (parasite) |
|---|---|---|---|---|---|
| baseline 4242 (pre-change, pt_loco4242) | 23/23, 100% | 2987 s | 4929 s | 2 | 24 (11) |
| baseline 7 (pre-change, pt_loco7) | 23/23, 100% | 3191 s | 5052 s | 1 | 19 (1) |
| layer on 4242 (first) | 23/23, 100% | 3195 s | 5378 s | 6 | 35 (10) |
| layer on 7 (first) | 23/23, 100% | 3996 s | 5730 s | 4 | 34 (9) |
| layer OFF 4242 (RNG migration only) | 23/23, 100% | 3119 s | 4884 s | 0 | 21 (6) |
| layer OFF 7 (RNG migration only) | 23/23, 100% | 5329 s | 7478 s | 5 | 38 (19) |
| on 4242 (with pulse fix) | 23/23, 100% | 3478 s | 5323 s | 2 | 23 (4) |
| on 7 (with pulse fix) | 23/23, 100% | 3550 s | 5281 s | 6 | 37 (11) |
| **FINAL on 4242** (HEAD f6ebcda) | **23/23, 100%** | 3595 s | 5344 s | 3 | 28 (7) |
| **FINAL on 7** (HEAD f6ebcda) | **23/23, 100%** | 3113 s | 4858 s | 4 | 35 (20) |

The bot's run is chaotic: with the layer OFF, seed 7 took 7478 s and 19 parasite hits; with it on,
5281-5730 s and 9-11. Nothing in these numbers singles out the layer as making fights harder; the
spread comes from the re-seeded sequence and route order (e.g. the bot climbing the fern column
before clearing the fern parasites, which bite it while it climbs without fighting back — bot
behaviour). One OFF run (4242, first try) crashed at 60 s with an engine threading error
("propagate_notification() ... caller thread", signal 11) also seen in other workstreams'
logs (pt_X4em7, pt_skipmesa); the rerun completed.

### Visual/motion QA (primary acceptance) — what I saw
Images: `cmp_paths_par_small.png`, `cmp_paths_par_medium.png`, `cmp_paths_par_large.png`,
`cmp_paths_par_spitter.png`, `cmp_paths_stalker.png`, `cmp_paths_puffer.png` (top row BEFORE, bottom
row AFTER, 8 individuals × 120 s, colour = time), `cmp_chase.png`, `cmp_heading_speed_series.png`,
`cmp_metrics.txt`; rendered 1-fps strips `strip_base_*.jpg` vs `strip_on_*.jpg` (16 s each).
- Parasites grazing: BEFORE is a polygon scribble — straight legs, corners, instant reversals
  (10-23/min). AFTER: continuous curves, arcs and teardrop turns, no straight legs (fraction of
  1-s windows that are straight: medium 0.26 → 0.06, large 0.33 → 0.07), speed varies (CV 0.03 →
  0.2) with visible pauses, reversals medium 13 → 3/min, large 10 → 0.06/min. Large ones swing in
  broad slow arcs; small ones twitch through tighter, quicker curves. No visible sine path: the
  weave is a few cm and the drift wanders, it does not oscillate. Individuals look unrelated.
  Remaining weaknesses, honestly: grazing inside small home areas still produces a dense tangle
  with frequent loops (the intent re-targets every 1.5-3.5 s at random; loops are the curved
  version of those re-targets, not periodic); small parasites still reverse ~14/min (quick U-turns
  suit a nervous creature, but it is busy); one small parasite that lives on a 3 m plant circles
  its unreachable graze spot in both BEFORE and AFTER (pre-existing).
- Closing in (cmp_chase): approach lines gain a gentle bend far out and are straight in the last
  metres; wind-ups and lunges/charges identical. Large charges unchanged.
- Stalkers: BEFORE a star of straight lines and hard corners; AFTER long curving prowls, U-turns
  as loops, stop-and-go pauses (speed dips to ~0.1 m/s), head bob/scan. The patch-edge bounce
  cluster of one stalker (pre-existing) is reduced but still there.
- Pufferfish: similar character, smoother, slow rise/sink; puffed it holds still as before. One
  puffer is carried ~100° round the ball by a strong current with or without the layer
  (pre-existing: its home pull is weaker than the flow) — worth a separate look.
- Crab: rest now shows a slow body turn and occasional small sidesteps (visible between strip
  frames); warn/charge identical. Eel: slow head sway in the cleft (subtle at 1 fps).
- Renders: the top-down 1-fps strips are small and mostly confirm heading changes (the medium
  parasite visibly curves over 16 s instead of travelling straight then snapping); the path traces
  are the better evidence. No clipping, burial or jitter seen in either.
