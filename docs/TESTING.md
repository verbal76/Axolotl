# Testing and CI structure

## Running tests locally

```
godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=unit --out=OUTDIR                  # whole suite (~46 min)
... --test=unit --shard=1/2 --out=OUTDIR      # half the suite (~23 min); --shard=2/2 is the other half
... --test=unit --only=_test_food,organic_motion  # exact test names; the _test_ prefix is optional
... --test=unit --only=_phase_organic_cost    # only the organic cost check
... --test=playthrough --out=OUTDIR
```

- Every test prints `[TIME] <test name> <ms>` after it finishes: `grep '^\[TIME\]' unit.log | sort -k3 -n -r | head`
  is the list to rebalance the shards from.
- `--only` matches EXACT names (`_test_food` no longer also runs `_test_food_reach`). A name that matches no
  registered test fails the run. An explicit `--only` wins over `--shard`.
- `--shard=K/2`: shard 1 is the explicit `SHARD_ONE` list in `scripts/tests/unit_tests.gd`; shard 2 is every other
  `_test_*` in registry order, so a newly registered test lands on shard 2 and is never dropped. `_phase_*` tests
  belong to no shard (they are the child halves of the relaunch tests and diagnostics, run by name).
- Order dependence: `_test_parasite_combat` -> `_test_organic_motion` -> ... -> `_test_all_clear` ->
  `_test_treasure_*` (and the tests that expect a healed world after it) share ONE world per process and must stay
  together, in registry order. They all live in shard 1. The shards must each have their own HOME/user:// (separate
  CI runners, or `iso.sh`-style isolation locally).
- The shard split came from a static cost proxy; re-balance it with the `[TIME]` numbers of a real run.

`organic_cost_bounded` (scripts/tests/organic_tests.gd) is a wall-clock check made load-tolerant: interleaved ABBA
slices, medians, on/off ratios, the layer's step cost in units of a fixed calibration kernel, one retry. See the
comment above `COST_*` there for the bounds and what each catches.

## CI structure

Before (`.github/workflows`):

```
push to a publish branch  -> ota-publish.yml  : one job, serial: check_scripts + unit (~46 min) + playthrough (~30 min) + sign/publish   ~85 min
pull_request (same SHA)   -> build.yml verify : one job, serial: check_scripts + unit + playthrough + drift + lock                        ~85 min   (duplicate, parallel runner)
push to main (same SHA)   -> build.yml verify : the same again                                                                           ~85 min   (duplicate)
```

After:

```
tests.yml (workflow_call, input ref = full SHA, full = true|false), parallel jobs:
    fast (check_scripts, version drift, runtime lock) | unit shard 1/2 | unit shard 2/2 | playthrough      wall = slowest, ~30-35 min

ota-publish.yml:  resolve (ref -> one full SHA) -> tests (full) -> publish (needs: resolve, tests; checks out that SHA)
                  publish never starts unless fast + both shards + playthrough succeeded for the SHA it publishes.
                  Its own "scripts compile" step, signing, verification, release, re-download and pointer steps are unchanged.
build.yml:        covered? -> tests (full unless covered) -> verify ("Scripts + automated tests (headless)", the stable check name)
                  covered = pull request from a publish branch of this repository (ota-publish tests that very SHA),
                            or the SHA already has a successful ota-publish run (e.g. the push to main of a published commit).
                  Not covered (feature-branch PRs, forks, unpublished SHAs, manual runs): full suites, now as parallel jobs.
                  A covered PR still runs the fast checks (scripts compile, drift, runtime lock).
```

Result: a published SHA is tested once (in the release gate), not two to three times; each full run takes about 35
minutes of wall time instead of about 85. The `android` / `ios` jobs and the native-layer detection are unchanged.
Not done on purpose: `paths-ignore` for docs-only changes (it would leave a required check pending) and a
`concurrency` group on the tests (the release gate already serialises on `ota-dev-channel`).

## First run of the parallel pipeline (2026-10-03)
OTA publish run 91 (a1a53c2, dev-000091): fast checks 31 s, unit shard 1/2 11m47s, shard 2/2 14m41s, playthrough 19m54s in parallel; publish 1 min; **21 min push-to-published** (was ~47 min serial). The PR check (Build & Verify) saw the SHA covered by OTA publish and finished in 1m40s instead of a second full suite.
