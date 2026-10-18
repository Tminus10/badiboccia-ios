# Boccia – iOS & iPadOS App

Native SwiftUI app for the BadiBoccia summer league, the companion to the website
**https://boccia.reutener.swiss** (repo: `../badiboccia`). Its look
follows Apple's Sports app: a deep blue gradient, dark cards, a scoreboard card and a
tournament tree with a phase bar.

- **Übersicht** – podium (once the final is played), scoreboard (*Zuletzt / Heute / Demnächst*), group tables.
- **Turnierbaum** – group tables → quarter-finals → semi-finals → final and third-place game. Two
  columns on iPhone (swipe or tap the phase bar), everything at once on iPad. Like in the Sports
  app, the leftmost visible round packs tightly and later rounds re-center between their feeders.
- **Spielplan** – all games by day, plus the website's calendar entries; "only my games" filter.
- **Mein Team** – log in with the team's 4-digit PIN (same as the website), then enter or correct
  results and set game dates. Clashing dates ask before saving, like on the website.
- Any season can be picked from the season capsule; past seasons are read-only (the archive).
- German and English (String Catalog `BocciaScore/Resources/Localizable.xcstrings`, German is the source language).

Admin tasks (seasons, teams, PIN resets, bracket pairings) stay on the website.

## Requirements

Xcode 27, iOS/iPadOS 26 or later. No third-party dependencies.

## Running

Open `BocciaScore.xcodeproj`, pick a simulator, run. To install on a device, set your team under
*Signing & Capabilities* (the project ships without a `DEVELOPMENT_TEAM`).

The app needs the website's JSON API (`/api/v1`, see the website README). Which website it talks to:

| Build   | Default server                       | Switchable in *Mein Team → Einstellungen* |
|---------|--------------------------------------|-------------------------------------------|
| Debug   | DEV – https://dev.boccia.reutener.swiss | PROD, DEV, Local (`http://localhost:8090`) |
| Release | PROD – https://boccia.reutener.swiss    | – |

Launch arguments for development (Xcode: *Scheme → Run → Arguments*):

- `-server local|development|production` – use that website (Local = the website's `./dev/serve.sh`, simulator only).
- `-tab overview|bracket|schedule|team` – start on that tab.

## Tests

- `BocciaScore` scheme – unit tests (Swift Testing): API decoding against captured responses in
  `BocciaScoreTests/Fixtures`, domain rules, tournament-tree geometry.
- `BocciaScoreUITests` scheme – end-to-end flow against the **local** website (tabs, tree, PIN login,
  correcting a result). Skipped unless a PIN is given; it changes a result in the dev database:

  ```
  TEST_RUNNER_BOCCIA_TEAM="Sandra & Thomi" TEST_RUNNER_BOCCIA_PIN=1234 \
    xcodebuild test -scheme BocciaScoreUITests -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
  ```

## Layout

```
BocciaScore/
  App/          entry point, tabs, navigation, AppModel (state, login, result entry)
  Model/        API types (mirror of ApiController.php) and domain helpers (Swiss time, labels, rules)
  Networking/   APIClient, Keychain session store, on-disk response cache
  Views/        Overview, Bracket, Schedule, Team, Game (detail + result/date entry), Components
  Resources/    assets, Localizable.xcstrings, Info.plist additions
```
