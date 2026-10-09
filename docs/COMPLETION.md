# Run timer, completion and the run save

Expansion 1 of the Mote open-items list. This is the foundation later expansions build on.

| Piece | File |
|---|---|
| Completion catalog, ids, percentage | `scripts/core/completion.gd` (`Completion`) |
| Run timer | `scripts/core/run_clock.gd` (`RunClock`) |
| Run save (file, migration, records) | `scripts/core/run_save.gd` (`RunSave`) |
| Wiring (earning, finishing, saving, continuing) | `scripts/core/game.gd` (`_open_run`, `_apply_run`, `_earn`, `_finish_run`, `save_run`) |
| UI | title (Continue / New Run), pause menu (run panel, Show run timer, New Run), HUD timer, ALL CLEAR finish time |
| Diagnostics | "Run timer & completion" section, through `StartupTrace.timeline_text` (the r5 bootstrap's only game-layer hook) |

## The run

A **run** is one playthrough from a fresh world. Mote keeps one run in progress, autosaved to
`user://run.json`. Before this expansion Mote saved **no progress at all**: every launch was a fresh
world. From this OTA on, closing and reopening Mote continues the run.

- **Continue** (title): the saved run, resumed at the last bloom (checkpoint) on the moss ball it
  was on, or at that ball's arrival point if no bloom there has been found. Everything earned is back:
  parasites cleared, motes returned, restored moss, caves, blooms, opened vortices, health.
- **New Run** (title, or pause menu; asks first): a fresh world and a fresh clock. Records (best
  finish time, list of past finishes) are kept.
- Autosave: whenever something is earned (within 1 s), when a bloom is found, when the pause menu
  opens, when the app goes to the background or closes, on Return to Title, and every 15 s of play.

## Timer rules

| Rule | Definition |
|---|---|
| **Start** | The first frame of play in a new run: Play or New Run from the title (`Game.start_play` on a run whose clock is `not_started`). |
| **Timed** | Every processed frame while the game is in play: moving, fighting, dying and regenerating, vortex travel and other cinematics. |
| **Not timed** | The title screen; the pause menu (the game is paused); the app in the background or without focus; loading. |
| **Resume** | The frame after returning from the background is discarded. One frame counts at most 0.25 s, so a stall or a resume never adds hidden time. |
| **Finish** | The frame the last moss ball becomes fully restored (every restoration event on every ball). ALL CLEAR follows as presentation and shows the finish time. |
| **Frozen** | The finish time is stored at that frame and never changes. Play afterwards only adds to *play time*. |
| **Source** | The engine's frame delta, summed in float64 seconds. Never the wall clock, so device clock and time-zone changes cannot affect it. The same play gives the same time at any frame rate (to within a frame). |
| **Best** | The fastest finish across runs on this device (`records.best_finish_s`); a New Run keeps it. |
| **Display** | `12.34`, `4:05.67`, `1:02:03.45`, hours grow as needed; centiseconds, truncated. |

The timer belongs to the run save, not the app session: quitting, relaunching, and the restart that
activates an OTA all continue the same clock. OTAs never touch `user://run.json`: the OTA client only
uses `user://ota`. No connection is needed.

Each finish stores the time, the completion % at that moment, the catalog version, the game version,
the OTA id and the timer model. Each run also lists the game versions and OTA ids that played part
of it. Later expansions can add verification or leaderboards on top of this without changing the
timing model (`RunClock.TIMER_MODEL`).

## Finishing is not 100%

- **Game finished**: every moss ball fully restored (the timer freezes).
- **100% complete**: every entry in the catalog earned.

You can finish below 100%: finishing needs only the restoration (and the milestones it brings).
The hidden caves, the blooms and the wildlife are what's left. Finishing with none of them is **58.5%**
(65% before catalog version 3).

## Balance review (Expansion 6)

The finishing floor stays at **58.5%** (restoration 45% + milestones 13.5%). The reasons:

- **Finishing is the speedrun; 100% is the completionist's goal.** A finish must never require
  optional content. The floor is what a player gets if they skip all of it. It sits well below
  100% on purpose, so the percentage keeps meaning something after the credits.
- **Real finishes land far above the floor.** The route to restore each ball passes blooms,
  grotto mouths and creatures. The playthrough bot earns only what its route touches (which
  includes every hidden cave), and it still finishes at 88–89% (table below). The gap from there to
  100% is the out-of-the-way blooms and the cave eels, which is the intended completionist
  content.
- **Nothing can be farmed.** Each id counts once. Stalkers and puffers, which return, earn
  nothing. Only species discovered and guardians and eels defeated count.
- **Raising the floor** would mean moving share from caves, blooms or wildlife into restoration.
  That would make the optional content worth less and change the ids' weights for existing runs.
  **Lowering it** would make an ordinary finish look incomplete. Neither is needed.

The highest first step in the game (the ball 2 mesa's swaying leaves, 1.5 m, with a 3 m/s
current) was reviewed. It stays: it is the game's one timing climb, and its mote is restoration,
not optional.

## 100% by play (Expansion 6)

After ALL CLEAR, the playthrough bot (`scripts/tests/playthrough_bot.gd`, `hundred()`) goes after
every catalog id still missing and earns each one by play, the way a player would. It travels by
vortex, walks or climbs to each bloom, enters each remaining cave, looks at each undiscovered
species, and fights each remaining crab and eel from in front of its crevice, entering its grotto
by the door. Nothing is granted directly. Checks:

- `normal_finish_below_100`: the run finishes below 100%.
- `hundred_percent_by_play`: afterwards every id is earned and the display reads 100%.
- `finish_time_kept_through_100`: the finish time is frozen and unchanged by the later play.

| Seed | Normal finish | Finish time | What the 100% phase earned | 100% reached at | Deaths | Checks |
|---|---|---|---|---|---|---|
| 7 | 87.8% | 1343.63 s | 17 blooms, 4 eels, the eel species | 2241.4 s (game time) | 0 | 23/23 |
| 4242 | 89.4% | 1610.05 s | 14 blooms, 4 eels, the eel species | 2662.7 s (game time) | 0 | 23/23 |

(Final release code, with the Expansion 6 parasite combat, commit `1734ea2`.)

The finish time was unchanged through the 100% phase on both seeds. The proof found real defects,
all fixed in Expansion 6:
- a pearl in the small Hollow Grotto cave rested on the cave's ceiling, out of reach
  (`cave_rewards_on_their_top_ledge`);
- after the parasite combat upgrade, a spitter backing away climbed onto a jungle stem's top,
  8.9 m up, so its ball could never be fully restored (`parasites_never_climb_stems`);
- the vortex-connection shot took the axolotl's controls while a parasite kept hitting him
  (`no_attacks_while_controls_taken`).

It also found stalls in the bot itself (eels fought from the roof above their grotto, a food search
at 1 hp that never timed out); those were the bot's.

## Completion catalog (catalog version 4)

- **Version 4** came with the world expansion (seven worlds at about twice the radius): 348 entries
  (was 172). Every v3 id is kept verbatim (`CatalogFrozen.V3`, tested); the shares are unchanged.
- **Version 3** came with Expansion 5 (the ecosystem): a Wildlife category, 172 entries (was 157).
- **Version 2** came with Expansion 4 (four new moss balls): 157 entries (was 87).
- No id has ever changed.

Each category has a fixed share of 100%. Inside a category every entry counts equally (weight 1).
Version 3 made room for Wildlife by scaling the other shares.

| Category | Share (v2 → v3 → v4) | Entries (v1 → v2 → v3 → v4) | What earns it |
|---|---|---|---|
| Moss restored (`restoration`) | 50% → 45% → 45% | 64 → 110 → 110 → 262 | a parasite cleared, a mote returned to the moss |
| Hidden caves (`caves`) | 20% → 18% → 18% | 3 → 7 → 7 → 8 | the reward in each hidden cave: the health upgrade (balls 1–3) or a pearl (balls 4, 5 and 7; ball 7 has three caves since v4) |
| Blooms found (`blooms`) | 15% → 13.5% → 13.5% | 14 → 26 → 26 → 48 | touching a bloom (checkpoint) |
| Milestones (`milestones`) | 15% → 13.5% → 13.5% | 6 → 14 → 14 → 14 | each moss ball fully restored (7), each vortex opened (6), the aquarium all clear (1) |
| Wildlife (`wildlife`) | — → 10% → 10% | 0 → 0 → 15 → 16 | each of the 8 species discovered (a first close look), each guardian crab (3) and cave eel (5) defeated |

A save from before v4 keeps everything it earned and counts about 67% if it had earned all of v3
(`v3_save_migrates`); the run save format is unchanged (1), and it stores no position (a continued
run resumes at its last bloom, by id, or at the ball's arrival point), so no save can be stranded by
the new terrain.

A pearl is a cave reward: it refills health instead of adding a heart, so the new caves count toward
completion without making the game easier in the old balls.

Percent = the sum over categories that have entries of share × earned weight ÷ total weight,
normalised by those categories' shares. It shows as a whole number rounded **down**, so 100% appears
only when every entry is earned. Earning the same id twice counts once.

**Finishing needs all seven balls restored** (owner decision for Expansion 4). Finishing with no
caves, blooms or wildlife is **58.5%** (65% before version 3). Wildlife is never needed to finish,
and nothing about it can be farmed: each species counts once, and each guardian and eel once.

### Ids

Ids are permanent. Since v4 every completion-bearing node authored before the expansion carries its
v3 id explicitly (`meta fixed_id`: Mossy Meadow's by hand, the other worlds' through
`LevelBuilder.freeze_ids()`), so adding content can never shift one. New content takes the next free
number in its zone (new zones: b1 rim, crack, heights, coral, fern, roots; b2 cut, hollows, kelp,
still; b3 crown, tangle; b4 grand, field, coralsh; b5 maze, secret, dell; b6 sky, garden; b7 chamber,
undercut, shaft, columns). The v3 ids, as shipped:

- Restoration: `b<n>.<zone>.parasite.<i>` and `b<n>.<zone>.mote.<i>`, where `<i>` counts from 0 within the zone.
  - b1: parasites tut 1, meadow 2, east 2, south 1, west 2, under 1; motes meadow 2, east 2, south 2, west 2, under 2.
  - b2: parasites arrive 1, mesa 1, north 2, east 2, south 2, far 2; motes arrive 2, mesa 2, north 2, east 2, south 2, far 2.
  - b3: parasites arrive 1, canopy 2, drop 2, lower 2, roots 2, far 2; motes arrive 2, canopy 3, drop 1, lower 2, roots 2, far 2.
  - b4 (Terrace Steps): parasites landing 1, terraces 2, arch 1, ridge 1, far 1; motes landing 1, terraces 2, arch 2, ridge 1, far 1.
  - b5 (Reed Canyon): parasites landing 1, canyon 2, end 1, far 1; motes landing 1, canyon 2, crests 2, end 1, far 1.
  - b6 (Canopy Spire): parasites landing 1, spire 1, shelves 1, far 1; motes landing 1, spire 2, shelves 2, far 1.
  - b7 (Hollow Grotto): parasites landing 1, corridors 1, grotto 1, cavelet 1, far 1; motes landing 1, corridors 2, grotto 1, cavelet 1, far 1.
- Caves: `b1.cave.0`, `b2.cave.0`, `b3.cave.0`, `b4.cave.0`, `b5.cave.0`, `b7.cave.0`, `b7.cave.1`.
- Blooms: `b1.bloom.0`–`b1.bloom.3`, `b2.bloom.0`–`b2.bloom.4`, `b3.bloom.0`–`b3.bloom.4`, and
  `b<n>.bloom.0`–`b<n>.bloom.2` for balls 4–7.
- Wildlife: `species.shrimp`, `species.snail`, `species.hopper`, `species.glowworm`,
  `species.stalker`, `species.crab`, `species.eel`, `species.puffer`; `b4.crab.0`, `b5.crab.0`,
  `b7.crab.0`; `b2.eel.0`, `b5.eel.0`, `b7.eel.0`, `b7.eel.1`.
- Milestones: `b1.restored` … `b7.restored`; `vortex.b1-b2`, `vortex.b2-b3`, `vortex.b1-b4`,
  `vortex.b2-b5`, `vortex.b3-b6`, `vortex.b4-b7`; `ending.all_clear`.

The unit test `completion_ids_unique_and_pinned` pins the count (348) and a SHA-256 of the ids in
catalog order. Any change to completion content fails it on purpose.

## Extending the catalog (Expansions 2–6)

1. New content registers through `Completion.build_from_world`. A new ball `b4` gets ids automatically
   from its level data. A new *kind* of thing gets its own id pattern there, under an existing
   category or a new one.
2. A new category needs an entry in `Completion.CATEGORIES`; re-balance the shares so they sum to 100.
3. Bump `Completion.CATALOG_VERSION`, re-pin the test (count and SHA), and update this document.
4. **Never rename or reuse an existing id.** If level data order changes, keep the old ids (map them
   explicitly) rather than letting them shift.

**When the catalog grows:** a save keeps every id it earned. The new entries are unearned, so the
denominator grows and the percentage **goes down** (by the new entries' share of their categories: a
new ball's restoration alone would take a 100% save to about 84%). That is intended: it never claims 100% while something is left. Ids the catalog no longer
lists stay in the save but are not counted. Whether a run finished, its frozen finish time and the
best time never change when the catalog grows. If a later expansion changes what "finished" means,
earlier finishes keep their recorded catalog version.

## Existing saves (migration)

- `user://settings.cfg` (volumes, HUD, haptics, save schema 1) is unchanged. The run save is a new,
  separate file with its own format (`RunSave.FORMAT` 1). The save schema stays 1, and older OTAs
  ignore `user://run.json`, so rolling back cannot damage it.
- **There is no earlier progress to migrate.** Before this OTA Mote wrote no game progress anywhere.
  The only file was `settings.cfg`, so a run finished on a phone before this update (including the
  completed proof-of-concept run) left no evidence on disk. On first launch Mote creates a new run
  save that records this (`history.migration`: "none: … no earlier progress existed on this device").
  It does not invent a finish, a time or earned items. Diagnostics shows the run save's origin.
- Damaged run save: falls back to `run.json.bak`. If both are unreadable, the damaged file is kept
  as `run.json.unreadable-<n>` (never deleted) and a new run starts.
- A run save from a **newer** format (after rolling back past a future migration) is never
  overwritten. The game plays without saving until an update that understands it returns.

## Diagnostics

The "Run timer & completion" section shows:
- timer state (and whether it is suspended)
- run time and play time
- finished or not, with the frozen finish time
- best finish
- completion % with earned and total entries, and how many earned ids are stored
- run id, the catalog version the run started with and the current one
- run save path, format, timer model and origin
- the last save result

## Tests

In `scripts/tests/unit_tests.gd`:
- `_test_run_clock`: the start, active, pause, background, cap, finish, frozen, serialisation, frame-rate and wall-clock rules, and formatting.
- `_test_completion_catalog`: pinned unique ids; shares sum to 100; 0%, partial, finished below 100% (58.5%), exactly 100%, never above 100%; duplicates count once; growth changes the denominator and keeps earned ids; ids are stamped on the world.
- `_test_run_save_file`: migration from no progress, write and reload, best time, New Run keeps records, damaged file uses the backup, newer format untouched, partial data completed, outside OTA storage.
- `_test_run_timer_live`: starts at play, advances in play, paused by the pause menu and in the background, saved when backgrounded, Diagnostics, HUD timer toggle, pause menu and title.
- `_test_run_continue`: a real relaunch (from an exported pack, pass `--pack=<its file>`). A child process plays (clears a parasite, returns a mote, finds a bloom and a cave) and saves. A second child continues: same run and ids, timer continues, restoration, cleared things, cave and health all restored, resumed at the last bloom, and the timer keeps running.
- `_test_timer_integrity`: the timer keeps running through death and respawn and through vortex travel, and an unfinished run records no best finish.
- `_test_resume_points_safe`: every bloom is a safe place to re-form, using the real death and respawn (no hit within the first seconds, no slide).
- `_test_all_clear`: the run finishes when every ball is restored; the finish time stays frozen after more play and is on disk; ALL CLEAR shows it.
