import XCTest

/// End-to-end check of the team flow against the website's local dev server (`./dev/serve.sh` in
/// the badiboccia repo), so it isn't part of the default test plan -- run the
/// "BocciaScoreUITests" scheme with the team's PIN in the environment:
///
///     TEST_RUNNER_BOCCIA_TEAM="Sandra & Thomi" TEST_RUNNER_BOCCIA_PIN=1234 xcodebuild test -scheme BocciaScoreUITests ...
///
/// It corrects a result of that team in the current season, so restore the dev database afterwards.
/// Set TEST_RUNNER_BOCCIA_SCREENSHOTS=<dir> to also save a PNG of every step.
final class TeamFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let env = ProcessInfo.processInfo.environment

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(env["BOCCIA_PIN"] == nil, "BOCCIA_PIN not set -- needs the local dev server, see the class comment.")
        app = XCUIApplication()
        // The assertions use the German texts, whatever language the simulator runs in.
        app.launchArguments = ["-server", "local", "-AppleLanguages", "(de)", "-AppleLocale", "de_CH"]
    }

    func testBrowseTabsAndTree() {
        app.launchArguments += ["-tab", "overview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Boccia"].waitForExistence(timeout: 10))
        snapshot("01-overview")

        app.tabBars.buttons["Turnierbaum"].tap()
        XCTAssertTrue(app.buttons["Halbfinal"].waitForExistence(timeout: 5))
        snapshot("02-bracket")
        app.buttons["Halbfinal"].tap()
        sleep(1)
        snapshot("03-bracket-semifinals")
        app.buttons["Final"].tap()
        sleep(1)
        snapshot("04-bracket-final")

        app.tabBars.buttons["Spielplan"].tap()
        sleep(1)
        snapshot("05-schedule")
    }

    func testLoginAndCorrectResult() throws {
        let teamName = try XCTUnwrap(env["BOCCIA_TEAM"])
        let pin = try XCTUnwrap(env["BOCCIA_PIN"])
        app.launchArguments += ["-tab", "team"]
        app.launch()

        // Log out first if a previous run left the team logged in.
        let logout = app.buttons["Abmelden"]
        if logout.waitForExistence(timeout: 3) {
            logout.tap()
        }

        let teamButton = app.buttons[teamName].firstMatch
        XCTAssertTrue(teamButton.waitForExistence(timeout: 10))
        teamButton.tap()
        snapshot("10-pin")

        // A wrong PIN is rejected...
        let wrong = String(pin.map { $0 == "9" ? "8" : "9" })
        for digit in wrong { app.buttons[String(digit)].tap() }
        XCTAssertTrue(app.staticTexts["Falscher PIN. Bitte versuche es nochmals."].waitForExistence(timeout: 5))
        snapshot("11-wrong-pin")

        // ...the right one logs in.
        for digit in pin { app.buttons[String(digit)].tap() }
        XCTAssertTrue(app.staticTexts["Angemeldet"].waitForExistence(timeout: 10))
        snapshot("12-logged-in")

        // Open the team's first played game and correct its result to 2:0.
        let played = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", teamName)).element(boundBy: 1)
        XCTAssertTrue(played.waitForExistence(timeout: 5))
        played.tap()
        let correct = app.buttons["Resultat korrigieren"]
        XCTAssertTrue(correct.waitForExistence(timeout: 5))
        snapshot("13-game-sheet")
        correct.tap()

        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS ' 2 zu 0 '")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        snapshot("14-result-entry")
        app.buttons["Speichern"].tap()

        XCTAssertTrue(app.staticTexts["2 : 0"].waitForExistence(timeout: 10))
        snapshot("15-saved")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = env["BOCCIA_SCREENSHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
        }
    }
}
