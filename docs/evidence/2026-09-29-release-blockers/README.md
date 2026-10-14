# Release blockers found qualifying Treasure Hunt (2026-09-29)

The Treasure Hunt candidate `8c12b15` failed seed 4242 twice, for two different reasons. Neither
was caused by Treasure Hunt, and both are playthrough-bot defects, not game defects. Treasure Hunt
stayed unpublished while they were root-caused and fixed.

The logs are gzipped here because the container that produced them is temporary.

## 1. `backtrack_to_ball1` (seed 4242, second run)

**Symptom.** The bot rode the vortex from ball 2 to ball 1, then went straight back through it. It
was on ball 2 when the check ran (`4242_run2_backtrack_fail.log`, 1997.9 s to 2038.7 s; the
heartbeat at 2020 s is on ball 1).

**Cause (bot).** `goto()` toward the ball-2 mouth only noticed arrival by seeing him within 0.3 m
of that mouth.
- When the ride started while `goto()` was inside a meal, a fight or a detour, it never saw him
  there.
- It then kept chasing the far mouth from ball 1. That walked him out of the arrival pool, past the
  game's 4.5 m re-entry block (`Game._vortex_block`), and back in.

**Game behaviour: correct.** Re-entry needs the player to leave the pool first.

**Fix.** `goto()` ends when a travel ride starts or the ball changes, when a vortex is allowed.

**Regression.** `--start=vortexrace` forces the ride during a 12 s busy spell.

| Fix | Result | Log |
|---|---|---|
| Off | He ends on ball 2: fail, the release symptom | `vortexrace_fix_off.log` |
| On | He stays on ball 1: pass | `vortexrace_fix_on.log` |

## 2. World 7 eel-grotto freeze (seed 4242, first run; also a dev-000029-era run)

**Symptom.** In the 100% phase, Gill stood still in the grotto of `b7.eel.0` from 4,780 s until the
run was stopped (`4242_run1_eel_grotto_freeze.log`). He was at (-171.7, -5.0, 55.4), with the floor
reported as `<null>` 0.13 m up.

The dev-000029-era run `dev29_era_4242_eel2_freeze.log` froze the same way at `b7.eel.2` on 1 hp for
526 heartbeats, and ended at 99.38%.

**Is it a player softlock? No.**
- `trapprobe_3m_172_points.log`: 172 drop points within 3 m, each pushed 4 ways for 1 s and then a
  jump. No point holds him.
- `trapprobe_exact_spot_16_dirs.log`: the exact frozen spot and 8 points within 0.4 m, each pushed
  16 ways. He always moves about 5.9 m.
- Normal input always gets him out.

**Cause (bot).** Reproduced exactly with `--start=eels --eel=b7.eel.0 --hp=2`: one eel hit leaves
him on 1 hp, and he freezes 8.81 m from the mouth, as in the release run
(`repro_eel0_hp2_input_trace.log`).
- The input trace shows controls on, state normal and the stick held at full, pushing into the
  grotto wall beside the cushion mound (`StaticBody3D` 11642).
- On 1 hp, `goto()` calls `eat_nearby()`. That picked the nearest food by straight-line distance,
  22.6 m away outside the grotto, and `lunge_at()` walked straight at it with no progress check
  (`repro_eel0_hp2_food_walks.log`: 83 walks at the same target from the same spot).

**Fix.**
- `eat_nearby()` only picks food it has a clear line to.
- `lunge_at()` gives up after 1.5 s without getting 0.3 m nearer.

**Result.** `eel0_hp2_after_fix.log` and `eels_all_hp2_after_fix.log`: `b7.eel.0` is beaten from 2 hp
and from 1 hp.

## Known, pre-existing, not release gates

The debug scenario `--start=eels` (every eel, starting outside its cave) also fails `b5.eel.0` (a
missed fight within 12 rounds) and `b7.eel.2` (the bot routes over the grotto roof).

- Both fail the same way on dev-000029 `1ad34ea` (`eels_all_dev29.log`) and before the fix
  `d7619e1` (`eels_all_before_food_fix.log`).
- The full playthroughs have beaten both eels.
- They stay open as bot work.
