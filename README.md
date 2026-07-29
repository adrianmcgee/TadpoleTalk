# Tadpole Talk

A private, parent-led home-practice companion for families of children with **Childhood
Apraxia of Speech (CAS)** — built to be used alongside therapy directed by a qualified
speech pathologist.

iOS / iPadOS 17+ · SwiftUI · MVVM · SwiftData (local-only) · XcodeGen.

## What it does
- **Today** — an encouraging home screen: this week's words, a practice streak, one button
  to start a short session.
- **Practice** — parent-led, one word at a time, with plain-language sound guidance, a DTTC-style
  cueing-ladder reminder, three one-tap ratings, and a celebratory reward on success.
- **Targets** — a word bank organised by syllable shape (CV → VC → CVC → CVCV…), seeded and
  fully editable; star the words that are this week's focus.
- **Library** — reference for speech sounds (plain-language how-to and optional hand cues)
  and Key Word Signs.
- **Progress** — charts of practice over time and per word, plus a one-tap **PDF/CSV export**
  to share with your therapist.
- **Reminders** — gentle, spread-out nudges for little-and-often practice.
- **Privacy** — everything stays on the device. No account, no tracking, nothing uploaded.

> Tadpole Talk does not diagnose, assess, or replace professional care. It ships only its own
> original explanatory content and is not affiliated with Cued Articulation or Key Word Sign.

## Architecture
- **MVVM**: each feature has an `@Observable` view-model holding state/logic (e.g.
  `PracticeSessionViewModel`, `ProgressViewModel`); views are thin presentation.
- **SwiftData**, a single local-only store (`PersistenceController`). Models: `Child`,
  `WordTarget`, `PracticeSession`, `Trial`. Reference content (`phonemes.json`, `signs.json`,
  `starter_targets.json`) is bundled read-only data loaded by `ContentStore`.
- **Adaptive navigation**: iPhone tab bar ↔ iPad sidebar split, from one `AppSection` enum.
- **Accessibility**: stable identifiers in `A11y`, Dynamic Type, VoiceOver labels, SF Symbols
  throughout (never emoji).

## Build & test
```sh
brew install xcodegen swiftlint   # if needed
xcodegen generate
open TadpoleTalk.xcodeproj        # or:
xcodebuild test -project TadpoleTalk.xcodeproj -scheme TadpoleTalk \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
- Unit tests (`TadpoleTalkTests`): persistence, view-model logic, content decoding, export.
- UI tests (`TadpoleTalkUITests`): first-run, add-target, and a full practice flow via page
  objects (launch with `-localStore` for a clean in-memory run).
- CI (`.github/workflows/ci.yml`) runs SwiftLint + tests on iPhone and iPad simulators.

## Release
See [`RELEASE.md`](RELEASE.md) and [`STORE_LISTING.md`](STORE_LISTING.md). The marketing /
privacy / support site lives in [`docs/`](docs/) (GitHub Pages).
