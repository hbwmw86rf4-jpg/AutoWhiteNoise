# What Apple actually lets us do (researched 2026-11-03)

This is the ground truth the whole design rests on. Each line says how sure we are.

## The one rule that shapes everything

**An iOS/iPadOS app cannot wake itself up at a chosen time and start playing audio.**
There is no "run my code at 5:30 AM" API for third-party apps. Timers die when the
app is suspended. Background pushes are throttled and may arrive late or not at all.
(Confidence: high. This has been true since iOS 4 and Apple has not relaxed it.)

What an app *can* do:

| Capability | iPhone / iPad | Mac | Notes |
|---|---|---|---|
| Keep playing audio once started, screen off, in background | Yes (Audio background mode) | Yes | Process stays alive as long as audio plays. |
| Be launched *by the system* in the background to start audio | Yes, via an App Intent that adopts `AudioPlaybackIntent` | Yes | This is the official door. Shortcuts, Siri, Action Button, Control Center buttons and widgets all go through it. Cold start adds a few seconds. |
| Run its own exact-time scheduler forever | Only while in the foreground and plugged in | Yes, always | Mac apps have no background restrictions. An iPad left on a charger with the app open behaves like a Mac. |
| Listen on the local network (tiny HTTP / Bonjour server) | Only while foreground or already playing audio | Yes, always | Lets any device on the Wi-Fi trigger it with a plain URL. |
| Stop itself at a set time | Yes (it is already running) | Yes | Easy. |

Source for the intent behaviour: Apple's `AudioPlaybackIntent` docs
(https://developer.apple.com/documentation/appintents/audioplaybackintent) and Apple DTS
answers on the developer forums (https://developer.apple.com/forums/thread/730542,
https://developer.apple.com/forums/thread/761677). DTS states plainly that a terminated app
cannot play audio on its own and that playback is normally user-initiated; App Intents are the
sanctioned exception because the *system* initiates the launch.

## So who does the waking up? Shortcuts automations.

The Shortcuts app's **personal automations** run on a schedule or on an event, and since iOS 17
nearly all of them can be set to **Run Immediately** (no "tap to confirm" prompt). The automation's
action is simply "run our app's *Start Sound* intent", which launches the app in the background
and starts audio. Confidence: high (Apple support guide + MacStories/Cassinelli coverage of iOS 17:
https://matthewcassinelli.com/automations-run-immediately-shortcuts-notifications).

Caveats:
- Automations are per-device. They are backed up to iCloud but do **not** sync between devices.
- "Run Immediately" automations always post a notification when they fire (cannot be turned off).
  Under Sleep Focus that notification is silent, so it is harmless for this use case.
- Apps cannot create automations for the user. We can ship pre-built shortcuts (iCloud links) and
  step-by-step setup screens, but the user taps "Add" in Shortcuts.
- Shortcuts automations run on iPhone and iPad. On Mac, Shortcuts has no automation triggers at all,
  but the Mac app can run its own scheduler, so it does not need them.

## Personal automation triggers available (iOS 17 to iOS 26)

Grouped by how useful they are for "start white noise when my wife wakes up".

**Time**
- Time of Day (fixed time, sunrise, sunset; daily / weekly / monthly repeat)
- Alarm: goes off / is stopped / is snoozed, for one specific Clock alarm or any alarm
- Sleep: Wind Down begins, Bedtime begins, Waking Up, Sleep Focus on/off (needs a Sleep Schedule in Health)

**Phone being used (good "she is awake" proxies on *her* phone)**
- Charger: connected / disconnected  (picking the phone up off the nightstand charger)
- App: opened / closed (e.g. she opens Messages or Safari)
- Focus: Sleep Focus turned off
- Alarm stopped (her alarm, on her phone)
- Wi-Fi: joined / left a network
- Bluetooth: device connected / disconnected (AirPods, car, watch)
- NFC tag tapped
- Battery level, Low Power Mode, Airplane Mode, Cellular Data, Sound Recognition, Transaction (Wallet),
  CarPlay, Arrive / Leave location, Before I Commute, Apple Watch workout

**Receiving something (how *my* phone can be told to start)**
- Message: a message is received, filterable by sender and by "message contains"
- Email: a message is received, filterable by sender/subject

Everything in this list except Arrive/Leave/Before I Commute supports Run Immediately
(Cassinelli reports location triggers were added late in the iOS 17 cycle; verify on device).

**Not available:** any trigger based on *another* person's phone, or on a HomeKit accessory changing
state. Those exist, but in different places (next sections).

## Phone-to-phone relay (the "she wakes up" case) — no server needed

Her phone: automation `Charger disconnected` (or `Alarm stopped`, or `Sleep Focus off`) →
`If time is between 05:00 and 08:00` → `Send Message "wn:start" to <me>` → Run Immediately.

My phone: automation `Message received from <her> containing "wn:start"` → `Start Sound (preset: Rain)`
→ Run Immediately.

Both halves use only built-in Apple triggers and actions, so this works on day one. Latency is a few
seconds (iMessage delivery + app cold start). Confidence: high for the mechanism; the exact wording of
the trigger options varies slightly by iOS version.

Alternative relay that avoids iMessage: her automation `Get Contents of URL` to the appliance device
(see below) on the same Wi-Fi. No message, no notification on her side beyond the mandatory one.

## Smart devices on the same Wi-Fi

Home app automations (HomeKit / Matter accessories) run on the **home hub** (HomePod, Apple TV), not on
a phone. "Convert to Shortcut" gives a reduced action set: Apple's own actions only, **no third-party app
intents**, because the hub has no third-party apps installed. Confidence: high (Apple guide + multiple
developer reports: https://developer.apple.com/forums/thread/650702).

What that means for us:
- A Home automation **cannot** call our app's intent directly.
- A Home automation **can** (a) control other accessories and HomePod playback, and (b) fetch a URL.
  (b) is how it reaches our app: `When Air Purifier turns on, 05:00–08:00 → Get Contents of URL
  http://bedside.local:8787/start?preset=rain`. This needs our app listening on the LAN, which on
  iPhone only works while the app is in the foreground or already playing. On a plugged-in iPad or a
  Mac it works all the time. **"Get Contents of URL" inside a converted home automation is something
  we must verify on a real hub before relying on it** (widely reported to work; not confirmed by Apple docs).
- If the purifier is not a HomeKit/Matter device, a smart plug that *is* can stand in for it: the plug
  reports power draw / on-state, and the automation keys off that.

Fallback for non-HomeKit ecosystems: a Home Assistant / SmartThings / IFTTT style hub can hit the same URL.

## Two Apple features that already exist and that we should not pretend don't

1. **Background Sounds** (Settings → Accessibility → Audio & Visual). iOS ships white, pink, brown,
   ocean, rain, stream, fire, night. Shortcuts has `Set Background Sound` and `Set Background Sounds`
   actions, so *every trigger above can switch on Apple's own white noise today with no app.*
   Limits: fixed sound set, no mixing, no fade, no timer, coarse volume, iPhone/iPad only.
2. **HomePod ambient sounds / playlists.** A Home automation can play audio on a HomePod directly. If
   there is a HomePod in the bedroom, "purifier on → play Rain on Bedroom HomePod" needs no app at all.

Our app earns its place by: custom and procedural sounds, mixing, fade in/out, auto-stop time,
presets addressable from any trigger, a reliable always-on "appliance mode" on iPad/Mac, a local-network
trigger endpoint, a log of what fired and when, and one place to set up all the automations.

## Things that do NOT work (so we don't waste time)

- Silent push (`content-available`) to launch the app and play audio: throttled, delayed, dropped when
  the user force-quits, and Apple reviewers reject apps that use it as a wake-up alarm. Not a primary path.
- Local notification with a long sound: notification sounds are capped at 30 s and do not keep the app alive.
- AlarmKit (iOS 26): its alarms can carry a custom sound (≤30 s, loops while ringing) and show an "Open"
  button bound to our intent. It is a real alarm UI at alarm volume, so it is a backstop, not a white
  noise player. Worth a small experiment later, not for MVP.
- Shortcuts "Alarm stopped" does not currently fire for AlarmKit alarms (developer report, unverified).

## Hardware reality check

- Mac: everything works, no restrictions. Best possible "appliance".
- iPad on a charger with the app in the foreground: same as Mac in practice. Screen can be dimmed to
  near-black by the app.
- iPhone on the nightstand: fully supported via Shortcuts automations + App Intents. Cannot be a LAN
  endpoint while idle.
- Apple Watch: out of scope for v1.
