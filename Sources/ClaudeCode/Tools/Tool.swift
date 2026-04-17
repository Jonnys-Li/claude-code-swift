import Foundation

/// Protocol for tools that can be called by Claude
protocol Tool: Sendable {
    /// Unique name of the tool
    var name: String { get }

    /// Description of what the tool does
    var description: String { get }

    /// JSON schema for the tool's input parameters
    var inputSchema: [String: Any] { get }

    /// Execute the tool with given parameters
    func execute(parameters: [String: String]) async throws -> ToolResult
}

/// Result from tool execution
struct ToolResult: Sendable {
    let content: String
    let isError: Bool

    init(content: String, isError: Bool = false) {
        self.content = content
        self.isError = isError
    }

    static func success(_ content: String) -> ToolResult {
        ToolResult(content: content, isError: false)
    }

    static func error(_ message: String) -> ToolResult {
        ToolResult(content: message, isError: true)
    }
}

/// Registry for managing available tools
actor ToolRegistry {
    private var tools: [String: Tool] = [:]

    func register(_ tool: Tool) {
        tools[tool.name] = tool
    }

    func getTool(named name: String) -> Tool? {
        tools[name]
    }

    func getAllTools() -> [Tool] {
        Array(tools.values)
    }
}
