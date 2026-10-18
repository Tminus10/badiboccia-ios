import Foundation

// MARK: - Swiss local time

/// The league plays at a Swiss beach; dates and times from the API are local Swiss time and are
/// always shown that way, whatever time zone the device is in.
enum SwissTime {
    static let timeZone = TimeZone(identifier: "Europe/Zurich")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// "yyyy-MM-dd" for a date, in Swiss local time.
    static func dayString(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// "HH:mm" for a date, in Swiss local time.
    static func timeString(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    static func date(day: String, time: String? = nil) -> Date? {
        let d = day.split(separator: "-").compactMap { Int($0) }
        guard d.count == 3 else { return nil }
        var components = DateComponents(year: d[0], month: d[1], day: d[2], hour: 12)
        if let time {
            let t = time.split(separator: ":").compactMap { Int($0) }
            if t.count >= 2 {
                components.hour = t[0]
                components.minute = t[1]
            }
        }
        return calendar.date(from: components)
    }

    static var today: String { dayString(.now) }
}

extension Date.FormatStyle {
    /// Formats in Swiss local time (see `SwissTime`).
    var swiss: Date.FormatStyle {
        var style = self
        style.timeZone = SwissTime.timeZone
        return style
    }
}

// MARK: - Game

extension Game {
    var isComplete: Bool { setsA != nil && setsB != nil }
    var hasBothTeams: Bool { teamAId != nil && teamBId != nil }
    var isDraw: Bool { isComplete && setsA == setsB }

    /// Start of the game in Swiss time; midday if only the date is known.
    var startDate: Date? {
        guard let playedDate else { return nil }
        return SwissTime.date(day: playedDate, time: gameTime)
    }

    func involves(_ teamID: Int) -> Bool { teamAId == teamID || teamBId == teamID }

    func opponent(of teamID: Int) -> Int? {
        if teamAId == teamID { return teamBId }
        if teamBId == teamID { return teamAId }
        return nil
    }

    /// "Gruppe A", "Viertelfinal 2", "Final", ...
    var title: String {
        switch phase {
        case .group:
            if let groupName { return String(localized: "Gruppe \(groupName)") }
            return phase.title
        case .qf, .sf:
            if let slotIndex { return "\(phase.title) \(slotIndex)" }
            return phase.title
        case .final, .third:
            return phase.title
        }
    }

    /// "Sa., 4. Juli · 18:00", "Sa., 4. Juli" or nil when no date is set.
    var dateLabel: String? {
        guard let startDate else { return nil }
        let day = startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).swiss)
        guard gameTime != nil else { return day }
        return "\(day) · \(startDate.formatted(.dateTime.hour().minute().swiss))"
    }

    /// Sort order for lists of games: by date, timed games before untimed ones on the same day, undated games last.
    static func chronological(_ a: Game, _ b: Game) -> Bool {
        let dateA = a.playedDate ?? "9999", dateB = b.playedDate ?? "9999"
        if dateA != dateB { return dateA < dateB }
        let timeA = a.gameTime ?? "99", timeB = b.gameTime ?? "99"
        if timeA != timeB { return timeA < timeB }
        return a.id < b.id
    }

    /// The set scores a result may have: a draw (1:1, an unfinished game) only in the group phase.
    var allowedScores: [Score] {
        phase == .group ? Score.all : Score.all.filter { !$0.isDraw }
    }
}

struct Score: Hashable, Sendable, Identifiable {
    let a: Int
    let b: Int

    var id: String { "\(a)-\(b)" }
    var isDraw: Bool { a == b }

    /// Same order and set as the website's GameController::VALID_SCORES.
    static let all: [Score] = [Score(a: 2, b: 0), Score(a: 2, b: 1), Score(a: 1, b: 1), Score(a: 1, b: 2), Score(a: 0, b: 2)]
}

// MARK: - Phases and placeholders

extension Phase {
    var title: String {
        switch self {
        case .group: String(localized: "Gruppenphase")
        case .qf: String(localized: "Viertelfinal")
        case .sf: String(localized: "Halbfinal")
        case .final: String(localized: "Final")
        case .third: String(localized: "Spiel um Platz 3")
        }
    }
}

extension Placeholder {
    /// "Sieger Gruppe A", "Zweiter Gruppe B", "Sieger Viertelfinal 1", "Verlierer Halbfinal 2".
    var label: String {
        switch type {
        case .groupWinner:
            String(localized: "Sieger Gruppe \(group ?? "?")")
        case .groupRunnerUp:
            String(localized: "Zweiter Gruppe \(group ?? "?")")
        case .winner:
            String(localized: "Sieger \(phase?.title ?? "") \(slot ?? 0)")
        case .loser:
            String(localized: "Verlierer \(phase?.title ?? "") \(slot ?? 0)")
        }
    }
}

// MARK: - Season

extension SeasonDetail {
    var teamsByID: [Int: Team] { Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0) }) }

    var groupGames: [Game] { groups.flatMap(\.games) }

    var bracketGames: [Game] { bracket.qf + bracket.sf + [bracket.final, bracket.third].compactMap { $0 } }

    var allGames: [Game] { groupGames + bracketGames }

    /// The game with this id, wherever it is in the season.
    func game(id: Int) -> Game? { allGames.first { $0.id == id } }

    /// Whether any group game has a result yet -- before that, standings are all-tied and alphabetical.
    var groupPhaseStarted: Bool { groupGames.contains(where: \.isComplete) }

    func group(id: Int?) -> TeamGroup? { groups.first { $0.id == id } }
}

extension Team {
    /// "Debi & Erika" unless the team name already is exactly that.
    var playersSubtitle: String? {
        let players = "\(player1.trimmingCharacters(in: .whitespaces)) & \(player2.trimmingCharacters(in: .whitespaces))"
        return players.lowercased() == name.trimmingCharacters(in: .whitespaces).lowercased() ? nil : players
    }

    /// Same rule as the website's initials(): first letters of the first and last word, or the first two letters of a single word.
    var initials: String {
        let parts = name
            .replacingOccurrences(of: "&", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard let first = parts.first else { return "?" }
        if parts.count == 1 { return String(first.prefix(2)).uppercased() }
        return (String(first.prefix(1)) + String(parts.last!.prefix(1))).uppercased()
    }
}
