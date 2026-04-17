import Foundation

/// Tool for reading file contents
struct ReadTool: Tool {
    let name = "read"
    let description = "Read the contents of a file. Supports reading specific line ranges."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ],
                "offset": [
                    "type": "string",
                    "description": "Optional line number to start reading from (0-indexed)"
                ],
                "limit": [
                    "type": "string",
                    "description": "Optional number of lines to read"
                ]
            ],
            "required": ["file_path"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] else {
            return .error("Missing required parameter: file_path")
        }

        // Expand ~ to home directory
        let expandedPath = NSString(string: filePath).expandingTildeInPath

        // Check if file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return .error("File not found: \(filePath)")
        }

        // Check if it's a directory
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            return .error("Path is a directory, not a file: \(filePath)")
        }

        do {
            let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            // Parse offset and limit
            let offset = parameters["offset"].flatMap { Int($0) } ?? 0
            let limit = parameters["limit"].flatMap { Int($0) }

            // Validate offset
            guard offset >= 0 && offset < lines.count else {
                return .error("Invalid offset: \(offset). File has \(lines.count) lines.")
            }

            // Calculate range
            let startIndex = offset
            let endIndex: Int
            if let limit = limit {
                endIndex = min(startIndex + limit, lines.count)
            } else {
                endIndex = lines.count
            }

            // Extract lines
            let selectedLines = Array(lines[startIndex..<endIndex])

            // Format output with line numbers
            var output = ""
            for (index, line) in selectedLines.enumerated() {
                let lineNumber = startIndex + index + 1
                output += "\(lineNumber)\t\(line)\n"
            }

            return .success(output)

        } catch {
            return .error("Failed to read file: \(error.localizedDescription)")
        }
    }
}
