# Shortcuts recipes

Two sets. **Set A** needs no app at all and works today with Apple's built-in Background Sounds;
use it this week to prove the trigger plumbing. **Set B** is the same automations pointed at
AutoWhiteNoise once it is installed. The triggers are identical; only the action changes.

Every automation below should be set to **Run Immediately** (not "Run After Confirmation").
iOS will still show a small notification each time one fires; under Sleep Focus it is silent.

## Set A: Apple Background Sounds, no app

Background Sounds lives in Settings → Accessibility → Audio & Visual → Background Sounds.
Turn it on once by hand, pick a sound and a volume, then turn it off. That seeds the settings the
Shortcuts actions rely on. The two actions are **Set Background Sound** (which sound) and
**Set Background Sounds** (on/off).

### A1. Her phone: "I'm up" message, only between 05:00 and 08:00

On **her** iPhone, Shortcuts → Automation → **+**:

1. Trigger: **Charger** → *Is Disconnected*. (Alternative: **Alarm** → *Is Stopped* → *Any*.)
2. Choose **Run Immediately**. Tap Next.
3. Actions, in order:
   - **Get Current Date**
   - **Format Date** → Date Format: *Custom* → format string `HH`
   - **If** *Formatted Date* *is greater than or equal to* `5`
     - **If** *Formatted Date* *is less than* `8`
       - **Send Message**: text `wn:start`, Recipient: you. Tap the arrow on the action and turn
         **Show When Run** off.
     - End If
   - End If
4. Done.

Why the `HH` dance: the Charger trigger has no time filter of its own, and Shortcuts' If action
compares numbers more reliably than times. `HH` gives the hour as a two-digit number.

### A2. Your phone: start on her message

On **your** iPhone, Shortcuts → Automation → **+**:

1. Trigger: **Message** → Sender: her, Message Contains: `wn:start`.
2. **Run Immediately**. Next.
3. Actions:
   - **Set Background Sound** → *Rain* (or whichever you like)
   - **Set Background Sounds** → *Turn On*
4. Done.

Test it: have her unplug her phone (or just send `wn:start` by hand). Your phone should start
within a few seconds, screen locked, no tap.

### A3. Your phone: scheduled start and stop

Two more automations on your phone:

- Trigger **Time of Day** 05:30, Weekdays, Run Immediately → **Set Background Sounds** *Turn On*.
- Trigger **Time of Day** 08:30, Every day, Run Immediately → **Set Background Sounds** *Turn Off*.

### A4. Your phone: stop when you get up

- Trigger **Charger** → *Is Disconnected* → **Set Background Sounds** *Turn Off*.
  (Or **Alarm** → *Is Stopped*, or **Sleep** → *Waking Up* if you keep a Sleep Schedule.)

### Known limits of Set A

- Fixed sound set, no mixing, no fade, no auto-stop timer, volume set in Settings not per trigger.
- Background Sounds stops when another app plays audio unless "Use When Media Is Playing" is on.
- iPhone and iPad only. No Mac.

## Set B: the same triggers pointed at AutoWhiteNoise

Install the app, open it once (that registers its actions with Shortcuts), then edit each
automation above and swap the action:

| Set A action | Set B action |
|---|---|
| Set Background Sound + Set Background Sounds *On* | **AutoWhiteNoise → Start Sound**, pick a preset. Optional: fade-in seconds, stop-after minutes. |
| Set Background Sounds *Off* | **AutoWhiteNoise → Stop Sound** |

Extras you get with Set B:

- Give the preset **allowed hours** 05:00–08:00 in the app. Then A1 can drop the `HH` logic entirely:
  send the message on every unplug, and the app refuses starts outside the window and logs them.
- **Toggle Sound** is ideal for the Action Button (Settings → Action Button → Shortcut).
- Siri: "Start AutoWhiteNoise", "Stop AutoWhiteNoise" work with no setup.
- **Is Sound Playing** lets a shortcut branch ("if already playing, do nothing").

## Set C: the Wi-Fi URL (Mac or iPad in appliance mode)

If a Mac or an always-on iPad is the player, her phone's automation can skip Messages entirely:

- Action: **Get Contents of URL** → the URL shown in the app under Automations
  (`http://<ip>:8787/start?preset=Rain&token=…`).

Same URL works from a Home-app automation (Convert to Shortcut → Get Contents of URL), from
Home Assistant, or from a browser bookmark. Paths: `/start`, `/stop`, `/status`, `/presets`.
Query extras: `&minutes=90`, `&fade=20`, `&force=1` (ignore allowed hours).

Give the player device a DHCP reservation on the router so the address never changes.
