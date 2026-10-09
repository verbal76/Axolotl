# Onboarding: authoritative design (owner, 2026-10-01)

Ledger row 20. The owner's design text is reproduced VERBATIM below and is authoritative. It replaces
an interim draft the build session wrote before this text arrived (that draft is void).

Onboarding scope is CLOSED: nothing beyond the four items below without a newly identified
player-understanding problem.

Owner rulings with it:

- The intro shows on the FIRST NEW RUN EVER only, and stays seen across New Run.
- Do not redesign this spec. Record it durably.
- Implement it at its queued position: second in the train, right after the Skills-page fix.

## Owner ruling, 2026-10-01 (later): ONCE PER RUN, with an off switch (supersedes "first new run ever" and "once per profile")

- The intro and the three lessons happen **once per run**: every new run, while tutorials are on.
- **Settings has a "Tutorials" on/off toggle** (title and in-run Settings). It is on by default for
  everyone, existing players included. Off skips the intro and all three lessons.
- The **empty frond** is per run too: each new run starts with one unlocked frond empty, only while
  tutorials are on. With tutorials off, a run starts at full health.
- The Replay tutorial button is removed; the toggle replaces it.
- A run already in progress when this ships (Continue) counts its lessons as done, so nothing
  appears mid-run. The next new run plays them.

The verbatim text below still defines what each lesson does; where it says "first-ever", "once", or
"stays seen across New Run", this ruling wins.

## Owner text (verbatim)

```
==================================================
ONBOARDING PHILOSOPHY
==================================================

Mote teaches only the three things a new player cannot reasonably understand just by looking, then trusts the player.

CONTEXT:
This is Gill's home. Parasites damaged it. Help restore it.

SURVIVAL:
Eat food to heal Gill.

RESTORATION:
Defeat parasites to bring the environment back to life.

PROGRESSION:
Collect Red Starfish to develop Gill's abilities.

No broader tutorial system is authorized.

==================================================
FIRST-EVER INTRO
==================================================

On the player's first genuinely new run only:

THIS IS GILL'S HOME.

Parasites have infested the aquarium and damaged the moss balls he lives among.

Help Gill clear them out and bring his home back to life.

[ Begin ]

Short Mote-styled screen. No lore dump, scrolling, quest briefing or cinematic.

Do not explain vortices, Motes, caves, food varieties, health upgrades, Treasure Hunt, later abilities, completion systems, etc.

Once seen, it stays seen across New Run.

Existing experienced saves should be migrated sensibly as already-seen.

==================================================
FIRST FOOD / JELLYFISH — INTERACTIVE
==================================================

Trigger when the intended first little food/jellyfish is genuinely visible, not merely spawned somewhere.

A new player begins this tutorial with ONE CURRENTLY UNLOCKED health frond intentionally empty/gray.

Do not confuse this with Gill's genuinely dormant/locked health fronds.

Briefly teach the REAL current feeding/lunge control.

Objective:
EAT THE JELLYFISH

The player must actually catch/eat it before the lesson completes.

Do not immobilize Gill. Allow movement, camera, aiming, misses, repositioning and retries.

Prevent bypassing the lesson, and make the target recoverable so it cannot wander, despawn, clip or otherwise soft-lock the tutorial.

On successful eating:

- register feeding normally;
- defer the visible health-frond restoration momentarily;
- smoothly move the camera into a close view of Gill;
- clearly frame the health fronds;
- THEN visibly restore the gray/dim unlocked frond to healthy color/light while the player is watching;
- briefly explain that food heals Gill and these visible fronds represent his health;
- smoothly return the camera;
- resume normal gameplay.

The player should learn by WATCHING the health indicator change.

After this lesson has been completed once, feeding behaves normally forever. Do not remove health at the start of later runs merely to replay it.

==================================================
FIRST PARASITE — INTERACTIVE
==================================================

When the intended first parasite is genuinely visible, briefly identify it and teach the REAL current Tail Swipe control.

Objective:
DEFEAT THE PARASITE

Require the player to actually attack and kill it.

Allow movement, camera, positioning, attacks, misses and retries. Prevent bypassing the lesson and make the encounter impossible to soft-lock.

On the tutorial parasite's death:

- register the legitimate kill/restoration normally;
- preserve EXACTLY the restoration amount/state the kill should produce;
- do not immediately show the normal fast restoration;
- smoothly move the camera upward/outward while keeping Gill visible;
- frame the surrounding damaged area;
- slowly PRESENT the legitimate restoration spreading through that area;
- let the player visibly watch gray/dead moss become healthy/green;
- visibly show affected vegetation/plants return as restoration reaches them.

Then briefly:

DID YOU SEE THAT?

Removing parasites lets the moss recover.

[ Got it ]

Return camera and normal gameplay.

This is presentation only. Do NOT award extra restoration, change completion math, increase radius, change rewards or permanently slow restoration.

Every later parasite uses normal gameplay presentation.

==================================================
FIRST RED STARFISH — INFORMATIONAL
==================================================

First-ever Red Starfish collection:

RED STARFISH FOUND!

Gill found a Red Starfish!

Spend Red Starfish on new abilities in the Skills tab, available from the Main Menu or Settings.

[ Got it ]

Informational only. No mandatory gameplay demonstration.

==================================================
PERSISTENCE / MIGRATION
==================================================

Use lightweight reusable first-discovery infrastructure, not three unrelated hacks and not a giant tutorial framework.

Persist independent seen/completed state for:
- intro;
- feeding/health lesson;
- parasite/restoration lesson;
- Red Starfish discovery.

Once genuinely learned, these should not become mandatory again on every New Run.

Existing saves must migrate safely. Infer already-completed lessons where existing progression clearly proves the player has done them.

Never reset or damage:
- run progress;
- completion;
- skills;
- starfish;
- permanent progression;
- saves.

==================================================
SOFT-LOCK PROTECTION
==================================================

Interactive lessons must remain completable through:
- repeated misses;
- unexpected movement;
- target movement;
- awkward geometry;
- damage;
- allowed UI;
- background/resume;
- close/reopen;
- save/load;
- normal despawn/repopulation conditions.

There must always be a valid route to completion.

Do not make Gill feel frozen. Lock the tutorial objective, not ordinary control needed to perform it.

==================================================
PRESENTATION
==================================================

Use established Mote styling:
- rounded shaded panels;
- landscape-phone safe;
- no scrolling;
- world dimmed behind explanatory panels;
- large touch targets;
- no gameplay input leaking through UI.

During interactive portions, remove the large panel and use only a small objective/prompt so gameplay remains visible.

==================================================
SCOPE CLOSED
==================================================

Only these are authorized onboarding:
- first-ever home/context intro;
- first feeding + health-frond visual lesson;
- first parasite + restoration visual lesson;
- first Red Starfish explanation.

Do not add tutorials for every mechanic.

Integrate cleanly with Ball 1's EXISTING Move / Jump / Water Burst / Tail Swipe / parasite healing / bloom tutorial rather than stacking duplicate or contradictory teaching. Audit that existing sequence and consolidate where necessary.

Record this authoritative design durably so it cannot disappear between sessions again.

Then implement it at its queued position without disturbing anything already publishing, using Rule 7 minimum-sufficient evidence.

Continue the autonomous train afterward.
```

## Holistic tutorial pass (owner, 2026-10-08): the whole teaching flow

Authoritative for teaching from 2026-10-08. The lessons above stay; this pass makes them one flow,
fills the gaps the playtests found (prey, Motes vs food, spitters), and guarantees nothing is lost.

### Player-knowledge map

| Concept | Class | Taught by |
|---|---|---|
| Gill's home, parasites infest it | A: card | Intro (new run) |
| Move, camera, jump, burst | B: prompt | HUD button pulses at the moment of use |
| Fronds = health; food heals; lunge eats | A: staged | Feeding lesson (EAT THE SHRIMP, frond close-up, card) |
| Lunge homes in on food ahead | B: prompt | Lunge prompt during the feeding objective; Field guide |
| Parasites hurt; Tail Swipe defeats them; removing them heals the moss | A: staged | Parasite lesson (DEFEAT THE PARASITE, moss reveal, card) |
| Motes heal the moss, are not food | A + C | Parasite card's 2nd line; first-encounter name; Field guide |
| Spitter globs: Tail Swipe bats them back | B + C | First-encounter name; glob hint (SWIPE TO BAT THE GLOB BACK + swipe prompt) |
| Last frond: eat to heal | B | Low-health hint (LAST FROND: EAT FOOD TO HEAL + lunge prompt), once |
| Food kinds (shrimp, water flea, worm) | C | First-encounter names; Field guide |
| Species (shoal, snail, stalker ...) and what they are to Gill | C | Species discovery note now carries a role ("Harmless", "Threat") |
| Red Starfish -> Skills | A: card | Starfish card |
| 70% restored opens tunnels; pad green = ready; tunnel colour = destination | A + B | Tunnel card; pads; Field guide |
| Ravine ooze is deadly | D/C | Field guide (the ravine cinematic shows it) |
| Pearls | (reserved) | Field guide keeps a mystery entry until one is found; never taught as food |
| Aquarium, colours, Treasure Hunt, Hard Mode, Tier-2 | D | Discoverable in menus; Tier-2 has its own discovery note |

A = must be taught explicitly (card / staged), B = contextual hint near the moment of use,
C = first-encounter identification, D = discoverable, no teaching.

### Flow and rules

- Order on a new run: Intro -> (first shrimp in view) feeding -> (first parasite in view) parasite ->
  starfish / tunnel when they happen. Names and hints never appear over a lesson, its objective or
  a card; species notes and names queue (never overwrite each other).
- **Never lost (reliability):** a lesson's moment is recorded when it happens (never staged twice),
  but its card is OWED (`owed.<lesson>` in the run's lesson record) until it has really been on
  screen. An owed card comes back alone, without the camera, after `CATCH_UP_S` (6 s) of calm play
  (normal play, no objective or hint, nothing hostile within 8 m). The tunnel's catch-up waits for
  owed cards. First-encounter names and hints are marked `seen.<key>` only when shown.
- Tutorials off: no lessons, no names, no hints, nothing owed comes. The Field guide is always there.
- Copy: FEED/KILL texts from the prey pass are kept and reconciled (the KILL card says Motes help the
  moss and are not food); no other card text changed.

### Field guide

Pause menu (in play and from the title): "Field guide", half-width beside the colours. One page, two
columns, nothing to scroll or earn: fronds, food, Motes, restoring the moss, parasites, spitters,
ravine ooze, water tunnels, Red Starfish, Pearl (a mystery until one is found).
`FieldGuidePage`; tests `guide_*` in `onboarding_tests.gd` (`_test_onb_guidance`); renders
`--test=shots --only=guide`.

## Implementation notes (build session; must stay consistent with the text above and the ruling)

- **Persistence (once per run, ledger row 24):** four independent flags (`intro`, `feeding`,
  `parasite`, `starfish`) in the RUN save (`run.onboarding`, `RunSave.lessons`), plus `frond` while
  the run's empty frond still waits for the feeding lesson. Each flag is written the moment its
  event happens (an interrupted lesson is never replayed in that run). Continue keeps the record;
  New Run (and Play with no saved run) starts a run with an empty record, so it plays them again.
- **Tutorials toggle:** `Settings.tutorials`, saved in `settings.cfg` as `[onboarding] tutorials`.
  Absent (every file from before it) reads as on. Shown in Settings from the title and in-run. Off:
  every lesson reads as done without being marked, so no intro, no lesson and no empty frond. Turned
  off mid-run, an objective or staged lesson ends at once through the normal clean exit (end reason
  "off"). Turned back on mid-run: no intro; this run's lessons not yet done may still come.
- **Runs from before the record:** a run in progress with no `onboarding` record counts every lesson
  as done (no lesson mid-run, no frond emptied); the record is filled in as all done. The next new
  run plays them. Old run saves are never given an empty record by migration.
- **Profiles from the once-per-profile builds:** their `onboarding` / `onboarding_epoch` keys load
  harmlessly, are kept as they were and are no longer read. Nothing new is written to the profile.
  Replay tutorial and its reset epoch logic are gone.
- **The empty frond:** at the start of each new run while tutorials are on, and kept empty on Continue
  until the feeding lesson. One currently UNLOCKED frond, never a dormant/locked frond. Off: full
  health.
- **The existing Ball 1 tutorial:** audited and consolidated so that its Tail Swipe and Lunge prompts
  become the lessons' objective prompts, not duplicates.
  - Move, Jump and Water Burst stay.
  - Its parasite healing / bloom step is the parasite lesson's restoration.
  - With tutorials off (or the lessons done in this run), its own Tail Swipe and Lunge prompts show
    as before.
- **Determinism:** presentation draws no gameplay random numbers and changes no simulation result. A
  test switch (`--onboarding=done|fresh|player`) marks every lesson done for tests and bots that are
  about something else (`done`, the unit-test default), gives a new run's lessons (`fresh`, the
  playthrough default) or does exactly what a player's launch does (`player`).

## Qualification (rule 7)

- **Impact map:** the title/new-run flow, HUD cards, the camera, the restoration presentation, food
  and frond visuals, starfish pickup, and the profile store migration.
- **Level:** L3. It touches persistence and the first minutes of every new player.
- **Required evidence:**
  - Unit tests for the lessons' triggers, once-only behaviour, the intro rule, migration of an
    existing profile, and the soft-lock exits (pause, death, ball change, time cap).
  - A test that the first-parasite kill's restoration state equals the same kill without staging.
  - The seed-7 playthrough locally. The publish gate runs the seed-4242 playthrough and the full suite.
  - Landscape renders of the intro screen and each card at 1280x720, 1600x720 and 2000x900, plus
    frames of the parasite restoration staging.
