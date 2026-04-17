import ArgumentParser
import Foundation

@main
struct ClaudeCodeCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claude-code",
        abstract: "Claude Code - AI-powered coding assistant",
        version: "0.1.0"
    )

    @Flag(name: .shortAndLong, help: "Show version information")
    var version = false

    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String?

    mutating func run() async throws {
        print("Claude Code Swift v\(Self.configuration.version ?? "unknown")")
        print("Starting REPL...")

        // TODO: Initialize configuration
        // TODO: Start REPL
    }
}
