import Foundation

// Mirrors the JSON of the website's /api/v1 (badiboccia: src/Controllers/ApiController.php).
// Decoded with `.convertFromSnakeCase`, so `team_a_id` arrives as `teamAId`.

struct SeasonSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let label: String
    let year: Int
    let isCurrent: Bool
    /// The demo season (badiboccia: scripts/seed-demo.php). Optional so caches and servers from before it still decode.
    var isDemo: Bool? = nil
}

struct Team: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let player1: String
    let player2: String
    let colorHex: String
    let photoUrl: URL?
    /// The team's group in the season it was loaded for; nil outside a season context.
    let groupId: Int?
    /// Plays only in the demo season. Optional so caches and servers from before it still decode.
    var isDemo: Bool? = nil
}

enum Phase: String, Codable, Hashable, Sendable, CaseIterable {
    case group, qf, sf, final, third
}

/// What will fill a bracket slot whose team isn't known yet, e.g. "winner of group A" or "winner of quarter-final 2".
struct Placeholder: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case groupWinner = "group_winner"
        case groupRunnerUp = "group_runner_up"
        case winner
        case loser
    }

    let type: Kind
    let group: String?
    let phase: Phase?
    let slot: Int?
}

struct Game: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let seasonId: Int
    let phase: Phase
    let groupId: Int?
    let groupName: String?
    let slotIndex: Int?
    let teamAId: Int?
    let teamBId: Int?
    let setsA: Int?
    let setsB: Int?
    /// "yyyy-MM-dd", local Swiss date.
    let playedDate: String?
    /// "HH:mm", nil means "all day" / no fixed time.
    let gameTime: String?
    let slotMinutes: Int
    let winnerTeamId: Int?
    let placeholderA: Placeholder?
    let placeholderB: Placeholder?
    let updatedAt: String?
}

struct StandingRow: Codable, Hashable, Sendable {
    let teamId: Int
    let rank: Int
    let played: Int
    let won: Int
    let tied: Int
    let lost: Int
    let setsFor: Int
    let setsAgainst: Int
    let points: Int

    var setDifference: Int { setsFor - setsAgainst }
}

struct TeamGroup: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let standings: [StandingRow]
    let games: [Game]
}

struct Bracket: Codable, Hashable, Sendable {
    let qf: [Game]
    let sf: [Game]
    let final: Game?
    let third: Game?
}

struct Podium: Codable, Hashable, Sendable {
    let championId: Int?
    let runnerUpId: Int?
    let thirdId: Int?
}

struct CalendarEvent: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let location: String?
    let date: String
    let time: String?
    let durationMinutes: Int?
}

struct SeasonDetail: Codable, Hashable, Sendable {
    let season: SeasonSummary
    let qualifiersPerGroup: Int
    let teams: [Team]
    let groups: [TeamGroup]
    let bracket: Bracket
    let podium: Podium?
    let events: [CalendarEvent]
}

struct Enrollment: Codable, Hashable, Sendable {
    let seasonId: Int
    let seasonLabel: String
    let year: Int
    let groupId: Int
    let groupName: String
}

struct TeamDetail: Codable, Hashable, Sendable {
    let team: Team
    let enrollments: [Enrollment]
    let games: [Game]
    let opponents: [Team]
}

struct APIInfo: Codable, Sendable {
    let apiVersion: Int
    let env: String
    let currentSeasonId: Int?
    /// Not part of /seasons; the app offers it separately as "Demo ausprobieren".
    let demoSeasonId: Int?
    /// Public: shown next to "Demo ausprobieren".
    let demoPin: String?
}

struct SeasonsResponse: Codable, Sendable {
    let seasons: [SeasonSummary]
}

struct LoginResponse: Codable, Sendable {
    let token: String
    let team: Team
}

struct MeResponse: Codable, Sendable {
    let team: Team
}

struct GameResponse: Codable, Sendable {
    let game: Game
}

/// Every API error: `{"error": code, "message": German text}`; a schedule clash adds the conflicting games.
struct APIErrorBody: Codable, Sendable {
    let error: String
    let message: String?
    let slotMinutes: Int?
    let conflicts: [Game]?
}

// MARK: - Request bodies (encoded with `.convertToSnakeCase`)

struct LoginRequest: Encodable, Sendable {
    let teamId: Int
    let pin: String
    let device: String
}

struct ResultRequest: Encodable, Sendable {
    let setsA: Int
    let setsB: Int
    let playedDate: String?
    let gameTime: String?

    enum CodingKeys: String, CodingKey { case setsA, setsB, playedDate, gameTime }

    /// Always sends date and time, as explicit nulls when cleared -- the API treats a missing key as "keep".
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(setsA, forKey: .setsA)
        try container.encode(setsB, forKey: .setsB)
        try container.encode(playedDate, forKey: .playedDate)
        try container.encode(gameTime, forKey: .gameTime)
    }
}

struct ScheduleRequest: Encodable, Sendable {
    let playedDate: String
    let gameTime: String?
    let force: Bool

    enum CodingKeys: String, CodingKey { case playedDate, gameTime, force }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playedDate, forKey: .playedDate)
        try container.encode(gameTime, forKey: .gameTime)
        try container.encode(force, forKey: .force)
    }
}
