# Project memory for Claude (keep this current)

## Owner context
- Owner knows HTML, networking and how software works, does not write code; wants short explanations of
  what functions do as we go. Wants proposals when there is a better idea, not literal execution.
- Owner runs a business and works across several interconnected projects; record anything learned about
  the business or their setup here so later sessions start informed.

## This project
- Personal-use first. Problem being solved: owner's wife wakes up earlier and switches on an air purifier,
  whose noise keeps the owner asleep. The app should start white noise automatically at that moment
  (within a time window) and on schedules, on iPhone / iPad / Mac.
- Core constraint: iOS apps cannot self-launch at a time; Shortcuts automations + App Intents
  (`AudioPlaybackIntent`) are the sanctioned path. Mac and a plugged-in iPad can run a real scheduler
  and a LAN listener. Details in `docs/01-what-apple-allows.md`.
- Decisions (2026-11-03): universal app on all three platforms; the air purifier is NOT smart (it was
  only an example of the sound); wife is OK with one automation on her phone; owner has a Mac with
  Xcode and a developer account. Details and status in `docs/02-plan.md`.
- Code layout: `NoiseCore/` Swift package (pure logic + fenced Apple-only audio/network code) and
  `App/` SwiftUI multiplatform target generated from `project.yml` with XcodeGen.
- The Linux cloud session CAN build and test `NoiseCore` by downloading the Swift toolchain from
  swift.org (Ubuntu 24.04 x86_64, use `curl -C -` with retries; the proxy drops long transfers).
  It CANNOT compile `App/` or the `#if canImport(AVFoundation|MediaPlayer|Network)` files; those
  were syntax-parsed only.
- First compile on the owner's Mac happened 2026-11-03: Xcode 27.1 / Swift 6.4 on macOS 27 (Darwin 27).
  macOS and iOS Simulator builds succeeded with zero code changes and zero compiler warnings; XcodeGen
  2.46 (via Homebrew) left the hand-written `App/Info.plist` and entitlements untouched. Not yet run
  on a real device. The owner has two iPhones paired with Xcode (an iPhone Air and an "iPhone Duo")
  for later on-device testing; they must be plugged in and unlocked to install.
- Simulator builds from the CLI: pass `id=<UDID>` in the destination, not `name=`; names were ambiguous.
- Signing (2026-11-04): team `3R62C4X3YS` (paid program, "Davinder Sandhu"), automatic signing, set in
  `project.yml`. The parenthesised ID in the "Apple Development: … (DJG862KS98)" certificate is the
  developer ID, NOT the team; using it fails with "No Account for Team". Bundle id
  `com.davindersandhu.AutoWhiteNoise`.
- On-device: installed and launched on iPhoneDuoDavinder (UDID `00008160-001E782E0ED0000A`) via
  `xcrun devicectl` on 2026-11-04. Commands in `docs/04-build-and-install.md`. The iPhone Air
  ("iPhoneDavinder") was unavailable at the time; capture its UDID when it is connected.
- Mac sessions spawned from the cloud session (bridge environment) cannot `send_message` back
  (trust restriction). Have them end with a plain-text report and read it with `list_events`.
- XCTest on Linux crashes if a test class is `@MainActor`; wrap test bodies in `MainActor.assumeIsolated`.
- Swift language mode 5 on purpose (fewer strict-concurrency errors for a first build).

## Conventions
- Before changing anything, check how it affects existing functions and say so.
- Keep `docs/` as the source of truth for decisions; update it when a decision is made.
