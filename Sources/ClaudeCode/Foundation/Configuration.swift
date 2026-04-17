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

        var config: Configuration
        if FileManager.default.fileExists(atPath: configPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            config = try JSONDecoder().decode(Configuration.self, from: data)
        } else {
            config = Configuration.default
        }

        // Override with environment variable if present
        if let envApiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            config = Configuration(
                apiKey: envApiKey,
                model: config.model,
                permissionMode: config.permissionMode,
                maxTokens: config.maxTokens
            )
        }

        return config
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
