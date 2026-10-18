# Boccia iOS/iPadOS App

SwiftUI app for the BadiBoccia league; companion to the PHP website in
`../badiboccia`, whose `/api/v1` (`src/Controllers/ApiController.php`) it uses.

## Build & run

- Project `BocciaScore.xcodeproj`, scheme **BocciaScore** (app + unit tests), scheme **BocciaScoreUITests** (UI tests, need the local website).
- Deployment target **iOS/iPadOS 26.0**, Xcode 27, Swift 6 language mode. No third-party dependencies.
- Simulators: **iPhone 18 Pro** (default), **iPad Pro 13-inch (M5)** for iPad layouts.
- The user keeps Xcode open alongside; after every change, confirm the build passes:

```
xcodebuild -project BocciaScore.xcodeproj -scheme BocciaScore \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build/DerivedData build
xcodebuild test -project BocciaScore.xcodeproj -scheme BocciaScore \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build/DerivedData
```

- Launch arguments: `-server local|development|production`, `-tab overview|bracket|schedule|team`.
  Local = the website's `./dev/serve.sh` at `http://localhost:8090` (simulator only).
- The project uses folder-synchronized groups: new files under `BocciaScore/` are picked up automatically, never edit `project.pbxproj` to add files.

## Architecture

- No MVVM / no per-screen view models. One `@MainActor @Observable` **`AppModel`** (`App/AppModel.swift`) holds server, seasons, loaded `SeasonDetail`s, the team session, and does all API calls (login, result entry, scheduling). Views read it via `@Environment(AppModel.self)`.
- `Navigator` (`App/BocciaScoreApp.swift`): selected tab + the game sheet (`navigator.open(game)`), so a game opens from any screen. Pushed screens go through `Route` + `.appDestinations()`.
- `Model/APIModels.swift` mirrors the API JSON 1:1 (snake_case decoded to camelCase). **Keep it in sync with `ApiController.php`**; API changes are made in the website repo.
- `Model/Domain.swift`: derived logic as extensions (Swiss time `SwissTime`, labels, `Score` rules). Game dates/times are Swiss local time — always format with `.swiss`.
- `Networking/`: `APIClient` (stateless struct), `SessionStore` (Keychain), `ResponseCache` (disk).
- `Views/<Feature>/`: Overview, Bracket, Schedule, Team, Game; shared pieces in `Views/Components` (`Theme`, `.card()`, `.themedScreen()`, `TeamAvatar`, `SeasonPicker`).
- Bracket geometry lives in `Views/Bracket/BracketLayout.swift` (pure, unit-tested).

## Conventions

- Look follows Apple's Sports app: dark blue gradient (`ThemeBackground`), dark cards, accent `Theme.qualifier`. App is dark-only.
- Business rules must match the website (valid scores 2:0 2:1 1:1 1:2 0:2, draw only in group phase, only participating teams in the current season may edit).
- **Localization**: German is the source language (Swiss German — never "ß"), English in `Resources/Localizable.xcstrings`. Every new user-facing string needs an English entry there. UI tests force German via launch args.
- Tests: Swift Testing in `BocciaScoreTests` (fixtures = real API responses in `BocciaScoreTests/Fixtures`).
- Commit messages: gitmoji format without env tag (`✨: Add …`); commit only when asked.
