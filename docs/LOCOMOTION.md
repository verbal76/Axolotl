# Mote Open Issue #1 — Gill fluid body locomotion and terrain traversal

Architecture investigation, design, and risk register.
Base: `claude/mote-game-continuation-bov2x9` @ `77c776b`. Work branch: `mote-issue1-locomotion`.

## 1. Current state (base 77c776b), verified

### Controller — `scripts/actors/axolotl.gd`
- A single sphere collider, r 0.3, centred 0.3 above the node origin (L94–99). `floor_max_angle` 52°
  (L89), `floor_snap_length` 0.35 (L90), `floor_block_on_wall = false` (L92). There is no step-up.
  A sharp step blocks him as a wall once it is over about 0.115 m: a sphere of r 0.3 touching the
  step's edge has a contact normal steeper than 52°.
- Orientation is radial only: `_apply_orientation` (L636–639) builds the basis from `facing` and the
  ball's radial `up`. It never uses the floor normal, so the whole model stays level on slopes.
- The head guard `_guard_head` (L149–188): a 0.17 m sphere at `head_center()` (0.4 ahead, 0.28 up).
  After every `move_and_slide` it pushes the whole body back out of any contact whose normal·up is
  ≤ cos 52°. Because of this, a lip higher than about 0.11 m stops him about 0.57 m short of its
  face.
- Facing turns toward the stick at 14 rad/s on the ground and 7 rad/s in the air (L241–245). From a
  standstill he turns on the spot before he sets off (L254–263). The model is rigid: the whole body
  turns at once.
- `place()` (L116–130) is the one entry point for respawns, checkpoints, vortex arrivals and
  ravine returns. `game.gd` L1146 drives him directly during the vortex ride.

### Model — `scripts/actors/axolotl_model.gd`
- A Skeleton3D `Spine` with 11 bones at `BONE_Z` [-0.2 … 0.91] (L22), chained head → tail. The skin
  is a 46-ring mesh weighted to pairs of neighbouring bones. Bone 0 carries the head
  (BoneAttachment) and was never posed. The legs hang off bones 1 and 4.
- The spine loop (L1070–1101) sets a relative (pitch, yaw) per bone from: the travelling S-wave, the
  whip, `tail_base` (the swim turn), `arch`, and the idle spine offsets. Everything is relative to a
  straight body along the model's −Z.
- In the air the whole rig tips with `vup` (`rig_rot.x`, L936). In the water the swimmer's node
  basis carries the pitch, and `swim_turn` only adds roll and a static tail offset (L940–951).
- `_animate` runs in `_process`. `whip_tip_az` (the swipe arc's head) is walked down the chain.
  `wake.gd` reads bone origins 0/3/6/8/10.

### Why he "faces into mossy slopes and gets stuck" (evidence)
- Terrain survey (analytic ground, 1.5° grid, all 7 balls): the only terrain over 52° is ravine
  walls (about 3 m faces, up to 77°). Hills and plateaus are all walkable. So the mossy steep faces
  he meets are mesh bodies: mound flares and sides (the flare's lowest ~0.2 m is under 52°, then
  75°), formations and props. The moss shader (`moss_slope` 0.5) draws moss well past 52°, so these
  faces read as walkable.
- Random-push probe (311 pushes from random open ground on all balls, random headings, 1.8 s each):
  only 2 pushes were blocked, and both were short lips (0.37 m and 0.16 m). Short lips were the one
  real traversal failure.
- Synthetic-geometry baseline (the new `_test_gill_traction`, run on 77c776b):
  - lips of 0.22, 0.30 and 0.40 m: **not climbed** (he stops about 0.57 m short: the head guard);
  - long faces at 56°, 62° and 75°: not climbed and no adhesion; he slides back down after a jump
    into them;
  - 30° and 45° ramps: walked.
- The ravine-wall probe on the baseline also shows no creep: placed on the wall and pushing up, he
  slides straight to the floor.
- The rest of the "rigid block" complaint is visual. The baseline follow tests show every spine
  segment swinging round on the same frame (±1) in a turn, and zero pitch conformity on a slope
  (every segment 30° off a 30° ramp).

## 2. Design chosen

### (a) Follow-through spine (model only) — `axolotl_model.gd` `_update_follow`
- **Representation.** Each of the 10 spine segments keeps its own **world** direction
  (`_seg_w`). Each frame the directions are read back in the model's frame as (yaw, pitch). Any
  rotation of the node therefore becomes lag automatically: facing turns, the swimmer's pitch, and
  even the radial up changing over the sphere.
- **Yaw.** Segment 0 (the head) always points where the controller faces, so the head leads with
  zero input lag. Each following segment relaxes toward the one ahead of it with rate
  `k = max(14/s, speed / 0.12 m)`.
  - Moving, the lag of each segment is its length over his speed, so every point of the body passes
    where the head passed: the body lies along the head's path.
  - Turning on the spot, it is a C-bend that straightens in about 0.5 s.
  - The bend is clamped to 0.42 rad per joint.
- **Why not the parasite's position trail.** I tried it on paper. A position trail folds the body
  into a U on a turn in place: the head circles its own trail within 0.2 m of the node. The
  per-segment lag gives the same path-following when moving and degrades gracefully to a C-bend
  when stationary. It also never needs clearing mid-play; `reset_follow()` clears it on `place()`,
  and a jump of more than 2.5 m in a frame counts as a teleport.
- **Pitch.**
  - On the ground, four rays (`FOLLOW_RAYS` z = −0.45, 0, 0.45, 0.9) give a piecewise ground
    profile under the body. Each segment eases (16/s) onto the slope under it, and the head joint
    is lifted onto the ground under it (`_f_lift`). The front therefore pitches first onto a slope,
    and the body drapes over crests and lips.
  - Each ray starts 0.6 m above the ground found by the ray before it, so it reaches ground rising
    behind him, and it ignores back faces.
  - In the air the head segment leads with `vup` and the rest follows the arc. The rigid rig tilt
    is cut to a third.
  - In the water the head is locked to the nose, and the body lags through dives and turns (looser
    than on land). The static swim `tail_base` is halved, because the follow already swings the
    tail out.
- **Composition.** The final bone rotation is `q_follow(relative) * q_anim`. The wave, whip, arch
  and idles are unchanged and ride on top.
  - Whip, lunge, landing, LOOKAROUND and DANCE straighten the follow yaw quickly (30/s). They are
    authored whole-body moves, and the swipe arc is drawn from the straight body.
  - `whip_tip_az` includes the follow yaw, so the arc still rides the real tail tip.
- **Scope.** The Gill page preview keeps `follow = false`: it is a colour preview on a turntable.
  The aquarium stand-in and the swimmer use it.
- **Cost.** 4 rays per frame, for the player on the ground only; about 40 trig ops per model.

### (b) Distributed traction — `axolotl.gd`
- **Lip pull-over (`_lip_ahead`, `LIP_MAX` 0.42 m).** A pull starts only when all of these hold:
  - he is grounded on gentle (under 40°), stable ground;
  - he is armed;
  - he is blocked (the head guard pushed him or `is_on_wall()`);
  - he is pushing forward (stick within about 45° of facing);
  - none of these are running: lunge, swipe, Tier-2, bubble column, current stream, hurt lock.

  The probe then requires:
  - a gentle top (under 40°), 0.1–0.42 m above his feet, where his front feet reach (0.72 m ahead);
  - the top still there 0.3 m further on (a real top, not a fin);
  - nothing rising above the lip (two forward rays);
  - nothing overhead;
  - room for his body sphere on top;
  - not in a ravine;
  - still, solid ground: no bending or swaying leaf, crumble cap, unsettled moving body or `unsafe`
    meta.
- **The pull itself.** One bounded move: 3.2 m/s up, 2 m/s forward, at most 0.35 s, cancelled by
  releasing the stick, a jump, a lunge, Tier-2 or a hit. The head guard is skipped only during the
  pull. It ends when his feet clear the lip, and he walks on.
- **Budget.** Each landing on gentle, stable ground re-arms one pull. So a long face never ratchets:
  there is no gentle purchase within 0.42 m on it, and a stack of narrow ledges is not "a top that
  goes on".
- **Long steep faces.** No adhesion was measured on the baseline, and nothing in the change adds
  any. There is no wall grip, the head guard is unchanged, and the pull needs gentle footing. He
  slides down anything over 52°, as before. Tests pin this: 56/62/75° faces, a ledged 60° face, and
  ravine walls.
- **Why no new routes (proof sketch).** A pull needs him standing on gentle ground F with the top
  S at most 0.42 m above F, right next to F, with headroom. From F a plain standing jump
  (1.85 m apex) always reached S. So the pull only makes existing moves smoother; it creates no new
  reachability. It never starts mid-air, so it cannot extend a jump or a burst.
- **Unchanged.** The M1 jump requirement (a 1.3 m mound) is untouched: 1.3 m > 0.42 m, and every
  cushion is at least 1.2 m tall, with walls of at least 0.97 m above its 0.23 m flare.
- **Apex bookkeeping.** Falls are measured from the pull's top, so a pull never registers as a fall.
  During the pull the model sees him as grounded and conforming, so the body drapes over the lip.

### Rejected alternatives
- **Tilting the gameplay body or its collision to the floor normal.** It would change collision,
  jump arcs, the camera and every route. The follow is visual only.
- **`floor_block_on_wall = true` or a raised floor angle.** Global engine behaviour changes that
  risk leaves, canopy and cave contracts. There was no measured adhesion to fix.
- **An automatic step-up of the sphere.** Invisible, and it would apply mid-air.

## 3. Risk register and how each contract is protected

| Contract | Risk | Protection / evidence |
|---|---|---|
| Jump, burst, lunge numbers | traction interferes | constants untouched; pull cancelled by jump/lunge; `_test_jump_and_burst`, `_test_coyote_and_buffer`, `_test_hard_landing`, `traction_tall_lip_needs_a_jump` |
| Falls / hard landings / canopy drop | pull counted as fall | apex follows the pull; `_test_hard_landing`, `_test_canopy` |
| Canopy rule (plain jumps) / leaves | pull onto leaves | leaves (bend/sway/crumble/moving) are never purchase; purchase rays on layers 1\|2 only; `_test_canopy*`, `_test_leaf_footing`, `_test_climbs_physical`, `_test_jungle_ladders_physical` |
| Designed elevated content | shortcut via lips | proof above + `_test_traction_no_shortcuts` (every elevated body, 6 sides) + `_test_route_audit` |
| Ravines unscalable | pull out of a ravine | ravine carve rejects purchase and footing; `traction_ravine_walls_unscalable`, `_test_ravines` |
| Caves / mound head tests | guard skipped during pull | pull only with nothing rising above the lip; walls are 1.9 m+ (caves) and 0.97 m+ (mounds); `_test_caves`, `_test_mounds` |
| Idles never move the body | follow moves the node | follow is bones only; `idles_never_move_gameplay_body` |
| Tail whip timing and arc | follow bends the tail | follow yaw straightens during the whip; arc azimuth includes it; `_test_tail_whip` |
| Wake (bone 9 tail) | bone positions change | `_test_vegetation` (wake checks) |
| Aquarium modes / swimmer | swimmer bends wrongly | `_test_swim_body_follow`, `_test_aquarium_experiences` |
| Teleports / saves | smear after place | `place_clears_the_body_trail`; the follow state is not saved (cosmetic) |
| Responsiveness | input lag | controller timing unchanged (`controls_turn_unchanged`: faces round in 2 frames, as before) |
| Playthrough bot `_wall_follow` | bot now climbs lips | playthrough seed 4242 |

## 4. Results

### Commits (branch `mote-issue1-locomotion`, on top of `77c776b`)

| Commit | What it does |
|---|---|
| `6fafe69` | Model follow-through: yaw/pitch lag, ground conformity, air lead, swim bends, `reset_follow` on `place()` |
| `66c9e2f` | Distributed traction: lip pull-over, bounded and re-armed only on gentle stable ground; traction tests and the no-shortcut probe |
| `111a913`, `18a9f00` | Shots mode `loco`, for renders |
| `12637a9` | Test section header wording, for the copy check |

### New tests (all pass)

- `_test_gill_traction`:
  - lips of 0.22, 0.30 and 0.40 m are pulled over (3 pulls);
  - a 0.62 m lip needs a jump: pushing gains 0.02 m; a jump lands him on top;
  - 56°, 62° and 75° faces over 4 pushes reach at most 0.03 m and rest at 0.00–0.02 m, and he
    slides off after a jump into them, with 0 pulls;
  - a ledged 60° face gets 0 pulls;
  - 30° and 45° ramps are walked;
  - ravine walls: no pull, he slides back down.
- `_test_traction_no_shortcuts`: 172 elevated bodies, 966 ground approaches. There were 3 pulls,
  all over lips on Moss Ball 1 ridge flanks, and none reached a top (0.58–0.66 m of 3 m). There were
  20 walk-ups of designed ramps with no pull.
- `_test_gill_body_follow`:
  - turning, segments swing round on frames `[4, 7, 8, 9, 10, 11, 11, 10, 11, 11]` (base: all
    within frames 4–5);
  - the bend reaches up to 55° and straightens to 5.5°;
  - the gameplay body still faces round in 2 frames;
  - running a curve, the tail is 19° off the head on average;
  - onto a slope, the front leads the tail by 25°; on the slope every segment is within 2.7° (base:
    33°);
  - `place()` leaves 0.0° of follow bend.
- `_test_swim_body_follow`: the swimmer bends 28° in turns and 9° in dives (base: 0° in dives), and
  2° gliding straight.

### Existing tests

- Model-related, before the traction commit: `_test_gill_look`, `_test_gill_idles`,
  `_test_tail_whip`, `_test_vegetation` (wake), `_test_aquarium_experiences`,
  `_test_gill_colours`: 42/42.
- Risky batch (new tests plus look, idles, whip, jump and burst, coyote, hard landing, sphere
  walk, canopy, climbs physical, jungle ladders, leaf footing, caves, mounds, route audit,
  ravines, aquarium, tutorial route): 92/92.
- Full unit suite on the branch: **505 passed, 2 failed** (both since fixed on the game branch). Both failures are pre-existing: the full suite on base
  code (`77c776b` scripts) gives 491 passed, 3 failed.
  - `no_new_exposition_or_name_copies` flags the phrase "Gill's" in unit_tests.gd L5230, and in
    ui_style.gd and presentation_ui.gd from the aquarium package.
  - `treasure_bad_spot_recovered` is order dependent: it passes as the treasure group, 37/37. Base
    also fails it, plus `treasure_no_double_and_clean_end`.

### Playthrough (seed 4242)

- 23/23 checks passed, 100% completion at 4937 s of game time, taking about 20 minutes of real
  time; 2 deaths.
- The bot's stuck recoveries were 244. Earlier 4242 runs on this machine took 4812–5383 s of game
  time with 193–252 recoveries, so there is no regression.

## 5. Known limits and follow-ups

- During the pull the body rises as a whole (the head clears the lip, and the tail floats about
  0.1 m for a moment) before the follow drapes it. A dedicated front-legs-up pose would read better.
- The follow uses the node's own displacement for speed. On the vortex ride (driven by `game.gd`)
  it works the same, but it was not rendered.
- The owner's specific "mossy slope" spot was not located. Open Issue #2 (elevated content) was
  audited separately and fixed in level design (bubble columns beside the platforms they serve,
  readable as lifts; ledger, Mote Open Issues); the traction work does not change reachability.
