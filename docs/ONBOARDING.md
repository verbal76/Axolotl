# Onboarding: context, three first-discovery lessons, then trust the player

Owner brief, 2026-10-01 (ledger row 20). **Scope is CLOSED**: no further tutorial systems or onboarding
popups without a newly identified player-understanding problem.

Philosophy:

- **Context:** this is Gill's home. Parasites damaged it. Help restore it.
- **Survival:** eat food to heal Gill.
- **Restoration:** defeat parasites to bring the environment back to life.
- **Progression:** collect Red Starfish to develop Gill's abilities.

Then trust the player. Teach only the things a new player cannot reasonably understand just by
looking. Vortices, Motes, caves, food varieties, health upgrades, Treasure Hunt, later abilities and
completion systems are learned through play and are never explained here.

The existing Ball 1 control prompts (Move, Jump, Water Burst, Tail Swipe, Lunge) stay as they are.
Onboarding adds what follows and nothing else.

## 0. Intro screen (a new run)

When the player starts a genuinely NEW run (Play with no saved run, or New Run), one short screen
appears before play begins. It uses the Mote visual language, is landscape-safe, has no scrolling and
has one large action:

> **THIS IS GILL'S HOME.**
>
> Parasites have infested the aquarium and damaged the moss balls he lives among.
>
> Help Gill clear them out and bring his home back to life.
>
> **[ Begin ]**

It is not a lore scene, cinematic, quest briefing or tutorial page.

- **When it shows (owner ruling, 2026-10-01):** on every new run until the player has completed all
  three lessons below. After that it never shows again, for any later run.
- Continue (resuming a saved run) never shows it.

## The three first-discovery lessons

Each lesson happens once: the first time its trigger occurs on a profile whose lesson is not yet
done. After that, the same event plays at normal gameplay speed, with no camera move and no popup.

### 1. First food or jellyfish: health fronds

- **Trigger:** the first food catch while at least one unlocked health frond is empty.
- **Fallback:** if Gill is at full health, the lesson waits for the first catch that heals.
- The player learns feeding by doing it (the existing Lunge prompt).
- **Staging:** the camera moves close to Gill, and the player watches one empty, unlocked frond
  restore from grey/dim to healthy colour and light.
- **Message (one line):** Gill's glowing fronds are his health. Food restores them. **[ Got it ]**
- **Teaches:** the visible fronds are his health.

### 2. First parasite: restoration

The player is introduced to the parasite, taught the real Tail Swipe control (the existing "swipe"
prompt), and must defeat it.

When that first parasite dies:

1. The kill registers normally.
2. The exact restoration amount and state this kill legitimately produces are preserved.
3. Instead of the normal fast restoration visual, the same result is staged slowly. The camera pulls
   up and out from Gill, keeping him visible while framing enough of the damaged area that the change
   can be seen clearly.
4. The restoration propagates outward through that area slowly enough to follow. Grey/dead turns to
   healthy green, and the player sees the vegetation respond and return as the restored area reaches
   it.
5. When it finishes: **DID YOU SEE THAT?** Removing parasites lets the moss recover. **[ Got it ]**
6. The camera returns smoothly to normal play.

This is **presentation only**. There is no extra restoration, no change to completion math, parasite
rewards, restoration radius or progression, no permanent slowdown, and no special larger event. The
health state changes exactly as it would without the lesson; only its first visual presentation is
paced.

### 3. First Red Starfish: skills

- **Trigger:** the first starfish pickup. This lesson is informational only, with no camera staging.
- **Message:** Red Starfish buy new abilities for Gill. Spend them in Skills, from the Main Menu or
  Settings. **[ Got it ]**

## Shared infrastructure

- **Persistence:** one "done" flag per lesson, plus the intro rule above. The flags live in the
  profile store that survives New Run (with the skills and starfish, `gill_progress`), not in the run
  save, so a lesson is never repeated on a later run.
- **Migration:** an existing profile with progress counts the matching lessons as done:
  - any starfish collected or skill bought: lesson 3;
  - a saved or finished run that is past the Ball 1 tutorial: lessons 1 and 2.

  Experienced players are not re-taught. A brand-new profile starts with nothing done.
- **Soft-lock protection:**
  - A staged moment never takes control indefinitely: each has a hard time cap and ends cleanly if the
    run is paused, Gill dies, the player leaves the ball, or the app is backgrounded.
  - Input is restored on every exit path.
  - A lesson interrupted before its message is marked done once the underlying event has happened.
    The game state is already correct, so it is never replayed and never blocks.
  - Pause works throughout. The **Got it** card is a single large touch target.
- **Determinism:** the staging draws no gameplay random numbers and changes no simulation timing
  (the parasite kill, health and completion are applied immediately and identically). Recordings,
  bots and playthroughs see the same state.
- **Bots and tests:** the playthrough bots dismiss cards like a player would. A test switch can mark
  every lesson as done.

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
