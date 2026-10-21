import SwiftUI

@main
struct BocciaScoreApp: App {
    @State private var model = AppModel()
    @State private var navigator = Navigator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(navigator)
                .preferredColorScheme(.dark)
                .tint(Theme.qualifier)
        }
    }
}

/// Screen-independent navigation: the game sheet can be opened from any tab.
@MainActor
@Observable
final class Navigator {
    var presentedGame: GameRef?
    var selectedTab: AppTab = .overview

    init() {
        // `-tab bracket` launch argument opens a specific tab (handy for screenshots and UI checks).
        if let tab = UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:)) {
            selectedTab = tab
        }
    }

    func open(_ game: Game) { presentedGame = GameRef(id: game.id) }
}

/// Only the id: the sheet always looks up the latest version of the game, e.g. right after a result was saved.
struct GameRef: Identifiable, Hashable {
    let id: Int
}

enum AppTab: String, Hashable {
    case overview, bracket, schedule, team
}

/// Pushed screens, shared by every tab's NavigationStack.
enum Route: Hashable {
    case team(id: Int, seasonID: Int?)
}

extension View {
    func appDestinations() -> some View {
        navigationDestination(for: Route.self) { $0.destination }
    }
}

extension Route {
    @ViewBuilder
    var destination: some View {
        switch self {
        case let .team(id, seasonID):
            TeamDetailView(teamID: id, initialSeasonID: seasonID)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var navigator = navigator
        TabView(selection: $navigator.selectedTab) {
            Tab("Übersicht", systemImage: "sportscourt", value: AppTab.overview) {
                NavigationStack { OverviewView().appDestinations() }
            }
            Tab("Turnierbaum", systemImage: "trophy", value: AppTab.bracket) {
                NavigationStack { BracketView().appDestinations() }
            }
            Tab("Spielplan", systemImage: "calendar", value: AppTab.schedule) {
                NavigationStack { ScheduleView().appDestinations() }
            }
            Tab("Mein Team", systemImage: "person.2", value: AppTab.team) {
                NavigationStack { MyTeamView().appDestinations() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .serverIndicatorLine()
        .sheet(item: $navigator.presentedGame) { ref in
            NavigationStack {
                GameDetailView(gameID: ref.id).appDestinations()
            }
            .serverIndicatorLine()
            .presentationDetents([.large])
            .presentationBackground(Theme.backgroundBottom)
        }
        .task {
            await model.refresh()
            await model.validateSession()
        }
        // Keep scores fresh while the app is open: results come in from other teams' phones.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await model.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }
}
