import Foundation
import Observation
import UIKit

/// App-wide state: which server and season are shown, the loaded season data, and the team login.
@MainActor
@Observable
final class AppModel {
    private(set) var server: ServerEnvironment
    private(set) var seasons: [SeasonSummary] = []
    private(set) var details: [Int: SeasonDetail] = [:]
    private(set) var session: TeamSession?
    private(set) var isLoading = false
    private(set) var lastError: APIError?
    private(set) var lastUpdated: Date?
    /// The server's demo season and its public PIN ("Demo ausprobieren"); nil while unknown or if there's none.
    private(set) var demo: DemoInfo?

    /// The season shown in all tabs; nil until the season list has loaded.
    var selectedSeasonID: Int? {
        didSet {
            guard selectedSeasonID != oldValue else { return }
            UserDefaults.standard.set(selectedSeasonID, forKey: Keys.selectedSeason)
            Task { await loadSelectedSeason() }
        }
    }

    private var client: APIClient { APIClient(baseURL: server.apiBaseURL) }

    private enum Keys {
        static let server = "server"
        static let selectedSeason = "selectedSeason"
    }

    init() {
        let defaults = UserDefaults.standard
        var server = defaults.string(forKey: Keys.server).flatMap(ServerEnvironment.init(rawValue:)) ?? .default
        // `-server local|development|production` launch argument, for testing against a specific website.
        if let override = defaults.string(forKey: "server").flatMap(ServerEnvironment.init(rawValue:)) {
            server = override
        }
        if !ServerEnvironment.selectable.contains(server) {
            server = .production
        }
        self.server = server
        self.session = SessionStore.load(for: server)
        self.selectedSeasonID = defaults.object(forKey: Keys.selectedSeason) as? Int
        loadCache()
    }

    // MARK: - Derived state

    /// A demo team plays in the demo season, which isn't part of the league's season list: while
    /// one is logged in, `seasons` also holds the demo season and it stands in for the current one.
    var isDemoSession: Bool { session?.team.isDemo == true }

    /// The season the user plays in: the running season, or the demo season in a demo session.
    var currentSeason: SeasonSummary? {
        isDemoSession ? seasons.first { $0.isDemo == true } : seasons.first(where: \.isCurrent)
    }

    var selectedSeason: SeasonSummary? { seasons.first { $0.id == selectedSeasonID } }

    var selectedDetail: SeasonDetail? { selectedSeasonID.flatMap { details[$0] } }

    var currentDetail: SeasonDetail? { currentSeason.flatMap { details[$0.id] } }

    /// Whether the logged-in team may enter a result or a date for this game (same rules as the website).
    func canEdit(_ game: Game) -> Bool {
        guard let session, game.hasBothTeams, game.involves(session.team.id),
              let season = seasons.first(where: { $0.id == game.seasonId }) else { return false }
        return season.isCurrent || season.isDemo == true
    }

    // MARK: - Loading

    /// Reloads the season list and the selected season. Safe to call often (pull to refresh, timer, foreground).
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let info = try? client.info()
            var seasons = try await client.seasons()
            if let info = await info {
                demo = info.demoSeasonId.map { DemoInfo(seasonID: $0, pin: info.demoPin ?? "") }
            }
            if isDemoSession, let demo {
                try? await loadSeason(id: demo.seasonID)
            }
            // Checked again after loading: the team may have logged out in the meantime.
            if isDemoSession, let demo, let summary = details[demo.seasonID]?.season {
                seasons.insert(summary, at: 0)
            }
            self.seasons = seasons
            if let data = try? JSONEncoder.snakeCase.encode(SeasonsResponse(seasons: seasons)) {
                ResponseCache.write(data, key: "seasons", server: server)
            }
            if selectedSeasonID == nil || !seasons.contains(where: { $0.id == selectedSeasonID }) {
                // didSet loads the newly selected season.
                selectedSeasonID = (currentSeason ?? seasons.first)?.id
            } else {
                await loadSelectedSeason()
            }
            if let current = currentSeason, current.id != selectedSeasonID, details[current.id] == nil {
                try? await loadSeason(id: current.id)
            }
            lastError = nil
        } catch is CancellationError {
        } catch let error as APIError {
            lastError = error
        } catch {}
    }

    private func loadSelectedSeason() async {
        guard let id = selectedSeasonID else { return }
        do {
            try await loadSeason(id: id)
            lastError = nil
        } catch let error as APIError {
            lastError = error
        } catch {}
    }

    func loadSeason(id: Int) async throws {
        let (detail, data) = try await client.season(id: id)
        details[id] = detail
        lastUpdated = .now
        ResponseCache.write(data, key: "season-\(id)", server: server)
    }

    func teamDetail(id: Int) async throws -> TeamDetail {
        try await client.team(id: id)
    }

    /// Loads the demo season's teams for "Demo ausprobieren".
    func loadDemoSeason() async throws {
        guard let demo else { return }
        try await loadSeason(id: demo.seasonID)
    }

    private func loadCache() {
        if let data = ResponseCache.read("seasons", server: server),
           let cached = try? APIClient.decode(SeasonsResponse.self, from: data) {
            seasons = isDemoSession ? cached.seasons : cached.seasons.filter { $0.isDemo != true }
        }
        for season in seasons {
            if let data = ResponseCache.read("season-\(season.id)", server: server),
               let detail = try? APIClient.decode(SeasonDetail.self, from: data) {
                details[season.id] = detail
            }
        }
    }

    // MARK: - Server

    func switchServer(to server: ServerEnvironment) async {
        guard server != self.server else { return }
        self.server = server
        UserDefaults.standard.set(server.rawValue, forKey: Keys.server)
        seasons = []
        details = [:]
        lastError = nil
        session = SessionStore.load(for: server)
        selectedSeasonID = nil
        loadCache()
        await refresh()
    }

    // MARK: - Team login

    func login(teamID: Int, pin: String) async throws {
        let response = try await client.login(teamID: teamID, pin: pin, device: UIDevice.current.name)
        let session = TeamSession(token: response.token, team: response.team)
        self.session = session
        SessionStore.save(session, for: server)
        if isDemoSession {
            await refresh()
            selectedSeasonID = currentSeason?.id
        }
    }

    func logout() async {
        if let token = session?.token {
            try? await client.logout(token: token)
        }
        endSession()
    }

    /// Checks the stored token is still valid (it's revoked when an admin resets the team's PIN).
    func validateSession() async {
        guard let token = session?.token else { return }
        do {
            let team = try await client.me(token: token)
            let updated = TeamSession(token: token, team: team)
            if updated != session {
                session = updated
                SessionStore.save(updated, for: server)
            }
        } catch let error as APIError where error.isUnauthorized {
            endSession()
        } catch {}
    }

    private func endSession() {
        let wasDemo = isDemoSession
        session = nil
        SessionStore.save(nil, for: server)
        if wasDemo {
            seasons.removeAll { $0.isDemo == true }
            if selectedSeason == nil {
                selectedSeasonID = (currentSeason ?? seasons.first)?.id
            }
        }
    }

    // MARK: - Result entry

    func submitResult(for game: Game, score: Score, date: Date?, time: Date?) async throws {
        let request = ResultRequest(
            setsA: score.a,
            setsB: score.b,
            playedDate: date.map(SwissTime.dayString),
            gameTime: time.map(SwissTime.timeString)
        )
        try await authorized { try await self.client.submitResult(gameID: game.id, request, token: $0) }
        try? await loadSeason(id: game.seasonId)
    }

    /// Throws an `APIError` with code `schedule_conflict` (and the clashing games) unless `force` is set.
    func schedule(_ game: Game, date: Date, time: Date?, force: Bool) async throws {
        let request = ScheduleRequest(
            playedDate: SwissTime.dayString(date),
            gameTime: time.map(SwissTime.timeString),
            force: force
        )
        try await authorized { try await self.client.schedule(gameID: game.id, request, token: $0) }
        try? await loadSeason(id: game.seasonId)
    }

    // MARK: - Team photo

    /// Uploads a new photo for the logged-in team, then reloads so every avatar shows it
    /// (the photo URL carries a version, so cached images of the old photo aren't reused).
    func uploadPhoto(_ image: UIImage) async throws {
        guard let teamID = session?.team.id else {
            throw APIError(code: "unauthorized", status: 401, serverMessage: nil)
        }
        guard let jpeg = image.squareJPEG(side: 1000) else {
            throw APIError(code: "invalid_photo", status: nil, serverMessage: nil)
        }
        let team = try await authorized { try await self.client.uploadPhoto(teamID: teamID, jpeg: jpeg, token: $0) }
        if let token = session?.token {
            let updated = TeamSession(token: token, team: team)
            session = updated
            SessionStore.save(updated, for: server)
        }
        await refresh()
    }

    /// Runs a call with the session token; a rejected token logs the team out.
    @discardableResult
    private func authorized<T>(_ call: (String) async throws -> T) async throws -> T {
        guard let token = session?.token else {
            throw APIError(code: "unauthorized", status: 401, serverMessage: nil)
        }
        do {
            return try await call(token)
        } catch let error as APIError where error.isUnauthorized {
            endSession()
            throw error
        }
    }
}

struct DemoInfo: Equatable, Sendable {
    let seasonID: Int
    let pin: String
}

extension JSONEncoder {
    static var snakeCase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

extension UIImage {
    /// Center-cropped square JPEG, at most `side` points wide. Drawing also bakes in the photo's
    /// orientation and converts HEIC, which the website can't read.
    func squareJPEG(side: CGFloat, quality: CGFloat = 0.85) -> Data? {
        let crop = min(size.width, size.height)
        guard crop > 0 else { return nil }
        let target = min(side, crop)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format)
        let scale = target / crop
        return renderer.jpegData(withCompressionQuality: quality) { _ in
            draw(in: CGRect(
                x: -(size.width - crop) / 2 * scale,
                y: -(size.height - crop) / 2 * scale,
                width: size.width * scale,
                height: size.height * scale
            ))
        }
    }
}
