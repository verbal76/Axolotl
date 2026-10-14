# Device checklist (what only real hardware can confirm)

Automated tests run headless on Linux with a dummy audio driver and no GPU. These checks need a person
with the device. Record: device, Android/OS version, build (About shows the OTA revision and runtime),
date, pass/fail, and a note for any fail. Nothing here has been done yet unless a row says so.

## Android phone (owner's Pixel first, then one other phone)

Install over the current app (build 132 / r5) so saves carry over; then take the OTA under test.

| # | Check | Pass when |
|---|---|---|
| A1 | Launch: splash, title, Continue | Hot Attic Games splash first, then the title; Continue lands where the run was saved |
| A2 | Music and ambience | Songs play and alternate; the aquarium bubbling and aerator hum fade in at launch and sit under the music |
| A3 | Positional sounds | Footsteps, tail swipes and hits come from the right side as the camera turns; a bubbler or vortex rush gets louder walking towards it and fades walking away (no sudden cut, no click) |
| A4 | Tunnel travel | The whoosh starts on entering a vortex and fades out on arrival |
| A5 | 15 minutes of normal play | No crash, no audio dropout, no stutter that was not there before |
| A6 | Background and resume, 5 times | Home button mid-play, wait 10 s, return: game paused/resumed as before, music and ambience come back, no burst of sound, run time did not count the away time |
| A7 | Lock screen while playing, then unlock | Same as A6 |
| A8 | Headphones (wired or Bluetooth) plugged in / connected mid-play | Sound moves to them; left/right correct |
| A9 | Settings at the phone's own resolution, during a finished run with abilities (fullest page) | Every control visible without scrolling, nothing overlaps, the run line readable |
| A10 | Settings with a controller connected | Status line one line; Button prompts and About reachable with the d-pad |
| A11 | Return to title and New Run, 3 times each | No crash; sound continues correctly after each |
| A12 | Battery/heat over 15 minutes | No noticeable change from the previous build |

## Windows PC

| # | Check | Pass when |
|---|---|---|
| W1 | Launch Mote.exe from the numbered build's EXE.zip | Starts fullscreen; F11 / Alt+Enter toggles windowed |
| W2 | A2-A5, A9-A11 above | Same results |
| W3 | Unplug/replug the audio device mid-play | Sound returns on the new device, no crash |

## Steam Deck

See docs/STEAM_DECK.md for the Deck-specific list (controls, glyphs, on-screen keyboard, 1280x800,
suspend/resume); also run A2-A5 and A9-A11 above.
