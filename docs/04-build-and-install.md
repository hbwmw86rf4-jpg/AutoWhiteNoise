# Build and install (on your Mac)

Nothing in this repo can be compiled anywhere but a Mac with Xcode. The shared `NoiseCore`
package is unit-tested on Linux in the cloud session. The SwiftUI app and the Apple-only audio,
media-controls and network code were first compiled on 2026-11-03 with Xcode 27.1: both the
macOS and the iOS Simulator builds succeed without changes. The app has **not yet been run** on
a real iPhone, iPad or Mac; that is the next step.

Command-line builds, if you prefer them to Xcode (no signing, so Simulator / local Mac only):

```bash
xcodebuild -project AutoWhiteNoise.xcodeproj -scheme AutoWhiteNoise -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
# iOS Simulator: use id=<UDID from `xcrun simctl list devices available`>; `name=` can be
# ambiguous when several runtimes carry the same device name.
xcodebuild -project AutoWhiteNoise.xcodeproj -scheme AutoWhiteNoise \
  -destination 'platform=iOS Simulator,id=<UDID>' CODE_SIGNING_ALLOWED=NO build
```

## One-time setup

1. Install **Xcode 16 or newer** from the App Store and open it once so it installs its tools.
2. Install Homebrew if you don't have it: https://brew.sh
3. In Terminal:
   ```bash
   git clone https://github.com/hbwmw86rf4-jpg/AutoWhiteNoise.git
   cd AutoWhiteNoise
   ```
4. `project.yml` uses the bundle prefix `com.davindersandhu`. Change it there if you prefer another.
5. Run:
   ```bash
   ./scripts/bootstrap.sh
   ```
   This installs XcodeGen, generates `AutoWhiteNoise.xcodeproj` from `project.yml`, and opens it.
   The `.xcodeproj` is generated output and is not committed; `project.yml` is the source of truth.
   Re-run the script any time files are added.

## Signing (already configured)

`project.yml` carries `DEVELOPMENT_TEAM: 3R62C4X3YS` (the paid Apple Developer Program team
"Davinder Sandhu") with automatic signing, so Xcode needs no manual team selection. Gotcha for
anyone redoing this: the parenthesised ID in the certificate name
"Apple Development: Davinder Sandhu (DJG862KS98)" is the *developer* ID, not the team ID; using
it fails with "No Account for Team". The team ID is in the certificate's OU field and in Xcode →
Settings → Accounts.

## In Xcode

1. Pick a run destination (your iPhone, an iPad, or **My Mac**) and press Run.
2. On an iPhone the first time: Settings → General → VPN & Device Management → trust your
   developer certificate, and enable Developer Mode if asked.

## Installing on an iPhone from the command line

Plug the phone in and unlock it. Known devices:

| Name | UDID |
|---|---|
| iPhoneDuoDavinder | 00008160-001E782E0ED0000A |
| iPhoneDavinder (iPhone Air) | not yet captured (`xcrun devicectl list devices` shows it when connected) |

```bash
xcodegen generate
UDID=00008160-001E782E0ED0000A
xcodebuild -project AutoWhiteNoise.xcodeproj -scheme AutoWhiteNoise \
  -destination "platform=iOS,id=$UDID" -allowProvisioningUpdates build
APP=$(xcodebuild -project AutoWhiteNoise.xcodeproj -scheme AutoWhiteNoise \
  -destination "platform=iOS,id=$UDID" -showBuildSettings 2>/dev/null \
  | awk '/ TARGET_BUILD_DIR =/{print $3}')/AutoWhiteNoise.app
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" com.davindersandhu.AutoWhiteNoise
```

First done 2026-11-04: installed and launched on iPhoneDuoDavinder with no errors.

## Running the core tests on the Mac

```bash
cd NoiseCore && swift test
```

## First real-world test (the one that proves the concept)

1. Run the app on your iPhone once and leave it; lock the phone.
2. Shortcuts → Automation → + → Time of Day → two minutes from now → Run Immediately →
   action: AutoWhiteNoise → Start Sound → preset Rain.
3. Lock the phone and wait. It should start playing with the screen off and show on the lock
   screen with a Stop button.

If that works, every other trigger in `docs/03-shortcuts-recipes.md` works too, because they all
end in the same action.

## Things to know

- **Force-quitting** the app (swiping it away in the app switcher) is fine; the Shortcuts
  automation relaunches it in the background. This is different from most background tricks.
- **Low Power Mode** can delay automations by a few seconds.
- **Mac**: keep the app running (it has a menu bar item). Schedules and the Wi-Fi listener only
  work while the app process is alive. Add it to Login Items so it starts at boot.
- **iPad as a bedside appliance**: plug it in, open the app, tap the moon icon (appliance mode).
  The screen stays on, dimmed to near-black with a clock, and schedules plus the Wi-Fi listener run.
