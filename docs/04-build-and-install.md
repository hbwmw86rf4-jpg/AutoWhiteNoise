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

## In Xcode

1. Select the **AutoWhiteNoise** target → **Signing & Capabilities** → pick your Team.
2. Pick a run destination (your iPhone, an iPad, or **My Mac**) and press Run.
3. On an iPhone the first time: Settings → General → VPN & Device Management → trust your
   developer certificate.

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
