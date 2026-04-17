import Foundation

/// Core query engine that manages the conversation loop
actor QueryEngine {
    private let client: AnthropicClient
    private let toolRegistry: ToolRegistry
    private let model: String
    private let maxTokens: Int

    private var conversationHistory: [Message] = []
    private var systemPrompt: String?

    init(
        apiKey: String,
        model: String = "claude-opus-4-6",
        maxTokens: Int = 4096
    ) {
        self.client = AnthropicClient(apiKey: apiKey)
        self.toolRegistry = ToolRegistry()
        self.model = model
        self.maxTokens = maxTokens
    }

    /// Set the system prompt
    func setSystemPrompt(_ prompt: String) {
        self.systemPrompt = prompt
    }

    /// Register a tool
    func registerTool(_ tool: Tool) async {
        await toolRegistry.register(tool)
    }

    /// Execute a query and return the response
    func query(_ userMessage: String) async throws -> String {
        // Add user message to history
        conversationHistory.append(.user(userMessage))

        // Main conversation loop
        var continueLoop = true
        var finalResponse = ""

        while continueLoop {
            // Get tool definitions
            let toolDefs = await toolRegistry.getToolDefinitions()

            // Call API
            let response = try await client.sendMessage(
                model: model,
                messages: conversationHistory,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: toolDefs.isEmpty ? nil : toolDefs
            )

            // Add assistant response to history
            let assistantMessage = Message(role: .assistant, content: response.content)
            conversationHistory.append(assistantMessage)

            // Process response content
            var toolResults: [ContentBlock] = []
            var hasToolUse = false

            for block in response.content {
                switch block {
                case .text(let text):
                    finalResponse += text

                case .toolUse(let id, let name, let input):
                    hasToolUse = true
                    print("🔧 Calling tool: \(name)")

                    // Execute tool
                    let result = await executeTool(name: name, input: input)

                    // Add tool result to next message
                    toolResults.append(.toolResult(
                        toolUseId: id,
                        content: result.content,
                        isError: result.isError
                    ))

                case .toolResult:
                    // Tool results shouldn't appear in assistant messages
                    break
                }
            }

            // If there were tool calls, send results back
            if hasToolUse {
                conversationHistory.append(Message(role: .user, content: toolResults))
            } else {
                // No more tool calls, we're done
                continueLoop = false
            }

            // Check stop reason
            if response.stopReason == "end_turn" || response.stopReason == "max_tokens" {
                continueLoop = false
            }
        }

        return finalResponse
    }

    /// Execute a tool by name
    private func executeTool(name: String, input: [String: String]) async -> ToolResult {
        guard let tool = await toolRegistry.getTool(named: name) else {
            return .error("Tool '\(name)' not found")
        }

        do {
            return try await tool.execute(parameters: input)
        } catch {
            return .error("Tool execution failed: \(error.localizedDescription)")
        }
    }

    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
    }

    /// Get conversation history
    func getHistory() -> [Message] {
        conversationHistory
    }
}
