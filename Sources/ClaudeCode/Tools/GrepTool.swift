import Foundation

/// Tool for searching file contents with regex patterns
struct GrepTool: Tool {
    let name = "Grep"
    let description = "Search for patterns in files using regular expressions"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "Regular expression pattern to search for"
                ],
                "path": [
                    "type": "string",
                    "description": "File or directory path to search in (defaults to current directory)"
                ],
                "glob": [
                    "type": "string",
                    "description": "Glob pattern to filter files (e.g., '*.swift', '**/*.txt')"
                ],
                "case_insensitive": [
                    "type": "boolean",
                    "description": "Perform case-insensitive search"
                ],
                "output_mode": [
                    "type": "string",
                    "enum": ["content", "files_with_matches", "count"],
                    "description": "Output mode: content (show matching lines), files_with_matches (show file paths), count (show match counts)"
                ],
                "context": [
                    "type": "integer",
                    "description": "Number of lines to show before and after each match"
                ],
                "head_limit": [
                    "type": "integer",
                    "description": "Limit output to first N results (default: 250)"
                ]
            ],
            "required": ["pattern"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let pattern = parameters["pattern"] else {
            return .error("Missing required parameter: pattern")
        }

        let path = parameters["path"] ?? "."
        let glob = parameters["glob"]
        let caseInsensitive = parameters["case_insensitive"] == "true"
        let outputMode = parameters["output_mode"] ?? "files_with_matches"
        let context = Int(parameters["context"] ?? "0") ?? 0
        let headLimit = Int(parameters["head_limit"] ?? "250") ?? 250

        // Build grep command
        var command = "grep -r"

        if caseInsensitive {
            command += " -i"
        }

        // Add line numbers for content mode
        if outputMode == "content" {
            command += " -n"
        }

        // Add context lines
        if context > 0 && outputMode == "content" {
            command += " -C \(context)"
        }

        // Add count mode
        if outputMode == "count" {
            command += " -c"
        }

        // Add files-only mode
        if outputMode == "files_with_matches" {
            command += " -l"
        }

        // Add pattern
        command += " -E \"\(escapeShellArgument(pattern))\""

        // Add path
        command += " \"\(escapeShellArgument(path))\""

        // Add glob filter if specified
        if let glob = glob {
            command += " --include=\"\(escapeShellArgument(glob))\""
        }

        // Add head limit
        command += " 2>/dev/null | head -n \(headLimit)"

        // Execute command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        // Grep returns exit code 1 when no matches found, which is not an error
        if process.terminationStatus == 0 || process.terminationStatus == 1 {
            if output.isEmpty {
                return .success("No matches found")
            }
            return .success(output)
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            return .error("Grep failed: \(error)")
        }
    }

    private func escapeShellArgument(_ arg: String) -> String {
        // Escape single quotes and backslashes
        return arg.replacingOccurrences(of: "\\", with: "\\\\")
                  .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
