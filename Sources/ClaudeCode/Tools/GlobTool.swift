import Foundation

/// Tool for finding files matching glob patterns
struct GlobTool: Tool {
    let name = "Glob"
    let description = "Find files matching glob patterns (e.g., '**/*.swift', 'src/**/*.txt')"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "Glob pattern to match files (e.g., '*.swift', '**/*.txt', 'src/**/*.json')"
                ],
                "path": [
                    "type": "string",
                    "description": "Directory to search in (defaults to current directory)"
                ]
            ],
            "required": ["pattern"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let pattern = parameters["pattern"] else {
            return .error("Missing required parameter: pattern")
        }

        let searchPath = parameters["path"] ?? "."

        // Check if search path exists
        guard FileManager.default.fileExists(atPath: searchPath) else {
            return .error("Path not found: \(searchPath)")
        }

        // Use find command with pattern matching
        // Convert glob pattern to find-compatible pattern
        let findPattern = convertGlobToFindPattern(pattern)

        let command: String
        if pattern.contains("**") {
            // Recursive search
            command = "find \"\(escapeShellArgument(searchPath))\" -type f -name \"\(escapeShellArgument(findPattern))\" 2>/dev/null | sort"
        } else {
            // Non-recursive search
            command = "find \"\(escapeShellArgument(searchPath))\" -maxdepth 1 -type f -name \"\(escapeShellArgument(findPattern))\" 2>/dev/null | sort"
        }

        // Execute command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            if output.isEmpty {
                return .success("No files found matching pattern: \(pattern)")
            }

            // Count and format results
            let files = output.split(separator: "\n").map(String.init)
            let fileCount = files.count

            return .success("Found \(fileCount) file\(fileCount != 1 ? "s" : ""):\n\(output)")
        } else {
            return .error("Glob search failed")
        }
    }

    private func convertGlobToFindPattern(_ glob: String) -> String {
        // Remove leading **/ for find command
        if glob.hasPrefix("**/") {
            return String(glob.dropFirst(3))
        }
        return glob
    }

    private func escapeShellArgument(_ arg: String) -> String {
        // Escape special characters for shell
        return arg.replacingOccurrences(of: "\\", with: "\\\\")
                  .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
