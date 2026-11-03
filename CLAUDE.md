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
- Plan and open questions in `docs/02-plan.md`. Phase 0 decisions are pending the owner's answers
  (playback device, is the purifier smart, wife's phone automation OK, Xcode/dev account).
- No code yet. When code starts: SwiftUI multiplatform app + `NoiseCore` Swift package. Nothing here
  can be compiled in the Linux cloud session; builds and device tests happen on the owner's Mac.

## Conventions
- Before changing anything, check how it affects existing functions and say so.
- Keep `docs/` as the source of truth for decisions; update it when a decision is made.
