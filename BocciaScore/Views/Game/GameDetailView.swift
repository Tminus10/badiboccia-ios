import SwiftUI

/// A single game: big scoreboard header, details, and -- for the two teams playing it, in the
/// current season -- entering the result or fixing the date.
struct GameDetailView: View {
    let gameID: Int
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var detail: SeasonDetail? {
        model.details.values.first { $0.game(id: gameID) != nil }
    }

    var body: some View {
        Group {
            if let detail, let game = detail.game(id: gameID) {
                content(game, detail: detail)
            } else {
                ContentUnavailableView("Spiel nicht gefunden", systemImage: "questionmark.circle")
            }
        }
        .themedScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) { dismiss() }
            }
        }
    }

    private func content(_ game: Game, detail: SeasonDetail) -> some View {
        let teams = detail.teamsByID
        let teamA = game.teamAId.flatMap { teams[$0] }
        let teamB = game.teamBId.flatMap { teams[$0] }
        return List {
            Section {
                ScoreHeader(game: game, teamA: teamA, teamB: teamB, seasonID: detail.season.id)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                LabeledContent("Runde", value: game.title)
                LabeledContent("Saison", value: detail.season.label)
                LabeledContent("Datum", value: game.startDate?.formatted(.dateTime.weekday(.wide).day().month(.wide).year().swiss) ?? String(localized: "noch offen"))
                if let time = game.gameTime {
                    LabeledContent("Zeit", value: slotText(game, start: time))
                }
                if game.isComplete {
                    LabeledContent("Resultat", value: "\(game.setsA ?? 0) : \(game.setsB ?? 0)")
                    if game.isDraw {
                        Text("Unterbrochenes Spiel – beide Teams erhalten einen Punkt.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .listRowBackground(Theme.card)

            if model.canEdit(game) {
                Section {
                    NavigationLink {
                        ResultEntryView(game: game, teamA: teamA, teamB: teamB)
                    } label: {
                        Label(game.isComplete ? "Resultat korrigieren" : "Resultat eintragen", systemImage: "square.and.pencil")
                    }
                    NavigationLink {
                        ScheduleGameView(game: game, teamA: teamA, teamB: teamB)
                    } label: {
                        Label(game.playedDate == nil ? "Termin festlegen" : "Termin ändern", systemImage: "calendar.badge.plus")
                    }
                } footer: {
                    Text("Jede Änderung wird mit dem Namen deines Teams protokolliert.")
                }
                .listRowBackground(Theme.card)
            } else if model.session == nil, game.hasBothTeams, model.selectedSeason?.isCurrent == true, !game.isComplete {
                Section {
                    Text("Spielst du in diesem Spiel? Melde dich unter „Mein Team“ mit dem PIN deines Teams an, um das Resultat einzutragen.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                .listRowBackground(Theme.card)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(game.title)
    }

    /// "18:00 – 19:30 (1½ h)", using the website's assumed slot length for the phase.
    private func slotText(_ game: Game, start: String) -> String {
        guard let begin = game.startDate else { return start }
        let end = begin.addingTimeInterval(TimeInterval(game.slotMinutes * 60))
        let range = "\(start) – \(end.formatted(.dateTime.hour().minute().swiss))"
        return range
    }
}

/// The Sports app's score layout: avatars and names left and right, big sets in between.
private struct ScoreHeader: View {
    let game: Game
    let teamA: Team?
    let teamB: Team?
    let seasonID: Int

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            side(teamA, placeholder: game.placeholderA)
            Text(scoreText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(game.isComplete ? .white : Theme.tertiaryText)
                .fixedSize()
            side(teamB, placeholder: game.placeholderB)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .card()
    }

    private var scoreText: String {
        guard let a = game.setsA, let b = game.setsB else { return "– : –" }
        return "\(a) : \(b)"
    }

    @ViewBuilder
    private func side(_ team: Team?, placeholder: Placeholder?) -> some View {
        let content = VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                TeamAvatar(team: team, size: 64)
                if let team, team.id == game.winnerTeamId {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.qualifier)
                        .offset(x: 4, y: -6)
                        .accessibilityLabel(Text("Sieger"))
                }
            }
            Text(team?.name ?? placeholder?.label ?? "–")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(team == nil ? Theme.secondaryText : .white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let subtitle = team?.playersSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)

        if let team {
            // A NavigationLink inside a List row would add a disclosure chevron; keep it invisible behind the content.
            content
                .background {
                    NavigationLink(value: Route.team(id: team.id, seasonID: seasonID)) { EmptyView() }
                        .opacity(0)
                }
        } else {
            content
        }
    }
}
