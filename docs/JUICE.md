# Mote v107: game feel ("juice")

Owner, 2026-10-08, after a read-only audit of what feedback already existed. The aim: Mote's
existing actions, finds and accomplishments feel more responsive, satisfying and expressive
(wet, soft, elastic, organic, buoyant, playful, a little exaggerated), with gameplay unchanged.

## The one rule

**Juice observes gameplay; it never drives it.** Turning all of v107's juice off
(`Juice.enabled = false`) changes no outcome. Unit test `juice_never_drives_play` runs the same
scripted walk, jump, landing and stop with it on and off and requires the same positions, velocities,
grounding and health at every mark.

Guardrails (all checked in `_test_juice` or by construction):
- No change to movement, forces, jump, Water Burst, coyote time, buffering, input, touch, camera,
  lunge targeting or range, collision, enemies, damage, health, invulnerability length, attack timing,
  restoration, progression, saves or timers. No game-time hit-stop, no time scaling.
- No `WaterFX.impulse()` for juice: impulses move food, Motes and parasites. Juice uses only puffs
  (`WaterFX.silt_kick`, `touch_ring`, `sparkle`, `wisp`, `bubbles`), the cosmetic `Wake`, sounds,
  haptics and Gill's model poses (`juice_makes_no_water_push`).
- Cosmetic randomness only from `_fx_rng` (`juice_draws_no_gameplay_random`, which also scans the
  source for bare `randf()`/`randi()`). `WaterFX.trail()`'s water pushes now roll on their own
  generator (`_trail_rng`), so no cosmetic effect can shift when they happen; same 25% chance.
- Event-driven; per-frame reads are a few comparisons. Effects are 3-12 optional puffs, dropped
  first when the puff pool is busy. Emission is timed (`Juice.emit_count`), never per frame.

## What v107 adds (scripts/core/juice.gd unless noted)

| Event | Feedback |
|---|---|
| Soft landing | body squash springing back (scaled by impact), a small silt ring when he came down with weight |
| Push-off | a quick stretch up as he leaves (never before: no latency) and a kick of silt at his feet |
| Eating | a gulp (mouth wide, snapped shut, chin up, swallow) sized by the prey; its own pitch (shrimp light, water flea lower, worm its big gulp); a light haptic; a smaller happy wriggle for the small prey; the food drawn into his mouth over 0.11 s (`Food.eaten(to)`). The heal is applied first, unchanged |
| Invulnerability | his skin breathes a soft glow while his existing `invuln_t` runs (read, never set) |
| Tunnel arrival | a touchdown ring, the soft landing sound, a small settle |
| Starts and stops | a few silt puffs behind (start) or ahead (stop), only on a real change of pace on the ground |
| Edge assist | when the existing assist stops him at a rim, a small teeter with wide eyes (`Axolotl.edge_stops`) |
| Moss steps | a very quiet, varied pat each ~1.15 m on the ground, on its own player (never a pool voice) |
| Tunnel entry | a short haptic |
| Moss ball 100% | first time this run: a new sting (`sfx_ball_restored`), a gentle haptic, "X is fully restored", Gill's delight, plants swaying out (cosmetic wake blast), three timed waves of bubbles and sparkles. Never takes control; outside ordinary play only the sound and the line |
| Health upgrade | the item's light streams into him; the new frond grows in from small (`grow_frond`, `restore_fronds_slowly`) |
| Pearl | its own peach light, sparkle and stream and its own sound (`sfx_pearl`). **Gameplay unchanged** (a full refill); the pearl's future permanent enhancement is undecided and not implemented |
| Glances | now and then, calm, his head turns toward a winding-up parasite, else food, else an open tunnel in front of him; eased in and out, never while lunging, swiping, landing or idling; his facing is never touched |
| Batted glob | turns aqua once it is his (path, speed, damage and collision unchanged) |
| Crab, eel, stalker hits | their own hit sounds (a shell clack, a burst of bubbles, a sharp hiss) |

## Clean-ups (audit findings)

- Sound: a sound already started this frame is not started again (the double deflect `swipe_hit`,
  two tunnels' pulses); the generic parasite `hit` gives way to `swipe_hit` (`Sfx.SUBORDINATE`).
- Frame-rate independence: tunnel-ride puffs (and off the gameplay `randf()`), ooze and re-forming
  sparkles are timed. (`WaterFX.trail()` runs in the physics step, already a fixed rate.)
- Puff pool: a new puff takes a free slot within 12 instead of overwriting a live one; optional puffs
  are dropped when none is free.
- Debris specks retire after 140 s (they drifted on for ever).
- Performance: a settled bloom beyond 45 m of the camera skips its petal sway and glow; a tunnel's
  constant current terms are written when they change; `aquarium.apply` runs when the restoration it
  draws moves (else twice a second and on any state change); the quiet impulse array is not
  re-written every frame.

## Skipped, and why

- **Heal-edge glint**: the growing edge exists only inside the shared moss/plant/vegetation
  `health_at()`; a glint needs a second per-pixel loop over up to 64 heals on all moss: too costly for
  the Pixel target.
- **Music swell**: the new sting carries the moment; a swell would need the music system reworked.
- **Takeoff compression**: a crouch before the jump would delay it; only the release stretch is shown.
- **Wake shader writes**: always live while Gill is on a ball (his body points); no safe skip.

## Tests and renders

`_test_juice` (unit suite) and `--test=shots --only=juice`.
