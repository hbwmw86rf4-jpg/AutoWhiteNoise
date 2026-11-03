# AutoWhiteNoise

White-noise and sleep-sound app for iPhone, iPad and Mac that can be started by schedules, Shortcuts
automations, another family member's phone, and devices on the same Wi-Fi.

- `docs/01-what-apple-allows.md`: platform constraints, researched.
- `docs/02-plan.md`: architecture, decisions, status.
- `docs/03-shortcuts-recipes.md`: the automations, with and without the app.
- `docs/04-build-and-install.md`: how to build it on a Mac.
- `NoiseCore/`: shared Swift package (models, scheduler, synthesised sounds, control protocol, player).
  `cd NoiseCore && swift test` runs 44 unit tests on macOS or Linux.
- `App/`: the SwiftUI app and its App Intents. `project.yml` + `scripts/bootstrap.sh` generate the Xcode project.
