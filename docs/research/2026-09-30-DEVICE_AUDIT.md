# Physical-device audit, 2026-09-30 (read-only research; nothing implemented)

Base: dev-000034 + docs (50bfbc2). Owner decisions still open are listed at the end; a section
becomes buildable only once its decisions are settled and the owner authorizes it.

## A. Colour Customizer and Settings: no scrolling
**Root cause.** Godot's `Viewport::_gui_call_input` stops pointer events at the first control whose
filter is `MOUSE_FILTER_STOP` (Button, HSlider, CheckButton default). The colour column is a
`ScrollContainer` (`gill_page.gd:49-56`) full of STOP controls, so a drag scrolls only if it starts on
pass-through area: 44–52 % of the visible 648 px window at 1280×720. Trials in the running game: a
swipe from a gap scrolled 0→149 px; one from the Body slider recoloured Gill (0.000→0.030) and did not
scroll; one from a swatch reached no scroll handler. Earlier fixes arbitrated stage-vs-panel (a
different boundary); tests scrolled via `scroll_vertical` or the 28 px bar, never a finger on content.
Settings has the same cause, worse: content 460×1493 in a 560×560 scroll (`pause_menu.gd:44-51`).

**Viewport.** Base 1280×720, `canvas_items` + `expand`, immersive: every landscape phone is 720 design
px tall; only width grows (1280 at 16:9, ~1560 at 19.5:9, 1600 at 20:9). Cut-outs ≈70–90 px on one
side. Design worst case 1244×692.

**Colours layout (no ScrollContainer).** Left column `clamp(0.46·W, 590, 640)`, margins 16/12, sep 8:
header (title 30 pt gold, Reset 130×60, Done 130×60); "Colour" + morph grid 4×2 (≈136×62); fine-tune
grid [label 96][colour slider][shade slider] for Body and Freckles (sliders ≈220×56); "Pattern" + grid
4×2 (≈136×70) with Upload… as the last cell and "Mine" joining; last row Full colour check 200×58 +
Repeats slider. Upload status moves to a caption over the stage. Needs 668/692 px height. Right: the
stage takes the rest (658–860 px wide); Gill ≈60 % of stage width. Compact fallback (still no scroll):
swatches 62→58, pattern cells 70→64. Sliders: `scrollable = false`, grab on thumb/track only.
Mockups: scratchpad `devaudit/mockA`, `mockB`.

**Settings layout (panel 1212 wide).** Left column (400, 64 px buttons): Resume, Return to Title, New
Run (confirm), Aquarium, Treasure Hunt, Gill's colours, Skills (00036), and at the bottom About /
Diagnostics, controller status and startup line. Right column (700): run time (30 pt) + detail in two
columns (20 pt); Tier 2 loadout as ONE horizontal row (`tier2_loadout.gd`); 2×2 toggles (340×60); Music
| Sound sliders (56 high). Right ≈620 px, left ≈580 px tall; no control under 56 px. Mockups:
`devaudit/setA`, `setB`.

**Pause order.** Smallest change: create `title` right after `v.add_child(resume)` (`pause_menu.gd:55`);
it stays in `_session_rows` (hidden from title-screen Settings). No test depends on order.

**Tests to rewrite:** `colours_split_workspace`, `colours_scroll_keeps_gill`, `_test_menu_scrollbar`,
the `_test_aquarium_polish` colours block; new fit test (every control inside the safe area, no
overlaps, at 1280×720, 1560×720 and 1600×720 with a 90 px inset). Renders `uiq`, `settings_scroll_*`.

## B. Aquarium Gill navigation
"VIEW FILL" is not a label in the build; the Live Tank View button cycles Whole tank / Left side /
Right side / Gill close-up. Gill is visible only in Gill close-up (924 px head-to-tail vs 1–2 px
elsewhere), so that is taken as "VIEW FILL" pending owner confirmation.

**Root cause: the stand-in has no environment awareness.** `presentation.gd` `_wander` (264-283) picks
a goal 0.3–1.2 m from home in a straight line with no check; `_place_standin` (286-297) snaps a single
point with one ray from +1.5 m to −2 m (mask 1|2|8). Anything taller than 1.5 m is walked into; lower
things pop him up by up to 1.5 m; he walks off edges; his body is rigid to radial up
(`model.conform` false), so hips and tail sink into slopes. No footprint, clearance, stuck logic or
avoidance. Measured (504 simulated minutes, 7 balls × 24 homes): 19 of 168 homes clip deeply, 2.34 %
of samples deep (+1.11 % contact), worst homes 25–53 % of the time; deep samples dominated by body and
tail (mid 2,062, hips 2,165, tail 2,121 vs head 892); 103 pops up to 1.51 m; median roam 1.15 m. Every
framing mode has it equally; the close-up only shows it. The close-up camera's ray (mask 1|2, min
0.5 m, `:195-206`) also lands inside him or leaves.

**Design.** New `scripts/actors/gill_explorer.gd` (RefCounted brain; Presentation calls `step(dt)`).
- Water shell on his ball, altitude 0.4–3.5 m; territory radius 10 m around home; tank layer respected.
- Destinations every 6–14 s or on arrival: 12 candidates; reject without 0.35 m sphere clearance; score
  distance preference 2–8 m, novelty (decaying 1.5 m cell visit memory), interest (plant edges, leaf
  tips, mound tops), reachability (clear `cast_motion` or a two-leg route).
- Context steering: 16 planar directions ±25° vertical; danger from head shape casts (r 0.30,
  look-ahead v·0.9 s + 0.7 m), ≤4 casts per frame round-robin; turn rate ≤1.6 rad/s, min radius 0.6 m,
  slow near danger. Body follows through the existing time-based follow; swim gait.
- Organic variation via `OrganicMotion` (00035) with a new `GILL_EXPLORE` profile (drift 0.35 rad @
  0.03 Hz, weave 0.12 @ 0.2 Hz, speed ±25 % @ 0.08 Hz, lift 0.4 m @ 0.04 Hz, rare hover-and-look).
  Share only the signal library and the intent/expression split, never enemy AI.
- Safety net: kinematic sphere 0.30 m at spine height with `move_and_slide`; a hit counts as late
  avoidance (target ≈0).
- Body clearance from real dimensions (head −0.27, tail tip +1.03, half-width 0.225, spine 0.17);
  hips/tail spheres (0.10/0.05) every 3rd frame widen the turn on contact; `conform = true` when resting.
- Stuck recovery, 2.5 s progress window (≥0.3 m): L1 slow to 40 % and double scan; L2 stop, back 0.5 m,
  turn to the most open of 26 directions; L3 new goal in the open hemisphere; L4 relocate to the last
  free breadcrumb only under a camera cut or view change. L4 must be 0 in tests.
- Close-up camera: mask 1|2|8, minimum distance ≥ body length.
**Validation.** `_phase_aq_nav`: every ball, 24 homes, 10 simulated minutes each; pass = 0 deep
penetrations, contact <0.2 %, 0 L4, stuck <1 % and no episode >4 s, ≥90 % destinations reached, ≥70 %
of reachable cells visited per 10 min, no revisit period <60 s; twin runs identical. Real frames in
every Live Tank view at the 8 worst homes; renders of open water, curving round moss, under a leaf,
near a mound, pocket escape, a 10-minute path trace. Cost ≈4 casts + 2 overlaps + 17 sines per frame,
aquarium only.

## C. Tall plants: terminal growth
Generator `MeshLib.stem_plant_mesh` (`mesh_lib.gd:112-170`) via `Levels._sprouts` (`levels.gd:124`,
`:135`). Root causes: decussate opposite pairs of flat kites that go horizontal near the top; uniform
spacing; a straight 3-sided tube that runs past the last pair to t = 1; no terminal bud; one mesh per
ball instanced everywhere (clones). Rules: 8–12 nodes, internodes geometric q 0.80–0.90; zigzag kink
0.08–0.16 rad per node; 4-sided tube, ring per node, taper to 20 %; one leaf per node (70 % distichous
180°±20°, 30 % spiral 137°±6°), short petiole, lance blade (6 stations, sin^0.8 width), size 1.0→0.5
with t^1.4, elevation 30°→62°, droop 0.45→0.12, midrib fold 12°→45°; terminal cluster of 3 young
folded leaves (0.26–0.36 size, 68–80°) set 0.25 of their size below the tip, so no bare stick; 4–6
variant meshes per ball; UV.y convention kept (sway unchanged). ≈2.2× triangles per plant, offset by
6 instead of 8 crown stems or far-view thinning. QA: turntables per variant, in-situ crown at 3
distances, far view, automated no-bare-tip and ≥4-variants checks, sway strip.
Mockup: `devaudit/plantB`.

## D. Normal repopulation (restoration permanent)
Today: parasites never return; pufferfish and stalkers return after 120 s when Gill is ≥20 m away;
crabs and eels stay defeated; food only on his ball, one target per ball (7–16), refill every
`2.5·7/target` s in ~7 authored regions, >22° from him, from 7–10 m up, using the global `randf()`.
**Returners:** new `Parasite` with `completion_id = ""` in a separate `ball.returners` list (never
`ball.parasites`), so catalog stamping and `_apply_run` never see them; `parasite_killed` branches: no
`_earn`, no `complete_event`, no health-map change. Per zone: first return ≥300 s of play after the
last kill, then every 240–420 s, hashed from (run id, zone, n); cap `ceil(0.34 × authored)`, ≤6 alive
per ball; authored species mix; spawn at authored `spawn_dir`s ≥35 m from Gill and off-camera; never
within 20 m of a bloom or 12 m of a vortex mouth. Saved as `run["world"]["repop"]` timers (additive).
**Food:** per-region targets `clamp(round(area/250 m²), 1, 4)` within 55 m; per-region cooldown
45–90 s; global cap 1.5 × `food_target`; own RNG seeded from (run id, ball) (re-baseline playthroughs
once). Tests: `repop_no_ids_no_restoration_change`, `repop_offscreen_and_far`,
`repop_not_before_grace`, `repop_caps`, `repop_saved_timers`, `food_local_targets_and_cooldown`,
`food_rng_isolated`, both playthroughs to 100 %.

## E. Hard Mode (APPROVED / QUEUED LAST / SPECIFICATION COMPLETE except the one blocker at the end / IMPLEMENTATION NOT YET STARTED; builds on D's returners; owner rulings above and §E2 take precedence)
- **Selection:** `run["mode"] = "hard"` at New Run (two-choice dialog); missing = normal, so every
  existing save and b22 install is Normal; run format stays 1 (additive; `migrate` keeps unknown keys;
  an older build plays a Hard run as Normal and loses nothing). Records carry `mode`;
  `best_finish_s_hard` separate.
- **Vitality:** per zone `V ∈ [F, 1]`; displayed and effective moss health =
  `health_map × lerp(0.35, 1, V)` via a 64×32 R8 vitality texture per ball (one extra fetch in
  `moss.gdshader` and `vegetation.gdshader`, repainted when V changes >0.01). Earned ids and the
  permanent health map are never touched.
- **Load** `L = Σ` live parasites and returners homed in the zone (small 1, medium 2, spitter 2,
  large 3). **Decay** `dV/dt = −0.0010 · min(L, 6) / 3` per play second when L > 0.
  **Recovery:** kill +0.12 (eased 3 s), mote restored +0.10, passive +0.002/s at L = 0.
- **Floors:** `F_zone = 0.20 + 0.40 · (done/total)` (a fully restored zone never below 0.60); a
  completed ball's mean V ≥ 0.65.
- **Anti-collapse:** returner cap `ceil(0.5 × authored)` per zone, ≤10 per ball; ≤2 zones per ball
  losing at once; no returners into a zone at its floor; return rate halves at Gill health ≤2.
  **Anti-lock:** returners keep coming at the Hard rate (every 180–300 s per zone after a 240 s grace)
  even on completed balls.
- **Scope** (remote behaviour pending the remaining blocker; see §E2): Gill's current ball runs the full local model; nothing while the app is closed; saved as
  `run["world"]["vitality"]` plus repop timers; no returners within 20 m of blooms, and zones with a
  touched bloom get their floor raised by 0.1; vortices, gates and crumbles key off earned restoration
  and zone-completed flags (`game.gd:1025`, `moss_ball.gd:795-815`), so vitality never closes them.
- **Completion:** 100 % = the same 348 ids, earned permanently. Finish = all seven balls restored (as
  in Normal) and freezes the time; the struggle continues as postgame. "Living aquarium" (every ball's
  mean V ≥ 0.9) is a moment, not a completion id. The timer is unchanged. 00036 starfish and skills
  are independent of mode. Timing hashed from (run id, ball, zone, n); play-time clocks only.
- **HUD:** top centre 360×20: DEAD (grey tuft) ◄ track ► LIVING (green sprout), UiStyle mint/gold; the
  marker is the current ball's area-weighted mean V; a secondary tick for Gill's zone glows and drifts
  while under pressure; a 3 px line in Reduced HUD; hidden in Normal. 4 Hz update, <0.1 ms.
- **Tests:** `hard_mode_saved_and_default_normal`, `hard_vitality_decay_rate`, `hard_floors_hold`,
  `hard_kill_and_mote_recover`, `hard_other_ball_frozen`, `hard_no_decay_while_closed`,
  `hard_vortex_gate_never_regress`, `hard_completion_never_unearned`, `hard_finish_same_as_normal`,
  `hard_hud_normal_hidden`, `hard_old_save_is_normal`.
- **`_phase_hard_sim`:** pure-data model, 3 scripted players × 3 simulated hours per ball.
  - Idle: V converges to the floors, never below.
  - Diligent: mean V ≥ 0.85, caps respected.
  - Casual (50 % kills): V in [0.65, 0.95].
  - Chore metric: ≤2 zones per 10 min cross below 0.6.
  - Lock metric: ≥1 pressure event per 10 min on a completed ball.
  - Bot playthroughs on Hard (seeds 7, 4242) reach 100 %.
  - Renders at V = 1, 0.6 and the floor, and the HUD in each state.
- **Release:** `000NN-hard-mode`, with full qualification in both modes.

## F. Release packaging (recommended)
00036-skill-tree → `00037-menus-landscape` (colours, Settings, pause order; after 00036, which edits
`pause_menu.gd`) → `00038-aquarium-gill` (needs `OrganicMotion` from 00035) → `00039-plants`
(rendering: needs a performance and visual campaign) → `00040-repopulation` (touches `game.gd` and the
food RNG; re-baseline) → Hard Mode last.

## Owner rulings (2026-09-30), authoritative
- **A. Living floor:** a fully restored zone never falls below V = 0.60. Visibly unhealthy, never back to
  its original dead state (formula `F_zone = 0.20 + 0.40 · done/total` stands).
- **B. Finish:** as Normal. Restoring all seven spheres completes the run; the struggle may continue as
  postgame; "Living aquarium" is never required to finish.
- **C. Mode:** chosen at New Run only. A Normal run can never convert.
- **D. HUD:** the bar shows the CURRENT sphere, with a subtle tick for Gill's current zone. There is no
  whole-aquarium bar; remote trouble is shown by the vortex network (J).
- **E. Aquarium Gill range:** roughly 10 m around where he was left. A natural home range, not a hard
  wall: destination scoring falls off softly past 8 m, candidates beyond 12 m are rejected, and
  transient steering may pass the edge.
- **F. Resting:** yes. He occasionally settles on moss, leaves or safe surfaces, `conform = true` and
  clearance-checked. It is chosen by the destination scorer, not by timer or fixed spots. Rest 4–12 s,
  at most ~20 % of the time, hashed timing, never twice in a row at the same 1.5 m cell.
- **G. "VIEW FILL"** means the existing **Gill close-up** Live Tank view. That name is used everywhere,
  and no new mode or button is added.
- **H. Normal returners:** the cap is ≈⅓ of a zone's authored parasites (`ceil(0.34 × authored)`),
  and the first return is ≥ 5 min of play after the zone is cleared. Off-camera and distance
  safeguards stay. Returners never award or reduce completion, never grey moss, never reclaim
  territory and never relock progression or vortices. The values are initial and tuned after phone
  feel tests. Food follows the local-region target and cooldown design (§D).
- **I. Hard simulation rules** retained: nothing deteriorates while the app is closed; unlocked
  vortices and gates stay unlocked; there is no permanent progression lock; the 0.60 floor and the
  anti-collapse and anti-lock rules stay active. The ruling "only the CURRENT sphere advances
  pressure" conflicts with J/N/P; see **Remaining blocker** below.
- **J–M. Remote distress through the vortex network (Hard only).** Every connection touching a
  threatened sphere signals on the HALF nearest that sphere (from the midpoint to its mouth). The
  other half stays normal unless its own sphere is threatened, and both halves signal independently
  when both are. Each connection keeps its own tint (`Vortex.TINTS`), pulsing between darker and
  brighter versions of that colour in the foam, streaks, jets, eye ring, bubbles and debris. It stays
  predominantly water: no red, no solid glowing tube, no rapid flashing. The HUD shows local detail;
  the vortices give remote direction; there are no floating arrows or quest markers.
- **N. Travel fairness** comes from measured traversal, not assumption (§E2).
- **O–Q.** Explicit vortex-distress tests, a seven-sphere accelerated simulation, and visual proof at
  phone scale (§E2).
- **R. Opening audio:** trace and fix (§G).
- **S.** All eight audit items stay authorized for the queue (§A–D).

## E2. Hard Mode additions: distress, travel fairness, remote pressure
**Travel measurement** (300 vortex hops across 7 playthrough logs, from "heading into vortex" to
"arrived", including the walk to the mouth): median 21.0 s, p90 27.6 s, max 49.6 s. Network (links
1-2, 2-3, 1-4, 2-5, 3-6, 4-7): diameter 5 hops. Worst-case response budget:
`T_resp = notice 120 s + transit 5 × 28 s + arrival-to-zone 90 s ≈ 350 s`. Skills (Quick Gill,
Glide) only shorten it; timings assume base speed.

**Sphere health for signalling.** `V_b` = area-weighted mean zone V on sphere b; `F_b` = the matching
floor mean; normalised `h_b = (V_b − F_b) / (1 − F_b)`. `A_b` (active pressure) = zone load
`L_b ≥ 2` and `V_b` fell over the last 20 s. The severity is DERIVED, never saved:

| Level | Condition (with A_b) | Pulse period | Luminance swing | Tint amount |
|---|---|---|---|---|
| S0 normal | not A_b, or h_b ≥ 0.90 | none | none | 0.50 (today) |
| S1 meaningful | h_b < 0.90 | 6.0 s | ±12 % | 0.55 |
| S2 greying | h_b < 0.65 | 4.0 s | ±25 % | 0.62 |
| S3 urgent | h_b < 0.35 | 2.5 s | ±40 % | 0.72 |

- Hysteresis: a level exits 0.05 above its entry threshold, and levels crossfade over 3 s.
- When pressure is relieved (A_b false), the level steps down one per 8 s, so it clears naturally.
- The period never drops under 2.0 s.
- Pulse: `p = 0.5 + 0.5 · sin(2π t / period + link_phase)`; colour = `tint × lerp(0.55, 1.45, p)`
  with ≤20 % lift toward white at S3.
- Half masks along the tube parameter u (0 = end A, 1 = end B):
  `mA = smoothstep(0.55, 0.45, u)`, `mB = smoothstep(0.45, 0.55, u)`. The A pool, eye and debris
  belong to A.
- Implementation: new uniforms `distress_a` / `distress_b` (vec2: amount, period) in
  `vortex_jets`, `vortex_pool` and `vortex_debris` shaders, set by the Hard controller at 4 Hz.
  Normal always passes 0.
- Purely visual: the ride, unlock state, collision and the bot are untouched.

**Timing check at maximum remote pressure** (fully restored sphere, F = 0.60):
- remote decay = 0.15 × local maximum = 0.0003 V/s;
- h 1 → 0.90 (quiet) takes 133 s;
- S1 → S3 (h 0.90 → 0.35, ΔV 0.22) takes **733 s ≥ 2 × T_resp (700 s)**;
- S3 → floor takes 467 s, and the sphere then plateaus at the floor. It is never lost.

**Remote pressure model** (recommended option (b) below; waiting for the owner):
- Remote spheres are data-only: no entities, 4 Hz.
- "Incursions" start aquarium-wide every 15–25 min of play, timing hashed from (run id, n), on a
  sphere with ≥1 restored zone, never the sphere Gill left in the last 10 min.
- At most ONE remote sphere is under incursion at a time.
- Abstract load ramps to the zone caps (`ceil(0.5 × authored)`, ≤10 per sphere).
- When Gill arrives, the abstract load becomes real returners through the normal off-camera spawn
  rules, and the local model resumes.
- An incursion also ends at the floor plateau: the signal stays at S3 until relieved.
- Nothing ticks while the app is closed or during menus or the aquarium.

**Tests (O):**
- `hard_distress_correct_half`
- `hard_distress_healthy_half_normal`
- `hard_distress_all_links_of_sphere`
- `hard_distress_unrelated_links_normal`
- `hard_distress_both_ends_independent`
- `hard_distress_tracks_pressure`
- `hard_distress_before_major_regression` (S1 reached while h ≥ 0.85)
- `hard_distress_clears_when_relieved`
- `hard_distress_keeps_link_colour` (hue within ±6° of `Vortex.TINTS`)
- `hard_distress_none_in_normal`
- `hard_distress_no_travel_change`
- `hard_distress_no_unlock_change`
- `hard_distress_no_collision_change`
- `hard_distress_derived_on_load` (no saved flag)

**Simulation (P):** extend `_phase_hard_sim` to seven spheres with a travel model: the measured hop
distribution plus arrival-to-zone 30–90 s. Players:
- **idle:** never responds;
- **responsive:** notices S1 on a mouth sighting (probability 0.5 per minute near a mouth) and
  responds;
- **distracted:** responds only at S2 and above;
- **completionist:** keeps exploring and collecting; responds at S3.

Twelve simulated hours each, several seeds. Pass criteria:
- No sphere below its floor.
- Responsive and distracted players keep every sphere at h ≥ 0.35 for ≥ 95 % of the time, with no
  unavoidable loss.
- Median ≥ 15 min between remote summons, and ≥ 70 % of play time with no remote S1 or above.
- No oscillation: a stabilised sphere stays at S0 for ≥ 10 min in ≥ 90 % of cases.
- No permanent Living lock: ≥ 1 pressure event per 30 min aquarium-wide.
- No progression locks; save/load mid-incursion yields the same state.
- Real bot playthroughs on Hard (seeds 7, 4242) reach 100 %.

**Visual proof (Q):** renders of a healthy connection; one end mild; one end severe; both ends
independently; every link around one threatened sphere pointing toward it; and the signal clearing.
Real frames at 1280×720 and 1600×720, checked at phone scale; a pulse strip of 8 frames per level.

**Phone checklist (Hard):** New Run dialog; HUD bar and zone tick; a distress pulse readable from a
mouth; the direction reads right; pulse pleasant, not flashing; a sphere recovers after clearing;
100 %/finish as in Normal; Normal shows no distress.

**Release:** `000NN-hard-mode`. Full qualification: unit suite, simulations, both playthroughs in
both modes, OTA end-to-end, performance.

## G. Opening audio: "static" before the menu
**Trace.**
- `AudioDirector._ready` (`scripts/core/audio_director.gd:62-76`) starts `amb_water.wav` (Ambience bus,
  −12 dB, autoplay) while the game builds, behind the loading screen.
- Music starts only at `set_ball` on the title (`:95`), so during loading this loop plays ALONE.
- It is synthesized in `tools/gen_audio.py:382-385`:
  `lowpass(noise, 220 Hz) × 0.8 + highpass(noise, 3000 Hz) × 0.05`, an 8 s mono loop at 22.05 kHz.
- A phone speaker reproduces little below ~300 Hz, so the 220 Hz rumble mostly disappears and what
  remains is the >3 kHz hiss band: it reads as static. Once music plays it is masked, which is why it
  shows only at launch.
- The tank bubbler (`amb_bubbler.wav`: synthesized bubble drops plus 600 Hz lowpassed noise) is
  positional in the tank and room, not part of this bed.

**Fix design.**
- Regenerate `amb_water` in `gen_audio.py` as an aquarium bed:
  - a soft, band-limited water movement layer (~250–900 Hz, audible on phones, no content above
    ~2.5 kHz except bubble transients);
  - a distant aerator of irregular, pitched bubble drops (reusing `drop()` / `place()`) with
    density modulation;
  - two layers with co-prime loop lengths (17 s and 23 s; repetition every 391 s);
  - peak ≤ −6 dBFS; still OGG/WAV and local, well under 1 MB.
- Keep the ONE ambience player: no second track and no stacking.
- Launch: fade the bed in over 1.5 s. On the title, the music starts over it and the bed eases −3 dB
  over 2 s. In play it returns to today's mix (`update_mix`).
- Respects the Ambience bus, which sends through SFX, so the Sound slider and mute apply. It adds no
  startup work: the same load, the same file size range.

**Qualification.**
- An offline spectral check: energy above 3 kHz ≤ −30 dB relative to 250–900 Hz; no clipping; a
  loop-seam click check.
- Launch → loading → title → New Run/Continue → play, with a trace of one ambience player at each step
  and no gaps or jumps (> 3 dB in 100 ms).
- Settings: Sound 0/50/100 %, mute, and restart with saved volumes.
- The startup marks are unchanged within noise.
- Phone checklist: sounds like an aquarium, not static; comfortable volume; no audible repeat; clean
  handover to the menu.

**Placement:** its own small OTA straight after 00036, as `00037-opening-audio`. It is independent
of the UI and aquarium work, touches startup and audio only, and must not ride in 00036, whose
starfish pickup sound likely also edits `gen_audio.py`.

## F2. Release order (updated)
00036-skill-tree → 00037-opening-audio → 00038-menus-landscape → 00039-aquarium-gill →
00040-plants → 00041-repopulation → Hard Mode last. Numbers are assigned at publish; order changes
only for a concrete dependency.

## Remaining blocker (the only player-facing Hard Mode decision)
Ruling I ("only the CURRENT sphere advances pressure") and rulings J/N/P (remote distress developing
while Gill is elsewhere, with a travel deadline and remote response in the simulation) cannot both
hold.
- **(a) Current sphere only.** Remote spheres freeze when he leaves. The vortices show only spheres
  he LEFT under pressure ("unfinished business"); no new remote trouble ever starts and there is no
  deadline. It is simpler and calmer, but the vortex network rarely has anything new to say.
- **(b) Remote incursions, slow and capped (recommended).** One remote sphere at a time, every
  15–25 min, at 0.15× the local rate. S1 → S3 takes ≥ 733 s against a measured ≤ 350 s response.
  Floors and caps apply, and it is paused while the app is closed. This gives the "aquarium calls
  for help" experience J–P describe.
- **(c) Carry-over only.** A sphere left under pressure keeps its trend for ≤ 10 min after he leaves,
  then freezes; no new remote trouble. It sits in between.
