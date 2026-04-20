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

    @Flag(name: .long, help: "Disable streaming (use non-streaming API)")
    var noStreaming = false

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

        guard let apiKey = finalApiKey else {
            print("Error: API key not found. Set it via:")
            print("  1. --api-key flag")
            print("  2. ~/.claude/settings.json")
            print("  3. ANTHROPIC_API_KEY environment variable")
            throw ExitCode.failure
        }

        // Initialize QueryEngine
        let permissionMode: PermissionMode
        if let configMode = fileConfig.permissionMode {
            switch configMode {
            case .alwaysAllow:
                permissionMode = .auto
            case .alwaysAsk:
                permissionMode = .prompt
            case .promptBased:
                permissionMode = .prompt
            }
        } else {
            permissionMode = .prompt
        }

        let engine = QueryEngine(
            apiKey: apiKey,
            model: finalModel,
            maxTokens: finalMaxTokens,
            permissionMode: permissionMode
        )

        // Register tools
        await engine.registerTool(EchoTool())
        await engine.registerTool(ReadTool())
        await engine.registerTool(WriteTool())
        await engine.registerTool(BashTool())
        await engine.registerTool(EditTool())
        await engine.registerTool(GrepTool())
        await engine.registerTool(GlobTool())

        if verbose {
            print("Query engine initialized with 7 tools")
        }

        // Simple REPL loop
        print("\nClaude Code REPL - Type 'exit' to quit\n")

        while true {
            print("> ", terminator: "")
            guard let input = readLine(), !input.isEmpty else {
                continue
            }

            if input.lowercased() == "exit" || input.lowercased() == "quit" {
                print("Goodbye!")
                break
            }

            do {
                let response: String
                if noStreaming {
                    response = try await engine.query(input)
                    print("\n\(response)\n")
                } else {
                    response = try await engine.queryStreaming(input)
                    print() // Extra newline after streaming
                }
            } catch {
                print("Error: \(error.localizedDescription)\n")
            }
        }
    }
}
