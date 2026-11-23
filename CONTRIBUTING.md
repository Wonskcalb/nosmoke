# Contributing

Bug reports, ideas and pull requests are welcome. If you are quitting yourself and something in the app got in your way, that is exactly the kind of issue worth opening.

## Getting started

1. `brew install xcodegen && xcodegen generate`
2. In `project.yml`, set `DEVELOPMENT_TEAM` to your team, and change the bundle IDs and the App Group (`group.<bundle id>`) to ones you own. Regenerate.
3. Open `NoSmoke.xcodeproj` and run the `NoSmoke` scheme.

## Where things live

- **`Shared/`**: the model (`AppState`, the taper plan, `stepInfo`), persistence and the theme. Logic that can be tested without a view goes here, with a test in `NoSmokeTests/`.
- **`Shared/Characters/`**: the SwiftUI drawings. Animations are short (1.5 s at most), play once, rest on a still pose, replay on tap, and respect Reduce Motion. Keep it that way.
- **`NoSmoke/`** and **`NoSmokeWidgets/`**: thin SwiftUI and WidgetKit layers on top.
- **`project.yml`**: the source of truth for the Xcode project. The generated `.xcodeproj` is git-ignored.

## Design

The look is "Jardin": a cream background, ink outlines, one terracotta accent, a serif for titles. The palette and fonts live in `Shared/Theme.swift` and the reference mockups in `design/jardin-mockups.html`. New screens use those tokens, not new colours. No dashboard grids of boxed cards: sections are separated by whitespace and hairlines.

Tone matters as much as pixels. The app talks to someone going through withdrawal: short sentences, no guilt, no exclamation marks, no gamified pressure.

## Before opening a pull request

- Run the tests: `xcodebuild test -scheme NoSmoke -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` (any simulator works).
- If you changed a screen, update its screenshot in `docs/`.
- Add a line to `CHANGELOG.md` under *Unreleased*.
- UI strings are in French. Code, comments, docs and commit messages are in English.

Never commit your own `state.json` or anything from a real device: it is health data.
