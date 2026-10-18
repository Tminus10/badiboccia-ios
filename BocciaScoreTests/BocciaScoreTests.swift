import CoreGraphics
import Foundation
import Testing
@testable import BocciaScore

/// Real /api/v1 responses captured from the website's local dev server.
private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private final class BundleToken {}

@Suite("Decoding the website API")
struct DecodingTests {
    @Test func decodesCompleteSeason() throws {
        let detail = try APIClient.decode(SeasonDetail.self, from: fixture("season-complete"))
        #expect(detail.season.year == 2018)
        #expect(detail.groups.map(\.name) == ["A", "B", "C"])
        #expect(detail.bracket.qf.count == 4)
        #expect(detail.bracket.sf.count == 2)
        #expect(detail.bracket.final != nil)
        #expect(detail.podium?.championId != nil)
        // Every team referenced by a game is in the season's team list.
        let teamIDs = Set(detail.teams.map(\.id))
        for game in detail.allGames {
            for id in [game.teamAId, game.teamBId].compactMap({ $0 }) {
                #expect(teamIDs.contains(id))
            }
        }
    }

    @Test func decodesBracketPlaceholders() throws {
        let detail = try APIClient.decode(SeasonDetail.self, from: fixture("season-unplayed-knockout"))
        let sf1 = try #require(detail.bracket.sf.first)
        #expect(sf1.teamAId == nil)
        #expect(sf1.placeholderA == Placeholder(type: .winner, group: nil, phase: .qf, slot: 1))
        #expect(sf1.placeholderB == Placeholder(type: .winner, group: nil, phase: .qf, slot: 2))
        let third = try #require(detail.bracket.third)
        #expect(third.placeholderA?.type == .loser)
        #expect(detail.podium == nil)
    }

    @Test func decodesTeamDetail() throws {
        let detail = try APIClient.decode(TeamDetail.self, from: fixture("team"))
        #expect(!detail.enrollments.isEmpty)
        #expect(detail.games.allSatisfy { $0.involves(detail.team.id) })
    }

    @Test func resultRequestSendsExplicitNulls() throws {
        let body = ResultRequest(setsA: 2, setsB: 1, playedDate: nil, gameTime: nil)
        let json = try #require(String(data: JSONEncoder.snakeCase.encode(body), encoding: .utf8))
        #expect(json.contains("\"played_date\":null"))
        #expect(json.contains("\"game_time\":null"))
        #expect(json.contains("\"sets_a\":2"))
    }
}

@Suite("Domain rules")
struct DomainTests {
    private func game(phase: Phase, setsA: Int? = nil, setsB: Int? = nil, date: String? = nil, time: String? = nil) -> Game {
        Game(id: 1, seasonId: 1, phase: phase, groupId: phase == .group ? 1 : nil, groupName: phase == .group ? "A" : nil,
             slotIndex: phase == .group ? nil : 2, teamAId: 10, teamBId: 20, setsA: setsA, setsB: setsB,
             playedDate: date, gameTime: time, slotMinutes: 90, winnerTeamId: nil, placeholderA: nil, placeholderB: nil, updatedAt: nil)
    }

    @Test func drawsOnlyInGroupPhase() {
        #expect(game(phase: .group).allowedScores.contains(Score(a: 1, b: 1)))
        #expect(!game(phase: .qf).allowedScores.contains(Score(a: 1, b: 1)))
        #expect(game(phase: .final).allowedScores.count == 4)
    }

    @Test func initialsMatchWebsite() {
        func team(_ name: String) -> Team {
            Team(id: 1, name: name, player1: "", player2: "", colorHex: "#ffffff", photoUrl: nil, groupId: nil)
        }
        #expect(team("Debi & Erika").initials == "DE")
        #expect(team("Kusi & Pädi").initials == "KP")
        #expect(team("Zimi").initials == "ZI")
    }

    @Test func playersSubtitleOnlyWhenDifferent() {
        let same = Team(id: 1, name: "Debi & Erika", player1: "Debi", player2: "Erika", colorHex: "#fff", photoUrl: nil, groupId: nil)
        let other = Team(id: 2, name: "Die Kugelblitze", player1: "Debi", player2: "Erika", colorHex: "#fff", photoUrl: nil, groupId: nil)
        #expect(same.playersSubtitle == nil)
        #expect(other.playersSubtitle == "Debi & Erika")
    }

    @Test func swissDatesRoundTrip() throws {
        let date = try #require(SwissTime.date(day: "2026-07-04", time: "18:30"))
        #expect(SwissTime.dayString(date) == "2026-07-04")
        #expect(SwissTime.timeString(date) == "18:30")
        #expect(game(phase: .group, date: "2026-07-04", time: "18:30").startDate == date)
    }

    @Test func chronologicalOrderPutsUntimedGamesLast() {
        let early = game(phase: .group, date: "2026-07-04", time: "09:00")
        let untimed = game(phase: .group, date: "2026-07-04")
        let nextDay = game(phase: .group, date: "2026-07-05", time: "08:00")
        #expect(Game.chronological(early, untimed))
        #expect(Game.chronological(untimed, nextDay))
    }
}

@Suite("Tournament tree geometry")
struct BracketLayoutTests {
    let layout = BracketLayout(columnWidth: 185, headerHeight: 28, rowHeight: 38)

    @Test func laterRoundsCenterBetweenTheirFeeders() {
        for focus in 0...1 {
            for round in focus..<2 {
                let games = 4 >> round
                for pair in 0..<(games / 2) {
                    let a = layout.centerY(round: round, index: 2 * pair, focusRound: focus)
                    let b = layout.centerY(round: round, index: 2 * pair + 1, focusRound: focus)
                    let next = layout.centerY(round: round + 1, index: pair, focusRound: focus)
                    #expect(abs(next - (a + b) / 2) < 0.001)
                }
            }
        }
    }

    @Test func focusedRoundIsPackedTightly() {
        // Scrolled to the semi-finals: they sit directly below each other, like the quarter-finals at the start.
        let sfGap = layout.centerY(round: 1, index: 1, focusRound: 1) - layout.centerY(round: 1, index: 0, focusRound: 1)
        let qfGap = layout.centerY(round: 0, index: 1, focusRound: 0) - layout.centerY(round: 0, index: 0, focusRound: 0)
        #expect(sfGap == layout.unit)
        #expect(qfGap == layout.unit)
        #expect(layout.topY(round: 1, index: 0, focusRound: 1) == 0)
    }

    @Test func championBadgeFitsAboveTheFinal() {
        for focus in 0...1 {
            let inset = layout.inset(aboveFinal: 110, focusRound: focus)
            #expect(inset >= 0)
            #expect(layout.topY(round: 2, index: 0, focusRound: focus) + inset >= 110)
        }
        // From the quarter-finals there is room already, so nothing moves.
        #expect(layout.inset(aboveFinal: 110, focusRound: 0) == 0)
    }

    @Test func iPhoneShowsTwoColumnsLikeTheSportsApp() {
        #expect(BracketLayout.visibleColumns(forWidth: 402, total: 4) == 2)
        #expect(BracketLayout.visibleColumns(forWidth: 834, total: 4) == 3)
        #expect(BracketLayout.visibleColumns(forWidth: 1366, total: 4) == 4)
    }
}
