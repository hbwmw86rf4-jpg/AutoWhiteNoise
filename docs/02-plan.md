# AutoWhiteNoise — proposed plan

## Goal (as I understand it)

A white-noise / sleep-sound app for iPhone, iPad and Mac that:
1. starts on a schedule with a chosen preset,
2. can be started by iOS automations (Shortcuts),
3. can be started by events from other people/devices in the house, chiefly "my wife woke up"
   (today the signal for that is her switching on the air purifier, which doubles as white noise),
4. only reacts inside a time window,
5. has the usual white/pink/brown noise and sleep sounds.

## Architecture in one picture

```
 Triggers (any of these)                         Player (one of these)
 ┌─────────────────────────────┐                 ┌────────────────────────────┐
 │ Shortcuts automation on MY  │── App Intent ──▶│ iPhone: app launched in    │
 │ phone (time / alarm / sleep)│                 │ background by the intent   │
 ├─────────────────────────────┤                 ├────────────────────────────┤
 │ Her phone automation        │── iMessage ───▶ │  (Message trigger → intent)│
 │ (charger off / alarm stop)  │── or LAN URL ─┐ ├────────────────────────────┤
 ├─────────────────────────────┤               └▶│ iPad/Mac "appliance mode": │
 │ Home hub automation         │── LAN URL ─────▶│ always on, own scheduler,  │
 │ (purifier / plug turns on)  │                 │ tiny HTTP listener         │
 └─────────────────────────────┘                 └────────────────────────────┘
```

Every path ends in the same place: `StartSound(preset:, fadeIn:, stopAt:)`. One code path, many doors.

## Components

1. **NoiseCore** (Swift package, shared by all three platforms)
   - Audio engine on `AVAudioEngine`: procedural white/pink/brown generators (no files, infinite, no loop
     seam) plus gapless loop playback of bundled files (rain, fan, ocean, stream, fire, crickets).
   - Mixer: up to 3 layers with per-layer volume. Master fade in / fade out. Auto-stop at a time or after
     a duration.
   - `Preset` model (Codable, synced via iCloud key-value store so all devices see the same presets).
   - `TriggerLog`: every start/stop with source (shortcut, message, LAN, schedule, manual) and timestamp,
     so "why did it go off at 3 AM?" is answerable.
   - `TimeWindow` rule: a preset can refuse to start outside its window; the window check lives in the
     app so it does not have to be rebuilt inside every automation.

2. **App Intents** (`StartSoundIntent` adopting `AudioPlaybackIntent`, `StopSoundIntent`,
   `SetVolumeIntent`, `IsPlayingIntent`). Exposed as App Shortcuts so they show up in Shortcuts, Siri,
   Action Button, Control Center and Lock Screen controls without any setup.

3. **Scheduler**
   - On Mac and in iPad appliance mode: in-process scheduler, exact times, repeats, survives sleep/wake.
   - On iPhone: the app shows the schedule, but the *trigger* is a Shortcuts Time-of-Day automation. A setup
     screen walks through creating it (and offers a one-tap "Add shortcut" link for the action part).

4. **LAN endpoint** (appliance mode only): Bonjour-advertised HTTP on a fixed port, token in the URL,
   routes `/start?preset=…`, `/stop`, `/status`. Plain enough that a Home hub, her phone, Home Assistant,
   or a browser can hit it.

5. **UI** (SwiftUI, one codebase): Now Playing, Presets, Schedules, Automations (setup wizard + log),
   Appliance mode toggle (dims screen, keeps awake, shows a clock).

## Phases

**Phase 0 — decisions** (blocked on you; questions below).

**Phase 1 — core player + intents (iPhone first).** Procedural noise, 4–6 bundled sounds, presets, fade,
auto-stop, `StartSound`/`StopSound` intents, background audio. Verify on a real iPhone that a Time-of-Day
automation starts it from a cold launch with the screen locked. This proves the whole concept.

**Phase 2 — the relay.** Setup wizard for the her-phone → my-phone iMessage relay with time window.
Trigger log.

**Phase 3 — appliance mode + LAN endpoint (iPad / Mac).** Own scheduler, HTTP listener, Home-hub recipe
for the air purifier (or a smart plug).

**Phase 4 — polish.** iCloud preset sync, widgets / Control Center controls, Sleep-timer UI, TestFlight.

## Decisions (2026-11-03)

1. **Universal app**: iPhone, iPad and Mac, so it can be started anywhere. Done in one SwiftUI codebase.
2. **The air purifier is not smart.** It was only an example of the sound wanted ("fan"). No smart-device
   trigger to wire for now; the Wi-Fi endpoint exists for later.
3. **Wife's phone**: one automation on her phone is fine. The iMessage relay is the primary "she's up" signal.
4. **Tooling**: Mac with Xcode and an Apple Developer account are available.
5. **Quick win**: Shortcuts recipes for Apple's built-in Background Sounds are in `03-shortcuts-recipes.md`.

## Status

- Phase 1 and most of Phase 2 and 3 are written: core package with 44 passing tests, app target with
  presets, schedules, automations guide, log, appliance mode, App Intents, lock-screen controls,
  Wi-Fi endpoint. First compiled on the owner's Mac on 2026-11-03 (Xcode 27.1, Swift 6.4): the
  macOS build and the iOS Simulator build both succeed with no code changes and no compiler
  warnings; the 44 core tests pass on macOS. Not yet run on a real device. See `04-build-and-install.md`.
- Not done: iCloud preset sync, widgets / Control Center controls, an app icon, recorded sounds.

## Original questions (answered above, kept for the record)

1. **What should actually make the sound at night?** Your iPhone on the nightstand, a HomePod, an old
   iPad, or a Mac in the room? (Recommendation: an iPad or Mac in appliance mode is the only setup that
   can react to the purifier directly over Wi-Fi; the iPhone-only setup works but relies on the iMessage
   relay for the "she woke up" case.)
2. **Is the air purifier a smart device?** Brand/model, and is it in the Home app? If not, are you open to
   a HomeKit/Matter smart plug under it so its power-on becomes the trigger?
3. **Is your wife OK with one automation on her phone?** It would be something like "when I unplug from the
   charger between 5 and 8 AM, send a message to <you>". Without it, the purifier/plug is the only
   "she's up" signal.
4. **Tooling:** do you have a Mac with Xcode and an Apple Developer account? Nothing here can be built or
   installed on a device without them. Free accounts can sideload for 7 days at a time; the $99/yr
   program is needed for TestFlight and for App Intents to behave identically to the store build.
5. **Quick win now, independent of the app:** Apple's built-in Background Sounds plus the automations in
   `01-what-apple-allows.md` can solve the basic case this week. Do you want the shortcut recipes for that
   while the app is being built? It doubles as a test of the trigger plumbing.
