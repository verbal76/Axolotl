# Onboarding: authoritative design (owner, 2026-10-01)

Ledger row 20. The owner's design text is reproduced VERBATIM below and is authoritative. It replaces
an interim draft the build session wrote before this text arrived (that draft is void).

Onboarding scope is CLOSED: nothing beyond the four items below without a newly identified
player-understanding problem.

Owner rulings with it:

- The intro shows on the FIRST NEW RUN EVER only, and stays seen across New Run.
- Do not redesign this spec. Record it durably.
- Implement it at its queued position: second in the train, right after the Skills-page fix.

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

## Implementation notes (build session; must stay consistent with the text above)

- **Persistence:** four independent flags (`intro`, `feeding`, `parasite`, `starfish`) in the profile
  store that survives New Run (`gill_progress`), saved with its existing backup and recovery. New Run
  never clears them.
- **Migration:** existing saves infer completed lessons only where progress proves them:
  - any saved or finished run, or any Ball 1 progress past the tutorial parasite: `intro`, `feeding`,
    `parasite`;
  - any starfish collected or skill bought: `starfish` (and `intro`).

  Nothing else in any save is touched.
- **The empty frond:** only while `feeding` is not done, at the start of the first-ever run.
  - One currently UNLOCKED frond starts empty, never a dormant/locked frond.
  - Later runs never remove health to replay it.
- **The existing Ball 1 tutorial:** audited and consolidated so that its Tail Swipe and Lunge prompts
  become the lessons' objective prompts, not duplicates.
  - Move, Jump and Water Burst stay.
  - Its parasite healing / bloom step is the parasite lesson's restoration.
- **Determinism:** presentation draws no gameplay random numbers and changes no simulation result. A
  test switch marks every lesson done for tests and bots that are about something else.

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
