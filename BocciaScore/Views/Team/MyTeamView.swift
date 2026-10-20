import SwiftUI

/// Logged out: pick your team and enter its PIN (same PIN as on the website).
/// Logged in: your team's open games with quick access to result entry, then its played games.
struct MyTeamView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false

    var body: some View {
        Group {
            if let session = model.session {
                LoggedInView(team: session.team)
            } else {
                TeamPickerView()
            }
        }
        .themedScreen()
        .navigationTitle(model.session == nil ? "Anmelden" : "Mein Team")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Einstellungen", systemImage: "gearshape") { showsSettings = true }
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack { SettingsView() }
                .serverIndicatorLine()
                .presentationBackground(Theme.backgroundBottom)
        }
    }
}

// MARK: - Logged out

private struct TeamPickerView: View {
    @Environment(AppModel.self) private var model
    @State private var loginTeam: Team?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "person.2.badge.key.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.qualifier)
                    Text("Tippe auf dein Team und gib euren 4-stelligen PIN ein. Danach könnt ihr Resultate und Termine eurer Spiele eintragen.")
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            if let detail = model.currentDetail {
                ForEach(detail.groups) { group in
                    Section("Gruppe \(group.name)") {
                        ForEach(teams(in: group, detail: detail)) { team in
                            Button {
                                loginTeam = team
                            } label: {
                                HStack {
                                    TeamLabel(team: team, avatarSize: 32)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            } else if model.seasons.isEmpty || model.currentSeason != nil {
                SeasonLoadingState()
                    .listRowBackground(Color.clear)
            } else {
                EmptyStateText(text: String(localized: "Es läuft gerade keine Saison. Anmelden ist nur während einer laufenden Saison nötig."))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.refresh() }
        .sheet(item: $loginTeam) { team in
            PINEntryView(team: team)
                .serverIndicatorLine()
                .presentationDetents([.large])
                .presentationBackground(Theme.backgroundBottom)
        }
    }

    private func teams(in group: TeamGroup, detail: SeasonDetail) -> [Team] {
        detail.teams.filter { $0.groupId == group.id }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// iOS-passcode-style PIN pad.
struct PINEntryView: View {
    let team: Team
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var error: APIError?
    @State private var isChecking = false
    @State private var shakes = 0

    private let length = 4

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button(role: .close) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Schliessen"))
                Spacer()
            }
            Spacer(minLength: 0)
            TeamAvatar(team: team, size: 72)
            VStack(spacing: 6) {
                Text(team.name)
                    .font(.title2.weight(.bold))
                Text("PIN eingeben")
                    .foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: 18) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                        .background(Circle().fill(index < pin.count ? .white : .clear))
                        .frame(width: 16, height: 16)
                }
            }
            .modifier(Shake(animatableData: CGFloat(shakes)))
            .accessibilityElement()
            .accessibilityLabel(Text("\(pin.count) von \(length) Ziffern eingegeben"))

            Text(error?.localizedDescription ?? " ")
                .font(.footnote)
                .foregroundStyle(.red.mix(with: .white, by: 0.3))
                .multilineTextAlignment(.center)
                .frame(minHeight: 36)

            keypad
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .background(ThemeBackground())
        .sensoryFeedback(.error, trigger: shakes)
        .disabled(isChecking)
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 76, height: 76)
        } else if key == "⌫" {
            Button {
                if !pin.isEmpty { pin.removeLast() }
            } label: {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Löschen"))
        } else {
            Button {
                type(key)
            } label: {
                Text(key)
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                    .frame(width: 76, height: 76)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private func type(_ digit: String) {
        guard pin.count < length else { return }
        error = nil
        pin.append(digit)
        if pin.count == length {
            submit()
        }
    }

    private func submit() {
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                try await model.login(teamID: team.id, pin: pin)
                dismiss()
            } catch let apiError as APIError {
                error = apiError
                pin = ""
                withAnimation(.default) { shakes += 1 }
            } catch {}
        }
    }
}

/// Horizontal shake for a wrong PIN.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

// MARK: - Logged in

private struct LoggedInView: View {
    let team: Team
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var navigator

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.team(id: team.id, seasonID: model.currentSeason?.id)) {
                    HStack(spacing: 14) {
                        TeamAvatar(team: team, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .font(.title3.weight(.bold))
                            if let subtitle = team.playersSubtitle {
                                Text(subtitle)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Label("Angemeldet", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.qualifier)
                        }
                    }
                    .padding(.vertical, 6)
                }
                TeamPhotoPicker(team: team)
            }
            .listRowBackground(Theme.card)

            if let detail = model.currentDetail {
                let mine = detail.allGames.filter { $0.involves(team.id) && $0.hasBothTeams }
                let open = mine.filter { !$0.isComplete }.sorted(by: Game.chronological)
                let played = mine.filter(\.isComplete).sorted(by: Game.chronological).reversed()

                Section {
                    if open.isEmpty {
                        Text("Keine offenen Spiele.")
                            .foregroundStyle(Theme.secondaryText)
                    }
                    ForEach(open) { game in
                        ScheduleRow(game: game, detail: detail)
                    }
                } header: {
                    Text("Offene Spiele")
                } footer: {
                    if !open.isEmpty {
                        Text("Tippe auf ein Spiel, um das Resultat oder den Termin einzutragen.")
                    }
                }
                .listRowBackground(Theme.card)

                if !played.isEmpty {
                    Section("Gespielt") {
                        ForEach(Array(played)) { game in
                            ScheduleRow(game: game, detail: detail)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            } else if model.currentSeason == nil, !model.seasons.isEmpty {
                Section {
                    Text("Es läuft gerade keine Saison.")
                        .foregroundStyle(Theme.secondaryText)
                }
                .listRowBackground(Theme.card)
            }

            Section {
                Button("Abmelden", role: .destructive) {
                    Task { await model.logout() }
                }
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await model.refresh()
            await model.validateSession()
        }
    }
}
