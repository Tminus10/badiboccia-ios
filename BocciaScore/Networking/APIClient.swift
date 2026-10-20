import Foundation

/// Which BadiBoccia website the app talks to.
enum ServerEnvironment: String, CaseIterable, Identifiable, Codable, Sendable {
    case production
    case development
    case local

    var id: String { rawValue }

    var websiteURL: URL {
        switch self {
        case .production: URL(string: "https://boccia.reutener.swiss")!
        case .development: URL(string: "https://dev.boccia.reutener.swiss")!
        // The website's ./dev/serve.sh; reachable from the iOS Simulator, not from a device.
        case .local: URL(string: "http://localhost:8090")!
        }
    }

    var apiBaseURL: URL { websiteURL.appending(path: "api/v1") }

    /// A website page in the app's language: the website switches (and stays) there via `?lang=`.
    func websitePage(_ path: String = "") -> URL {
        let url = path.isEmpty ? websiteURL : websiteURL.appending(path: path)
        guard let language = Bundle.main.preferredLocalizations.first else { return url }
        return url.appending(queryItems: [URLQueryItem(name: "lang", value: language)])
    }

    var title: String {
        switch self {
        case .production: String(localized: "Produktiv")
        case .development: String(localized: "Entwicklung (DEV)")
        case .local: String(localized: "Lokal (localhost:8090)")
        }
    }

    /// Short tag shown in the app while it isn't on the live site (`ServerIndicator`); nil for production.
    var badge: String? {
        switch self {
        case .production: nil
        case .development: "DEV"
        case .local: "LOCAL"
        }
    }

    /// Release builds only offer the live site; debug builds can switch to DEV or the local dev server.
    static var selectable: [ServerEnvironment] {
        #if DEBUG
        allCases
        #else
        [.production]
        #endif
    }

    static var `default`: ServerEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}

struct APIError: LocalizedError, Sendable {
    /// The API's error code (`wrong_pin`, `schedule_conflict`, ...) or one of the client-side codes below.
    let code: String
    let status: Int?
    let serverMessage: String?
    var conflicts: [Game] = []

    static let networkCode = "network"
    static let notSupportedCode = "api_missing"
    static let invalidResponseCode = "invalid_response"

    var isUnauthorized: Bool { code == "unauthorized" }

    var errorDescription: String? {
        switch code {
        case "wrong_pin": String(localized: "Falscher PIN. Bitte versuche es nochmals.")
        case "locked_out": String(localized: "Zu viele Fehlversuche. Bitte versuche es in 15 Minuten erneut.")
        case "unauthorized": String(localized: "Deine Anmeldung ist abgelaufen. Bitte melde dich erneut an.")
        case "season_archived": String(localized: "Diese Saison ist archiviert und kann nicht mehr bearbeitet werden.")
        case "not_participant": String(localized: "Nur die beiden beteiligten Teams können dieses Spiel bearbeiten.")
        case "opponent_unknown": String(localized: "Für dieses Spiel steht der Gegner noch nicht fest.")
        case "invalid_score": String(localized: "Ungültiges Resultat. Erlaubt sind 2:0, 2:1, 1:2, 0:2 und 1:1.")
        case "draw_not_allowed": String(localized: "Ein Unentschieden ist nur in der Gruppenphase möglich.")
        case "invalid_date": String(localized: "Ungültiges Datum.")
        case "invalid_time": String(localized: "Ungültige Uhrzeit.")
        case "not_found": String(localized: "Nicht gefunden.")
        case "no_current_season": String(localized: "Es läuft gerade keine Saison.")
        case "not_own_team": String(localized: "Du kannst nur das Foto deines eigenen Teams ändern.")
        case "invalid_photo": String(localized: "Das Foto konnte nicht verarbeitet werden. Bitte wähle ein anderes Bild.")
        case "schedule_conflict": String(localized: "Zu dieser Zeit ist bereits ein anderes Spiel geplant.")
        case Self.networkCode: String(localized: "Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung.")
        case Self.notSupportedCode: String(localized: "Dieser Server unterstützt die App noch nicht.")
        default: serverMessage ?? String(localized: "Unerwartete Antwort vom Server.")
        }
    }
}

/// Thin async wrapper around the website's JSON API.
struct APIClient: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    // MARK: Endpoints

    func info() async throws -> APIInfo { try await get("") }
    func seasons() async throws -> [SeasonSummary] { try await (get("seasons") as SeasonsResponse).seasons }

    /// The season plus the raw response, so it can be cached as-is.
    func season(id: Int) async throws -> (SeasonDetail, Data) {
        let data = try await send(request(path: "seasons/\(id)"))
        return (try decodeBody(SeasonDetail.self, from: data), data)
    }

    func team(id: Int) async throws -> TeamDetail { try await get("teams/\(id)") }

    func login(teamID: Int, pin: String, device: String) async throws -> LoginResponse {
        try await post("auth/login", body: LoginRequest(teamId: teamID, pin: pin, device: device))
    }

    func logout(token: String) async throws {
        _ = try await send(request(path: "auth/logout", method: "POST", token: token))
    }

    func me(token: String) async throws -> Team { try await (get("me", token: token) as MeResponse).team }

    func submitResult(gameID: Int, _ body: ResultRequest, token: String) async throws -> Game {
        try await (post("games/\(gameID)/result", body: body, token: token) as GameResponse).game
    }

    func schedule(gameID: Int, _ body: ScheduleRequest, token: String) async throws -> Game {
        try await (post("games/\(gameID)/schedule", body: body, token: token) as GameResponse).game
    }

    /// Replaces the team's photo; `jpeg` should already be square (the server crops to the center).
    func uploadPhoto(teamID: Int, jpeg: Data, token: String) async throws -> Team {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = request(path: "teams/\(teamID)/photo", method: "POST", token: token)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 60
        return try decodeBody(MeResponse.self, from: try await send(request)).team
    }

    // MARK: Plumbing

    private func get<T: Decodable>(_ path: String, token: String? = nil) async throws -> T {
        try decodeBody(T.self, from: try await send(request(path: path, token: token)))
    }

    private func post<T: Decodable>(_ path: String, body: some Encodable, token: String? = nil) async throws -> T {
        var request = request(path: path, method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        return try decodeBody(T.self, from: try await send(request))
    }

    private func request(path: String, method: String = "GET", token: String? = nil) -> URLRequest {
        let url = path.isEmpty ? baseURL : baseURL.appending(path: path)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // Some shared-hosting PHP setups drop the Authorization header; the API accepts this too.
            request.setValue(token, forHTTPHeaderField: "X-Api-Token")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError(code: APIError.networkCode, status: nil, serverMessage: error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let isJSON = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.contains("json") ?? false
        if (200..<300).contains(status), isJSON {
            return data
        }
        if isJSON, let body = try? Self.decoder.decode(APIErrorBody.self, from: data) {
            throw APIError(code: body.error, status: status, serverMessage: body.message, conflicts: body.conflicts ?? [])
        }
        // An HTML page instead of JSON: the website exists but has no API yet (not deployed there).
        throw APIError(code: APIError.notSupportedCode, status: status, serverMessage: nil)
    }

    private func decodeBody<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw APIError(code: APIError.invalidResponseCode, status: nil, serverMessage: nil)
        }
    }
}
