import SwiftUI

/// Entering (or correcting) a result: pick the set score, optionally when it was played.
/// Mirrors the website's result form: 2:0, 2:1, 1:2, 0:2, and 1:1 for an interrupted group game.
struct ResultEntryView: View {
    let game: Game
    let teamA: Team?
    let teamB: Team?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var score: Score?
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var isSaving = false
    @State private var error: APIError?

    init(game: Game, teamA: Team?, teamB: Team?) {
        self.game = game
        self.teamA = teamA
        self.teamB = teamB
        _score = State(initialValue: game.setsA.flatMap { a in game.setsB.map { Score(a: a, b: $0) } })
        let start = game.startDate ?? .now
        // Off for a game without a date, so saving a result never invents one; switching it on suggests today.
        _hasDate = State(initialValue: game.playedDate != nil)
        _date = State(initialValue: start)
        _hasTime = State(initialValue: game.gameTime != nil)
        _time = State(initialValue: game.gameTime != nil ? start : SwissTime.date(day: SwissTime.today, time: "18:00") ?? .now)
    }

    var body: some View {
        Form {
            Section {
                ForEach(game.allowedScores) { option in
                    Button {
                        score = option
                    } label: {
                        ScoreOptionRow(score: option, teamA: teamA, teamB: teamB, isSelected: option == score)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Resultat (Sätze) · \(teamA?.name ?? "–") – \(teamB?.name ?? "–")")
            } footer: {
                if game.phase == .group {
                    Text("1:1 nur für ein unterbrochenes Gruppenspiel, z. B. wegen Regen.")
                }
            }
            .listRowBackground(Theme.card)

            Section("Gespielt am") {
                Toggle("Datum", isOn: $hasDate.animation())
                if hasDate {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .environment(\.timeZone, SwissTime.timeZone)
                    Toggle("Uhrzeit", isOn: $hasTime.animation())
                    if hasTime {
                        QuarterHourTimePicker(title: "Uhrzeit", selection: $time)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .themedScreen()
        .navigationTitle(game.isComplete ? "Resultat korrigieren" : "Resultat eintragen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Speichern", systemImage: "checkmark") { save() }
                        .disabled(score == nil)
                }
            }
        }
        .alert(isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }), error: error) {
            Button("OK", role: .cancel) {}
        }
        .sensoryFeedback(.success, trigger: isSaving) { old, new in old && !new && error == nil }
    }

    private func save() {
        guard let score else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await model.submitResult(
                    for: game,
                    score: score,
                    date: hasDate ? date : nil,
                    time: hasDate && hasTime ? time : nil
                )
                dismiss()
            } catch let apiError as APIError {
                error = apiError
            } catch {}
        }
    }
}

/// "2 : 1  [avatar] Sandra & Thomi gewinnt" -- the score with whoever it makes the winner.
private struct ScoreOptionRow: View {
    let score: Score
    let teamA: Team?
    let teamB: Team?
    let isSelected: Bool

    private var winner: Team? { score.a > score.b ? teamA : (score.b > score.a ? teamB : nil) }

    private var caption: String {
        if score.isDraw { return String(localized: "Unterbrochen – je 1 Punkt") }
        return String(localized: "\(winner?.name ?? "–") gewinnt")
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(score.a) : \(score.b)")
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .fixedSize()
            if score.isDraw {
                Image(systemName: "cloud.rain")
                    .frame(width: 26)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                TeamAvatar(team: winner, size: 26)
            }
            Text(caption)
                .foregroundStyle(score.isDraw ? Theme.secondaryText : .white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Theme.qualifier : Theme.tertiaryText)
                .font(.title3)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(teamA?.name ?? "") \(score.a) zu \(score.b) \(teamB?.name ?? "")"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Fixing the date (and optionally the time) of a game. A clash with another planned game is a
/// warning, not an error -- like on the website, the team can save anyway.
struct ScheduleGameView: View {
    let game: Game
    let teamA: Team?
    let teamB: Team?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var isSaving = false
    @State private var error: APIError?
    @State private var conflicts: [Game] = []

    init(game: Game, teamA: Team?, teamB: Team?) {
        self.game = game
        self.teamA = teamA
        self.teamB = teamB
        let start = game.startDate ?? .now
        _date = State(initialValue: start)
        _hasTime = State(initialValue: game.playedDate == nil || game.gameTime != nil)
        _time = State(initialValue: game.gameTime != nil ? start : SwissTime.date(day: SwissTime.today, time: "18:00") ?? .now)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.timeZone, SwissTime.timeZone)
                Toggle("Uhrzeit", isOn: $hasTime.animation())
                if hasTime {
                    QuarterHourTimePicker(title: "Uhrzeit", selection: $time)
                }
            } footer: {
                Text("Ohne Uhrzeit erscheint das Spiel als ganztägiger Termin im Kalender.")
            }
            .listRowBackground(Theme.card)
        }
        .themedScreen()
        .navigationTitle(game.playedDate == nil ? "Termin festlegen" : "Termin ändern")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Speichern", systemImage: "checkmark") { save(force: false) }
                }
            }
        }
        .alert(isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }), error: error) {
            Button("OK", role: .cancel) {}
        }
        .alert("Terminüberschneidung", isPresented: Binding(get: { !conflicts.isEmpty }, set: { if !$0 { conflicts = [] } })) {
            Button("Trotzdem speichern") { save(force: true) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
    }

    private var conflictMessage: String {
        let teams = model.details[game.seasonId]?.teamsByID ?? [:]
        let lines = conflicts.map { other in
            let a = other.teamAId.flatMap { teams[$0]?.name } ?? "–"
            let b = other.teamBId.flatMap { teams[$0]?.name } ?? "–"
            let when = other.gameTime ?? String(localized: "ganztags")
            return "• \(when): \(a) – \(b)"
        }
        return String(localized: "Zu dieser Zeit ist bereits ein anderes Spiel geplant:") + "\n" + lines.joined(separator: "\n")
    }

    private func save(force: Bool) {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await model.schedule(game, date: date, time: hasTime ? time : nil, force: force)
                dismiss()
            } catch let apiError as APIError where apiError.code == "schedule_conflict" {
                conflicts = apiError.conflicts
            } catch let apiError as APIError {
                error = apiError
            } catch {}
        }
    }
}
