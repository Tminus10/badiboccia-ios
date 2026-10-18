import Foundation
import Security

/// A logged-in team: the API token plus the team it belongs to.
struct TeamSession: Codable, Hashable, Sendable {
    let token: String
    let team: Team
}

/// Stores the team session in the Keychain, one entry per server.
enum SessionStore {
    private static let service = "swiss.reutener.boccia.session"

    static func load(for server: ServerEnvironment) -> TeamSession? {
        var query = baseQuery(server)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(TeamSession.self, from: data)
    }

    static func save(_ session: TeamSession?, for server: ServerEnvironment) {
        SecItemDelete(baseQuery(server) as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var query = baseQuery(server)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func baseQuery(_ server: ServerEnvironment) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: server.rawValue,
        ]
    }
}

/// Last-known API responses on disk, so the app opens instantly and still shows something offline.
enum ResponseCache {
    private static var directory: URL {
        URL.cachesDirectory.appending(path: "api", directoryHint: .isDirectory)
    }

    static func read(_ key: String, server: ServerEnvironment) -> Data? {
        try? Data(contentsOf: file(key, server))
    }

    static func write(_ data: Data, key: String, server: ServerEnvironment) {
        let url = file(key, server)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func file(_ key: String, _ server: ServerEnvironment) -> URL {
        directory.appending(path: server.rawValue, directoryHint: .isDirectory).appending(path: "\(key).json")
    }
}
