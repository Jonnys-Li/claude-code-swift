import Foundation

/// Core query engine that manages the conversation loop
actor QueryEngine {
    private let client: AnthropicClient
    private let toolRegistry: ToolRegistry
    private let permissionManager: PermissionManager
    private let model: String
    private let maxTokens: Int

    private var conversationHistory: [Message] = []
    private var systemPrompt: String?

    init(
        apiKey: String,
        model: String = "claude-opus-4-6",
        maxTokens: Int = 4096,
        permissionMode: PermissionMode = .prompt
    ) {
        self.client = AnthropicClient(apiKey: apiKey)
        self.toolRegistry = ToolRegistry()
        self.permissionManager = PermissionManager(mode: permissionMode)
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

    /// Execute a query with streaming and return the response
    func queryStreaming(_ userMessage: String) async throws -> String {
        // Add user message to history
        conversationHistory.append(.user(userMessage))

        // Main conversation loop
        var continueLoop = true
        var finalResponse = ""

        while continueLoop {
            // Get tool definitions
            let tools = await toolRegistry.getAllTools()

            // Call streaming API
            let stream = try await client.sendMessageStreaming(
                model: model,
                messages: conversationHistory,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: tools.isEmpty ? nil : tools
            )

            // Accumulate response
            var contentBlocks: [ContentBlock] = []
            var currentTextBlock = ""

            for try await event in stream {
                switch event.type {
                case "message_start":
                    // Message started
                    break

                case "content_block_start":
                    // New content block started
                    if let block = event.contentBlock {
                        switch block {
                        case .text:
                            currentTextBlock = ""
                        case .toolUse:
                            break
                        case .toolResult:
                            break
                        }
                    }

                case "content_block_delta":
                    // Content delta received
                    if let delta = event.delta {
                        if delta.type == "text_delta", let text = delta.text {
                            currentTextBlock += text
                            print(text, terminator: "")
                            fflush(stdout)
                        }
                    }

                case "content_block_stop":
                    // Content block finished
                    if !currentTextBlock.isEmpty {
                        contentBlocks.append(.text(currentTextBlock))
                        finalResponse += currentTextBlock
                        currentTextBlock = ""
                    }

                case "message_delta":
                    // Message metadata update
                    break

                case "message_stop":
                    // Message finished
                    continueLoop = false

                default:
                    break
                }
            }

            print() // New line after streaming

            // Add assistant response to history
            let assistantMessage = Message(role: .assistant, content: contentBlocks)
            conversationHistory.append(assistantMessage)

            // Process tool uses
            var toolResults: [ContentBlock] = []
            var hasToolUse = false

            for block in contentBlocks {
                if case .toolUse(let id, let name, let input) = block {
                    hasToolUse = true
                    print("🔧 Tool requested: \(name)")

                    // Check permissions
                    let isAllowed = await checkPermission(toolName: name, input: input)

                    if isAllowed {
                        // Execute tool
                        let result = await executeTool(name: name, input: input)

                        toolResults.append(.toolResult(
                            toolUseId: id,
                            content: result.content,
                            isError: result.isError
                        ))
                    } else {
                        toolResults.append(.toolResult(
                            toolUseId: id,
                            content: "Permission denied by user",
                            isError: true
                        ))
                    }
                }
            }

            // If there were tool calls, send results back
            if hasToolUse {
                conversationHistory.append(Message(role: .user, content: toolResults))
                continueLoop = true
            }
        }

        return finalResponse
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
            let tools = await toolRegistry.getAllTools()

            // Call API
            let response = try await client.sendMessage(
                model: model,
                messages: conversationHistory,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: tools.isEmpty ? nil : tools
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
                    print("🔧 Tool requested: \(name)")

                    // Check permissions
                    let isAllowed = await checkPermission(toolName: name, input: input)

                    if isAllowed {
                        // Execute tool
                        let result = await executeTool(name: name, input: input)

                        // Add tool result to next message
                        toolResults.append(.toolResult(
                            toolUseId: id,
                            content: result.content,
                            isError: result.isError
                        ))
                    } else {
                        // Permission denied
                        toolResults.append(.toolResult(
                            toolUseId: id,
                            content: "Permission denied by user",
                            isError: true
                        ))
                    }

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

    /// Check permission for tool execution
    private func checkPermission(toolName: String, input: [String: String]) async -> Bool {
        // Check if permission is already granted
        if await permissionManager.isAllowed(toolName: toolName) {
            return true
        }

        // Check if confirmation is required
        if await permissionManager.requiresConfirmation(toolName: toolName) {
            // Convert input to [String: Any] for display
            let inputAny = input.reduce(into: [String: Any]()) { $0[$1.key] = $1.value }

            // Prompt user
            let decision = await PermissionPrompt.promptForPermission(
                toolName: toolName,
                parameters: inputAny
            )

            // Apply decision
            await permissionManager.applyDecision(decision)

            // Return result
            switch decision {
            case .allow, .allowAlways:
                return true
            case .deny, .denyAlways:
                return false
            }
        }

        // Default: check if allowed
        return await permissionManager.isAllowed(toolName: toolName)
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
