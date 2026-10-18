import SwiftUI

/// A team's page: who plays in it, its record, and its games in one season (switchable to any
/// season it took part in, like the website's team page).
struct TeamDetailView: View {
    let teamID: Int
    let initialSeasonID: Int?

    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var detail: TeamDetail?
    @State private var error: APIError?
    @State private var seasonID: Int?

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if let error {
                ContentUnavailableView {
                    Label("Team konnte nicht geladen werden", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Erneut versuchen") { Task { await load() } }
                }
            } else {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .themedScreen()
        .navigationTitle(detail?.team.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            let loaded = try await model.teamDetail(id: teamID)
            detail = loaded
            error = nil
            if seasonID == nil {
                let enrolled = Set(loaded.enrollments.map(\.seasonId))
                seasonID = initialSeasonID.flatMap { enrolled.contains($0) ? $0 : nil } ?? loaded.enrollments.first?.seasonId
            }
        } catch let apiError as APIError {
            error = apiError
        } catch {}
    }

    private func content(_ detail: TeamDetail) -> some View {
        let enrollment = detail.enrollments.first { $0.seasonId == seasonID }
        let games = detail.games.filter { $0.seasonId == seasonID }
        var teams = Dictionary(uniqueKeysWithValues: detail.opponents.map { ($0.id, $0) })
        teams[detail.team.id] = detail.team

        return List {
            Section {
                VStack(spacing: 10) {
                    TeamAvatar(team: detail.team, size: 96)
                    Text(detail.team.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    if let subtitle = detail.team.playersSubtitle {
                        Text(subtitle)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if model.session?.team.id == detail.team.id {
                        TeamPhotoPicker(team: detail.team) { await load() }
                    }
                    record(games)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            if detail.enrollments.count > 1 {
                Section {
                    Picker("Saison", selection: $seasonID) {
                        ForEach(detail.enrollments, id: \.seasonId) { enrollment in
                            Text(enrollment.seasonLabel).tag(Optional(enrollment.seasonId))
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }

            Section {
                if games.isEmpty {
                    Text("Keine Spiele in dieser Saison.")
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(games) { game in
                    TeamGameRow(game: game, teamID: detail.team.id, opponent: game.opponent(of: detail.team.id).flatMap { teams[$0] })
                }
            } header: {
                if let enrollment {
                    Text("\(enrollment.seasonLabel) · Gruppe \(enrollment.groupName)")
                }
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    private func record(_ games: [Game]) -> some View {
        let played = games.filter(\.isComplete)
        let won = played.filter { $0.winnerTeamId == teamID }.count
        let tied = played.filter(\.isDraw).count
        let lost = played.count - won - tied
        return HStack(spacing: 28) {
            stat(won, String(localized: "Siege"))
            if tied > 0 { stat(tied, String(localized: "Unentschieden")) }
            stat(lost, String(localized: "Niederlagen"))
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.monospacedDigit().weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One of the team's games, from its point of view: opponent, round, date, and the result (W/L).
private struct TeamGameRow: View {
    let game: Game
    let teamID: Int
    let opponent: Team?
    @Environment(Navigator.self) private var navigator
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            // The sheet looks the game up in loaded season data; make sure that season is there.
            Task {
                if model.details[game.seasonId] == nil {
                    try? await model.loadSeason(id: game.seasonId)
                }
                navigator.open(game)
            }
        } label: {
            HStack(spacing: 12) {
                TeamAvatar(team: opponent, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(opponent.map { String(localized: "gegen \($0.name)") } ?? String(localized: "Gegner noch offen"))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text([game.title, game.dateLabel].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if game.isComplete {
                    resultBadge
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var resultBadge: some View {
        let mine = game.teamAId == teamID ? game.setsA ?? 0 : game.setsB ?? 0
        let theirs = game.teamAId == teamID ? game.setsB ?? 0 : game.setsA ?? 0
        let (letter, color): (String, Color) = mine > theirs
            ? (String(localized: "S", comment: "Badge: won"), .green)
            : mine < theirs ? (String(localized: "N", comment: "Badge: lost"), .red) : (String(localized: "U", comment: "Badge: draw"), .gray)
        return HStack(spacing: 8) {
            Text("\(mine):\(theirs)")
                .font(.body.monospacedDigit().weight(.semibold))
            Text(letter)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(color.opacity(0.85), in: .circle)
        }
    }
}
