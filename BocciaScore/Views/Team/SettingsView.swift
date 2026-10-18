import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if ServerEnvironment.selectable.count > 1 {
                Section {
                    Picker("Server", selection: Binding(get: { model.server }, set: { server in
                        Task { await model.switchServer(to: server) }
                    })) {
                        ForEach(ServerEnvironment.selectable) { server in
                            Text(server.title).tag(server)
                        }
                    }
                } footer: {
                    Text("Nur in Entwicklungs-Builds sichtbar. Die Anmeldung gilt jeweils pro Server.")
                }
                .listRowBackground(Theme.card)
            }

            Section {
                Link(destination: model.server.websiteURL) {
                    Label("Website öffnen", systemImage: "safari")
                }
                Link(destination: model.server.websiteURL.appending(path: "regeln")) {
                    Label("Spielregeln", systemImage: "book")
                }
                Link(destination: model.server.websiteURL.appending(path: "calendar")) {
                    Label("Kalender abonnieren", systemImage: "calendar.badge.plus")
                }
            } footer: {
                Text("Saisons, Teams und den Turnierbaum verwalten Admins weiterhin auf der Website.")
            }
            .listRowBackground(Theme.card)

            Section {
                LabeledContent("Version", value: Bundle.main.versionText)
                if let updated = model.lastUpdated {
                    LabeledContent("Zuletzt aktualisiert", value: updated.formatted(date: .omitted, time: .shortened))
                }
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .themedScreen()
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .close) { dismiss() }
            }
        }
    }
}

private extension Bundle {
    var versionText: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
