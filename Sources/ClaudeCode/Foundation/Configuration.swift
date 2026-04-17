import Foundation

/// Application configuration loaded from settings.json
struct Configuration: Codable {
    let apiKey: String?
    let model: String?
    let permissionMode: PermissionMode?
    let maxTokens: Int?

    enum PermissionMode: String, Codable {
        case alwaysAllow = "always-allow"
        case alwaysAsk = "always-ask"
        case promptBased = "prompt-based"
    }

    static func load(from path: String? = nil) throws -> Configuration {
        let configPath = path ?? defaultConfigPath()

        guard FileManager.default.fileExists(atPath: configPath) else {
            return Configuration.default
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        return try JSONDecoder().decode(Configuration.self, from: data)
    }

    static func defaultConfigPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/settings.json").path
    }

    static let `default` = Configuration(
        apiKey: nil,
        model: "claude-opus-4-6",
        permissionMode: .alwaysAsk,
        maxTokens: 4096
    )
}
