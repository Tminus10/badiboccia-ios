import SwiftUI

/// The Sports app's "Yesterday / Today / Upcoming" card. Boccia games are spread over the summer,
/// so "recent" is the latest day that has results and "upcoming" the next scheduled games.
struct ScoreboardCard: View {
    let detail: SeasonDetail
    @State private var segment: Segment?

    enum Segment: CaseIterable, Hashable {
        case recent, today, upcoming

        var title: String {
            switch self {
            case .recent: String(localized: "Zuletzt")
            case .today: String(localized: "Heute")
            case .upcoming: String(localized: "Demnächst")
            }
        }
    }

    var body: some View {
        let selected = segment ?? defaultSegment
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Segment.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.snappy) { segment = item }
                    } label: {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(item == selected ? .white : Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == selected ? .isSelected : [])
                }
            }
            Divider().overlay(Theme.separator)

            let games = games(for: selected)
            if games.isEmpty {
                EmptyStateText(text: emptyText(for: selected))
            } else {
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    if index > 0 {
                        Divider().overlay(Theme.separator).padding(.horizontal)
                    }
                    ScoreRow(game: game, detail: detail, showDate: selected != .today)
                }
            }
        }
        .card()
    }

    /// Today if there are games today, else what's coming up, else the latest results.
    private var defaultSegment: Segment {
        if !games(for: .today).isEmpty { return .today }
        if !games(for: .upcoming).isEmpty { return .upcoming }
        return .recent
    }

    private func games(for segment: Segment) -> [Game] {
        let today = SwissTime.today
        let candidates = detail.allGames.filter { $0.hasBothTeams && $0.playedDate != nil }
        switch segment {
        case .today:
            return candidates
                .filter { $0.playedDate == today }
                .sorted(by: Game.chronological)
        case .upcoming:
            return Array(candidates
                .filter { $0.playedDate! > today && !$0.isComplete }
                .sorted(by: Game.chronological)
                .prefix(4))
        case .recent:
            let played = candidates.filter { $0.playedDate! < today && $0.isComplete }
            guard let lastDay = played.map({ $0.playedDate! }).max() else {
                // Results without a date (older seasons) still deserve a place: show the latest bracket games.
                return Array(detail.bracketGames.filter(\.isComplete).reversed().prefix(4))
            }
            return played.filter { $0.playedDate == lastDay }.sorted(by: Game.chronological)
        }
    }

    private func emptyText(for segment: Segment) -> String {
        switch segment {
        case .recent: String(localized: "Noch keine Resultate.")
        case .today: String(localized: "Heute finden keine Spiele statt.")
        case .upcoming: String(localized: "Keine geplanten Spiele.")
        }
    }
}

/// One game in big scoreboard style: avatar and name on each side, the sets as large numbers,
/// and what/when in the middle -- like the Sports app's live score rows.
struct ScoreRow: View {
    let game: Game
    let detail: SeasonDetail
    var showDate = true
    @Environment(Navigator.self) private var navigator

    var body: some View {
        let teams = detail.teamsByID
        let teamA = game.teamAId.flatMap { teams[$0] }
        let teamB = game.teamBId.flatMap { teams[$0] }
        Button {
            navigator.open(game)
        } label: {
            HStack(spacing: 8) {
                side(teamA, placeholder: game.placeholderA)
                score(game.setsA, isWinner: game.winnerTeamId != nil && game.winnerTeamId == teamA?.id)
                VStack(spacing: 4) {
                    Text(game.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.tertiaryText)
                    Text(statusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(minWidth: 84)
                score(game.setsB, isWinner: game.winnerTeamId != nil && game.winnerTeamId == teamB?.id)
                side(teamB, placeholder: game.placeholderB)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(teamA, teamB))
        .accessibilityAddTraits(.isButton)
    }

    private var statusText: String {
        let time = game.startDate.map { $0.formatted(.dateTime.hour().minute().swiss) }
        let day = game.startDate.map { $0.formatted(.dateTime.day().month(.abbreviated).swiss) }
        if game.isComplete {
            return showDate ? (day ?? String(localized: "Beendet")) : String(localized: "Beendet")
        }
        if showDate {
            return [day, game.gameTime != nil ? time : nil].compactMap { $0 }.joined(separator: "\n")
        }
        return game.gameTime != nil ? (time ?? "") : String(localized: "Ganztags")
    }

    private func side(_ team: Team?, placeholder: Placeholder?) -> some View {
        VStack(spacing: 6) {
            TeamAvatar(team: team, size: 44)
            Text(team?.name ?? placeholder?.label ?? "–")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    private func score(_ sets: Int?, isWinner: Bool) -> some View {
        Text(sets.map(String.init) ?? "–")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(sets == nil ? Theme.tertiaryText : (game.winnerTeamId == nil || isWinner ? .white : Theme.secondaryText))
            .frame(minWidth: 28)
    }

    private func accessibilityText(_ teamA: Team?, _ teamB: Team?) -> String {
        let a = teamA?.name ?? game.placeholderA?.label ?? "–"
        let b = teamB?.name ?? game.placeholderB?.label ?? "–"
        var parts = [game.title, "\(a) – \(b)"]
        if let setsA = game.setsA, let setsB = game.setsB {
            parts.append(String(localized: "Resultat \(setsA) zu \(setsB)"))
        }
        if let date = game.dateLabel { parts.append(date) }
        return parts.joined(separator: ", ")
    }
}
