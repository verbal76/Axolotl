# The ecosystem: creatures of the seven moss balls

Expansion 5 of the Mote open-items list. The goal: an aquarium that feels inhabited, where
different places hold different life and the threats ask for different reactions. It does not
just add more enemies.

## Audit: what lived here before

| Mover | Role | Behaviour |
|---|---|---|
| Parasite (small, medium, large) | the only threat | crawls its home area; notices the axolotl within about 6.5 m; chases; winds up; lunges (1 damage). The three kinds differ only in size, numbers and reach |
| Food (drifter, darter, burrower) | prey | hovers or hides; darters flee; burrowers duck into holes. Heals |
| Mote | collectible | drifts; caught with the lunge |
| Tank snail | decoration | on the gravel outside the balls |

**Gaps:**
- One hostile behaviour.
- No ambient life on the balls.
- Nothing in the caves.
- Nothing on the leaves, shelves, ridges or spire.
- Nothing that used the tall reeds or the dark.
- Every creature on the current ball simulated at every distance.

## Design (owner decisions)

The owner chose four threats and four kinds of ambient life, with completion by species discovered
plus significant threats defeated. Defeated guardians and eels stay defeated; stalkers return
after a while; ambient life is never saved.

| Creature | Role | Habitat | How it behaves | What the player does |
|---|---|---|---|---|
| **Reed stalker** | hidden hunter | tall reeds (Mossy Meadow reed bed, Reed Canyon floor ×2, Giant Stems far jungle) | Prowls low in its patch, lower than the reeds. Stalks him a few metres off when he is in its patch. Then rears and hisses while the reeds thrash (0.9 s), and pounces along the line it locked. Lies low afterwards. Gives up when he leaves the patch | Watch the reeds. Sidestep the pounce, strike while it lies low (2 hits), or leave its patch. Driven off, it returns after 2 minutes |
| **Crab guardian** | territorial | grotto mouths (Terrace Steps, Reed Canyon, Hollow Grotto) | Rests at its post. When he enters its territory (5 m) it faces him, raises its claws and clacks (1.2 s). If he stays within 3.8 m it charges sideways; only the charge hurts. Never leaves its territory, and walks back to its post | Back off after the warning, or fight it: 3 hits, sidestep the charge. Beaten, it stays beaten (a completion entry) |
| **Cave eel** | ambush | grotto walls (Current Hollows, Reed Canyon, Hollow Grotto ×2) | Hidden in a dark cleft, eyes faintly glowing. When he is near, in front and in its line of sight, its eyes brighten and bubbles rise (0.9 s), then it strikes up to 2.3 m and pulls back. It never leaves the crevice; the strike stops short of rock or a ledge; it never notices him through the wall | Read the bubbles and step out of reach, or swipe it while it is out (2 hits). Beaten, it stays beaten (a completion entry) |
| **Pufferfish** | avoid | open water at jump height over ridges and open ground (Current Hollows ×2, Terrace Steps, Reed Canyon, Hollow Grotto) | Drifts slowly (the current carries it on Current Hollows). Calm, it is an elongated spotted fish with fins. Near him it puffs up over 0.6 s into a round ball, its spines standing out, and stays puffed a while | Go round it or wait for it to drift clear. Touching it puffed hurts; a swipe only bats it away |
| **Shrimp shoal** | ambient | open moss and terraces (7 shoals of 9) | Graze and flick about together, drifting round their patch. Scatter in all directions when he rushes at them; drift back together | Life to run through |
| **Canopy snail** | ambient | leaves and shelves: the Giant Stems canopy and jungle ladders, the Canopy Spire, shelves, the arch top (17) | Creeps back and forth along its leaf; tucks into its shell when he comes close | Life up high |
| **Leaf hopper** | skittish | climbs: the Giant Stems canopy spiral and three jungle ladders, the Canopy Spire, the terraces (6) | Springs one or two steps up its climb whenever he comes near, then waits at the top and leaps back down | Following it shows the way up |
| **Cave glow-worms** | ambient | every grotto ceiling (7 colonies of 48) | Lights on silk threads. The nearest ones dim and draw up as he passes, and brighten behind him | Caves feel inhabited; the glow marks the ceiling |

**Readability and fairness rules** (all tested):
- Every threat telegraphs before it can hurt, with a visible and audible cue: the crab's claws and
  clack, the eel's eyes and bubbles, the stalker's rearing, hiss and thrashing reeds, the puffer's
  puffing up.
- Each threat hurts only in its attack phase, once per attack. The axolotl's invulnerability after a
  hit prevents chained damage.
- Nothing strikes or notices through rock.
- No threat can reach a bloom's respawn point or a vortex arrival point.
- The stalker pounces along a line locked when its telegraph starts, so a sidestep avoids it.

## Parasites (Expansion 6 addendum: combat)

The parasites are the main recurring enemy. Before this pass, all three sizes shared one
routine: notice, chase, wind up, lunge. Each size now fights its own way (`scripts/actors/parasite.gd`).

| | How it fights | Telegraph (posture, sound, timing) | Afterwards |
|---|---|---|---|
| **Small** | Rushes in with darting bursts and a zig-zag, and commits quickly. Its bite latches on for a moment | rears up, the wind-up chirr, 0.45 s | a short recovery; never flees |
| **Medium** | Closes to a wary distance, then circles him for a better angle (his side or back) before committing | rears up, the wind-up chirr, 0.6 s | recovers, then may circle again |
| **Large** | A heavy committed charge along the line it locked: 4.4 m in 0.6 s, stopped by rock or a drop | coils (the body shortens), rears high, scrapes the moss, a low grinding swell, 1.1 s | spent: head low, a 1.5 s recovery (the time to hit it) |
| **Spitter** (four mediums, in the far zones of balls 2–5) | Keeps 3–7 m off, backing away and sidling. It spits a slow glowing glob (5 m/s, no homing), and bites if cornered | faces him, rears and swells, a bubbling gurgle, 0.85 s | 2.6 s before it spits again |

- **Retreat and recovery.** A timid medium or large (about two in three) hurt to half its
  vitality breaks off after the blow's knockback. It flees faster than it crawls, never beyond its
  own territory (it runs along the edge instead), for up to 4 s or until clear, and stays wary a
  little while (it notices him later). Left alone for 10 s, it regains one stage, once. So you
  can chase it down, or let it go and face it at 1 stage again.
- **Pack alert.** A parasite that sees him alerts grazing neighbours within 8 m whose territory he
  is in (the alert chitter). Only a parasite that saw him itself raises the alarm, so it never
  chains across the ball. Joiners come in from their own side (40–70° round him), and engaged
  parasites shuffle apart instead of stacking.
- **Fair by construction.** At most two attacks are committed at once on a ball (a glob in flight
  counts as one), and attack starts are at least 0.4 s apart. The others hold just out of reach.
  After any hit the axolotl's invulnerability still prevents chained damage. Every attack has a
  telegraph of 0.45 s or more.
- **Sight.** A parasite notices him only in line of sight over the terrain (two rays, low and high).
  It never notices him through rock, and gives up when he has been out of sight for 1.5 s
  (2.5 s when alerted). Spitters never fire from off-screen. Globs splat on rock, moss and
  plants.
- **Respawn and blooms.** The bloom's pulse startles parasites off a re-forming axolotl, and they
  hold off attacking for 3.5 s. Grazing and fleeing parasites keep 2.2 m off blooms.
- **Glob deflection.** A tail swipe that meets a glob bats it back at the spitter (1.5× speed),
  where it hurts the spitter.
- **Body.** The continuous body sells each move. It coils during a wind-up and stretches in a lunge
  or charge, the charge's momentum runs down the body, it perks up at the alarm, it runs long and
  low in flight, and its head drops when spent. Death still goes to the twitch and limp drift.
- **Determinism and cost.** Every choice (brave or timid, circling side, circle length, flank)
  comes from the parasite's own generator, seeded from where it lives. Only parasites on his ball
  run. Sight is checked 5 times a second and only when he is within 12 m. Measured cost is about
  40 µs per engaged parasite per frame (desktop).
- **Completion unchanged.** Spitters are existing parasites with their ids. Retreat, recovery,
  alerts and deflections earn nothing and are never required.

Tests: `_test_parasite_combat` (25 checks). Each size's behaviour; the dodges (a sidestep from the
charge and from a glob); the retreat threshold, boundary and recovery; the alert reaching near
neighbours and not far ones; a group spreading round him within the attack budget; the spitter's
telegraph, dodge window, deflection, terrain stop and never firing off-screen; never noticing
through rock; blooms not camped; determinism; the charge stirring the plants; a fleeing
parasite's death; cost.

## Look (Expansion 6)

The owner reviewed each creature against reference photos. Each was remodelled so it reads as the
animal. Their behaviour, collision and timings are unchanged.

| Creature | Before | Now |
|---|---|---|
| Crab guardian | a smooth red balloon | a wide serrated carapace with a dark speckled dome, a red rim and a cream underside (`shaders/crab_shell.gdshader`); eight jointed legs, pincer claws and eye stalks. It flashes when hit |
| Pufferfish | a sphere that grew | one mesh with two shapes (`shaders/puffer_body.gdshader`). Calm, an elongated tan porcupinefish with spots, fins, eyes and lips, its 170 spines lying flat. Puffed, the body morphs onto a sphere and the spines stand straight out |
| Cave eel | a chain of beads | a moray: one continuous spotted body on the parasites' body shader, with a heavy head and a jaw. It sits in the grotto wall on the side away from the ledges, so its strike guards the floor and never knocks him off the optional climb |
| Burrowers (food) | hollow, clipped shapes on the sand | garden eels: a spotted, curled body rising out of a sand mound with a dark hole, swaying in the current |
| Shrimp | simple primitive shapes | arched, banded shrimp |
| Canopy snail | a simple primitive shell | a log-spiral shell with growth bands |
| Parasites | a chain of beads | one continuous tapering body with faint rings (`shaders/parasite_body.gdshader`), drawn along a smooth curve through the segments. Defeated, it twitches and goes limp, and the body drifts down as a slack, rippling curve |

## Vegetation

Movers bend the plants where they really are. The reed stalker adds wake points on its head and
mid-body (stronger while it moves, thrashing during its telegraph), so in tall reeds the plants
move before it can be seen. Crabs and scattering shrimp stir the plants too. The wake has 32 points
now (it was 24): the axolotl's 16 are unchanged, then the three nearest parasites, then up to 8
creature points, nearest first. The axolotl's own interaction is unchanged.

## Caves and high routes

- **Caves:** every grotto has glow-worms. Three are guarded at the mouth by a crab, and four have
  an eel in the wall; Reed Canyon's and Hollow Grotto's main grotto have both.
- **High routes:** snails creep on the leaves and shelves of the climbs, and hoppers spring up the
  climbs ahead of the axolotl. Both stand on the stem-ladder leaves and never walk off them.

## Architecture

| Piece | File |
|---|---|
| Creature base: activation, own random generator, hittable interface, standing and line-of-sight helpers, merged meshes | `scripts/actors/critter.gd` (`Critter`) |
| The eight species | `scripts/actors/critters/*.gd` |
| Placement by habitat, activation manager, discovery, wake gathering | `scripts/world/ecosystem.gd` (`Ecosystem`) |
| Glow-worm shader | `shaders/glow_worm.gdshader` |
| Combat, defeats, discovery toast, restoring a save | `Game._strikeable`, `critter_defeated`, `discover_species`, `_apply_run`; `Hud.show_discovery` |
| Sounds | `tools/gen_audio.py` `creatures()` (own random generator; the existing sounds are unchanged) |

**Cost:**
- Only creatures on the axolotl's ball within 38 m of him are ticked, re-checked 4 times a second;
  everything else does no per-frame work.
- Each creature's physics setup (rays onto leaves, cave walls and ceilings) happens once, on the
  first physics frame.
- Creatures are merged vertex-coloured meshes (1–4 draw calls each); shoals, glow-worms and
  segmented bodies are MultiMeshes.

**Determinism:** every creature has its own seeded random generator (ball, species, index) and
never touches the global sequence that gameplay and the test bot use (`eco_leaves_gameplay_rng_alone`).

## Completion (catalog version 3)

A new category, **Wildlife** (10% share); the other shares scale to make room (45 / 18 / 13.5 / 13.5).
The new ids are:
- `species.shrimp`, `species.snail`, `species.hopper`, `species.glowworm`, `species.stalker`,
  `species.crab`, `species.eel` and `species.puffer`, each earned on the first close look at one;
- `b4.crab.0`, `b5.crab.0` and `b7.crab.0` for the guardians defeated;
- `b2.eel.0`, `b5.eel.0`, `b7.eel.0` and `b7.eel.1` for the eels defeated.

That is 15 new ids; the catalog goes from 157 to 172. No id changed; wildlife is never needed to
finish. Finishing with nothing optional is 58.5% (it was 65%). Details in `docs/COMPLETION.md`.

## Save and load

- Defeated guardians and eels are completion ids: a continued run hides them (`restore_defeated`).
- Discovered species are ids.
- Stalkers, pufferfish and all ambient life are never saved: they are as they were placed.
- The relaunch test beats Hollow Grotto's crab, saves, relaunches and checks it stays beaten
  (counted once) while the other creatures are there (`read_creatures_restored`).

## Tests

`_test_ecosystem` in `scripts/tests/unit_tests.gd`:

| Area | Checks |
|---|---|
| World and fairness | `eco_species_in_their_habitats`, `eco_only_nearby_creatures_run`, `eco_leaves_gameplay_rng_alone`, `eco_deterministic`, `eco_no_threats_at_respawn_or_arrival`, `eco_tick_cheap` |
| Crab | `crab_warns_before_charging`, `crab_charge_hurts`, `crab_stays_in_territory`, `crab_returns_to_post`, `crab_warning_only_at_the_edge`, `crab_defeated_counts_once` |
| Eel | `eel_never_strikes_through_rock`, `eel_telegraphs_then_strikes`, `eel_stays_in_its_crevice`, `eel_defeated_while_out` |
| Stalker | `stalker_moves_the_reeds_unseen`, `stalker_telegraphs_then_pounces`, `stalker_sidestep_avoids_pounce`, `stalker_pounce_hurts_in_line`, `stalker_gives_up_outside_its_patch`, `stalker_driven_off_then_returns` |
| Pufferfish | `puffer_puffs_up_near`, `puffer_contact_hurts_once`, `puffer_batted_not_beaten` |
| Ambient life and discovery | `shrimp_scatter_then_regroup`, `snail_tucks_in_when_near`, `hopper_leads_up_the_climb`, `glowworms_react_to_him`, `species_discovered_once` |

The playthrough bot reads the telegraphs too: it sidesteps pounces, backs out of an eel's reach,
avoids puffed pufferfish and beats the crab guarding a grotto before going in.

## Performance

Measured with `--test=shots --only=perf` under a software Vulkan renderer: the same views before
(dev-000022's source, `fe3e0fd`) and after, two runs each, averaged, the axolotl walking. The frame
times are a relative proxy.

| View | Before | After |
|---|---|---|
| Ball 1 tutorial | 142 ms, 307 draw calls | 146 ms, 308 draw calls |
| Ball 1 meadow (shrimp) | 98 ms | 101 ms |
| Ball 1 reed bed (stalker) | 99 ms | 104 ms |
| Ball 2 east (pufferfish) | 92 ms | 87 ms |
| Ball 2 mesa side | 73 ms, 266 draw calls | 77 ms, 296 draw calls |
| Ball 3 jungle (snails, hoppers) | 93 ms, 198 draw calls | 89 ms, 227 draw calls |
| Ball 1 cave (glow-worms) | 90 ms | 92 ms |
| Ball 4 terraces / 5 bridge / 6 spire / 7 high shelf | 56 / 85 / 51 / 64 ms | 58 / 83 / 48 / 63 ms |
| Ball 7 grotto (glow-worms, eel, crab) | 72 ms, 121 draw calls | 73 ms, 126 draw calls |

- Video memory: +2.4 MB.
- Creature simulation: about 15 µs per frame on the busiest ball (`eco_tick_cheap`).
- The first build drew every creature part separately (+136 draw calls on ball 2); merging each
  creature's parts into one mesh brought that down to +30.
