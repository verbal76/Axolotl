# Steam Deck / Steam Machine (owner, 2026-10-11)

Mote is being prepared for Valve's Steam Deck and Steam Machine compatibility review. Owner decisions:
a native Linux x86_64 build; no Steamworks yet (no Steam App ID registered), so every requirement is met
with built-in tools and Steamworks can slot in later; the controller work is shared with the phone game.

| Requirement | How Mote meets it | Where | Proof |
|---|---|---|---|
| Controller: default configuration reaches all content, no setting needed | Gameplay already reads named actions (keys + pad: move, look, jump, swipe, lunge, skill, menu, whole-ball view). On a computer, or with a pad connected, the game starts in controller mode. Every menu page is navigable by d-pad / left stick with A to choose and B to go back (`PadNav`: first press focuses the page's first button, a page that opens takes the focus, B presses the page's own back control, never quits from the title, and stays the Lunge in play). The aquarium room has a **Look closer** button with a controller; inspection looks round with the sticks; the live tank keeps its buttons; the colours page turns Gill with the right stick. | `scripts/ui/pad_nav.gd`, `scripts/core/settings.gd`, `scripts/ui/presentation_ui.gd`, `scripts/ui/gill_page.gd` | `deck_every_page_reachable_by_controller` (title, players, settings, colours, skills, field guide, about, aquarium: every focusable control reached from the focus by d-pad), `deck_b_on_title_never_quits`, `deck_b_in_play_is_lunge`, `deck_aquarium_look_closer_by_controller` |
| Glyphs match the input in use; no keyboard/mouse glyphs from Deck inputs | Drawn glyphs, by family: Deck / Steam Controller (SteamOS sets `SteamDeck=1`; Steam's virtual pad): monochrome A/B/X/Y with View and Menu icons; Xbox: coloured letters; PlayStation: cross/circle/square/triangle. The button comes from the input map, so a glyph always names the button that works. In controller mode the touch HUD hides and lesson prompts become a glyph + label row. Mote never shows keyboard or mouse glyphs; the Deck's trackpad (mouse) never changes the mode. | `scripts/ui/glyphs.gd`, `scripts/ui/hud.gd` | `deck_glyph_families`, `deck_glyphs_follow_input_map`, `deck_prompt_glyph_row_on_screen` |
| Text input with only a controller | A built-in controller keyboard under the name box (digits, letters, ' - . !, Shift, Space, Delete, Done; X deletes, Y types a space). | `scripts/ui/on_screen_keyboard.gd`, `scripts/ui/players_page.gd` | `deck_controller_keyboard_types_a_name` |
| Performance: 30 fps at 800p by default | Mobile renderer (the phones' renderer) at native 1280x800, the quality scaler steps down if the frame rate drops. **Not yet measured on a Deck.** | `scripts/core/quality_scaler.gd` | needs a Deck |
| No device warnings, no launcher | Mote starts straight into its studio splash and title; it never inspects the OS or GPU to warn. | | |
| Resolution 1280x800 | Base canvas 1280x720 "expand": at 1280x800 the UI draws 1:1 and the extra height is used. | `project.godot` | renders `--test=shots --only=deck` with `--resolution 1280x800` |
| Text at least 9 px (12 px recommended) at 1280x800 | Smallest text on every page is 13 px (vitality bar labels); menus 17 px and up. | | `deck_text_at_least_12px` |

## The Linux build

`.github/workflows/desktop-build.yml` exports a native Linux x86_64 build with the game embedded, smoke-
runs it, and publishes a `.tar.gz`. Started by a push that changes `.github/desktop-build-request.json`
(`{"sha": "<commit>"}`) or by hand. The Linux export preset is written into `export_presets.cfg` inside
that run only: the committed file belongs to the Android runtime lock (r5). Desktop builds have no OTA
client (Boot runs it only with the Android `ota` feature); Steam will deliver their updates.

Sideloading on a Deck: Desktop Mode, extract, Steam > Add a Non-Steam Game > `Mote.x86_64`, then play from
Game Mode.

## When Mote has a Steam App ID

- GodotSteam (GDExtension) for Steam Input glyphs (`ISteamInput::GetGlyphPNGForActionOrigin`) and Steam's
  gamepad text entry (`ShowGamepadTextInput`), replacing `Glyphs` and `OnScreenKeyboard` where available.
- A Steam Input action manifest (in-game actions) so players can rebind in Steam.
- Depot and launch options for the Linux build.
