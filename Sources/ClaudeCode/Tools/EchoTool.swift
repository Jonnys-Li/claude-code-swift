import Foundation

/// Simple echo tool for testing
struct EchoTool: Tool {
    let name = "echo"
    let description = "Echoes back the input message"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "message": [
                    "type": "string",
                    "description": "The message to echo back"
                ]
            ],
            "required": ["message"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let message = parameters["message"] else {
            return .error("Missing 'message' parameter")
        }

        return .success("Echo: \(message)")
    }
}
