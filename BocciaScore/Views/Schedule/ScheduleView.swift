import SwiftUI

/// Every game of the season by day (plus the website's calendar entries such as the group draw),
/// then the games that have no date yet. Logged-in teams can narrow it down to their own games.
struct ScheduleView: View {
    @Environment(AppModel.self) private var model
    @State private var onlyMine = false

    var body: some View {
        Group {
            if let detail = model.selectedDetail {
                content(detail)
            } else {
                ScrollView { SeasonLoadingState() }
            }
        }
        .themedScreen()
        .navigationTitle("Spielplan")
        .toolbar {
            ToolbarItem(placement: .principal) {
                SeasonPicker()
            }
            if model.session != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $onlyMine) {
                        Label("Nur meine Spiele", systemImage: onlyMine ? "person.fill" : "person")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
    }

    private func content(_ detail: SeasonDetail) -> some View {
        let days = scheduleDays(detail)
        let undated = games(detail).filter { $0.playedDate == nil }
        return ScrollViewReader { proxy in
            List {
                ArchivedSeasonNote()
                    .listRowBackground(Color.clear)
                if days.isEmpty && undated.isEmpty {
                    EmptyStateText(text: String(localized: "Noch keine Spiele."))
                        .listRowBackground(Color.clear)
                }
                ForEach(days, id: \.day) { day in
                    Section {
                        ForEach(day.events) { event in
                            EventRow(event: event)
                        }
                        ForEach(day.games) { game in
                            ScheduleRow(game: game, detail: detail)
                        }
                    } header: {
                        Text(dayTitle(day.day))
                            .foregroundStyle(day.day == SwissTime.today ? Theme.qualifier : Theme.secondaryText)
                    }
                    .id(day.day)
                    .listRowBackground(Theme.card)
                }
                if !undated.isEmpty {
                    Section {
                        ForEach(undated) { game in
                            ScheduleRow(game: game, detail: detail)
                        }
                    } header: {
                        Text("Noch ohne Termin")
                    } footer: {
                        Text("Beteiligte Teams können den Termin in der App oder auf der Website festlegen.")
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                // Start at today (or the next game day) instead of the season's first game.
                if let target = days.first(where: { $0.day >= SwissTime.today })?.day {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    private func games(_ detail: SeasonDetail) -> [Game] {
        var games = detail.allGames.filter(\.hasBothTeams)
        if onlyMine, let teamID = model.session?.team.id {
            games = games.filter { $0.involves(teamID) }
        }
        return games
    }

    private struct Day {
        let day: String
        var games: [Game] = []
        var events: [CalendarEvent] = []
    }

    private func scheduleDays(_ detail: SeasonDetail) -> [Day] {
        var byDay: [String: Day] = [:]
        for game in games(detail) {
            guard let date = game.playedDate else { continue }
            byDay[date, default: Day(day: date)].games.append(game)
        }
        if !onlyMine {
            for event in detail.events {
                byDay[event.date, default: Day(day: event.date)].events.append(event)
            }
        }
        return byDay.values
            .map { day in
                var day = day
                day.games.sort(by: Game.chronological)
                return day
            }
            .sorted { $0.day < $1.day }
    }

    private func dayTitle(_ day: String) -> String {
        guard let date = SwissTime.date(day: day) else { return day }
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().swiss)
        return day == SwissTime.today ? String(localized: "Heute, \(text)") : text
    }
}

/// Compact game row: time on the left, both teams stacked, sets on the right.
struct ScheduleRow: View {
    let game: Game
    let detail: SeasonDetail
    @Environment(Navigator.self) private var navigator
    @Environment(AppModel.self) private var model

    var body: some View {
        let teams = detail.teamsByID
        Button {
            navigator.open(game)
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    if let time = game.gameTime {
                        Text(time)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Text(game.title)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 74)

                VStack(alignment: .leading, spacing: 8) {
                    teamLine(game.teamAId.flatMap { teams[$0] }, sets: game.setsA)
                    teamLine(game.teamBId.flatMap { teams[$0] }, sets: game.setsB)
                }
                if model.canEdit(game) && !game.isComplete {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Theme.qualifier)
                        .accessibilityLabel(Text("Resultat eintragen"))
                }
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func teamLine(_ team: Team?, sets: Int?) -> some View {
        let isLoser = team != nil && game.winnerTeamId != nil && game.winnerTeamId != team?.id
        let isWinner = team != nil && game.winnerTeamId == team?.id
        return HStack {
            TeamLabel(team: team, avatarSize: 22, emphasized: isWinner, dimmed: isLoser)
            Spacer()
            if let sets {
                Text("\(sets)")
                    .font(.body.monospacedDigit().weight(.bold))
                    .foregroundStyle(isLoser ? Theme.secondaryText : .white)
            }
        }
    }
}

/// A calendar entry from the website (group draw, victory party, ...).
private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            Text(event.time ?? "")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .frame(width: 74)
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Theme.qualifier)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .fontWeight(.medium)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
