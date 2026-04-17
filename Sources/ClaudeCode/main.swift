import ArgumentParser
import Foundation

@main
struct ClaudeCodeCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claude-code",
        abstract: "Claude Code - AI-powered coding assistant",
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String?

    @Option(name: .long, help: "Anthropic API key")
    var apiKey: String?

    @Option(name: .shortAndLong, help: "Model to use (default: claude-opus-4-6)")
    var model: String?

    @Option(name: .long, help: "Maximum tokens for responses")
    var maxTokens: Int?

    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose = false

    mutating func run() async throws {
        print("Claude Code Swift v\(Self.configuration.version)")

        // Load configuration
        let fileConfig = try Configuration.load(from: config)

        // Merge CLI args with file config (CLI takes precedence)
        let finalApiKey = apiKey ?? fileConfig.apiKey
        let finalModel = model ?? fileConfig.model ?? "claude-opus-4-6"
        let finalMaxTokens = maxTokens ?? fileConfig.maxTokens ?? 4096

        if verbose {
            print("Configuration loaded:")
            print("  Model: \(finalModel)")
            print("  Max tokens: \(finalMaxTokens)")
            print("  API key: \(finalApiKey != nil ? "***" : "not set")")
        }

        guard finalApiKey != nil else {
            print("Error: API key not found. Set it via:")
            print("  1. --api-key flag")
            print("  2. ~/.claude/settings.json")
            print("  3. ANTHROPIC_API_KEY environment variable")
            throw ExitCode.failure
        }

        print("Starting REPL...")
        // TODO: Start REPL
    }
}
