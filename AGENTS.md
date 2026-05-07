# Repository Guidelines

## Project Structure & Module Organization
- `Suilog/` contains the iOS app source. Key areas: `Views/` (SwiftUI screens), `Models/` (SwiftData entities), `Managers/` (domain/service logic), `Resources/` (bundled JSON/images), and `Assets.xcassets/` (catalog assets).
- `SuilogTests/` and `SuilogUITests/` hold unit and UI tests.
- `Suilog.xcodeproj` is the Xcode project entry point.
- `images/` and `screenshots/` store marketing and documentation assets.
- `firebase/` contains hosting configuration for any web assets.

## Build, Test, and Development Commands
- `open Suilog.xcodeproj` — open the project in Xcode.
- In Xcode: select the `Suilog` scheme and Run for device/simulator builds.
- CLI tests (example):
  - `xcodebuild -scheme Suilog -destination 'platform=iOS Simulator,name=iPhone 15' test` — run all tests.

## Coding Style & Naming Conventions
- Follow Xcode defaults: 4-space indentation, braces on the same line.
- Swift types use `PascalCase`; properties/functions use `camelCase`.
- Name files after primary types (e.g., `Aquarium.swift`, `CheckInView.swift`).
- No automated formatter/linter is configured; keep style consistent with nearby files.

## Testing Guidelines
- Tests use the Swift Testing framework (`import Testing`) with `@Suite` and `@Test`.
- Place unit tests in `SuilogTests/` and UI tests in `SuilogUITests/`.
- Prefer descriptive test names that read like behavior (e.g., `filtersUnvisitedAquariums`).

## Commit & Pull Request Guidelines
- Commit messages are short, descriptive, and written in Japanese without prefixes.
- PRs should include: a concise summary, testing notes (simulator/device), and UI screenshots for visual changes.
- Link related issues or tasks when applicable.

## Configuration & Environment Notes
- The app targets iOS 17+ and uses SwiftUI, SwiftData, MapKit, and CoreLocation.
- StoreKit testing uses `Suilog/Configuration.storekit`.
