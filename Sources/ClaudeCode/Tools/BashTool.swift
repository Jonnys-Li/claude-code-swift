import Foundation

/// Tool for executing bash commands
struct BashTool: Tool {
    let name = "bash"
    let description = "Execute a bash command and return its output. Use with caution."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The bash command to execute"
                ],
                "timeout": [
                    "type": "string",
                    "description": "Optional timeout in seconds (default: 30)"
                ]
            ],
            "required": ["command"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let command = parameters["command"] else {
            return .error("Missing required parameter: command")
        }

        let timeout = parameters["timeout"].flatMap { Double($0) } ?? 30.0

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            // Start process
            try process.run()

            // Wait with timeout
            let startTime = Date()
            while process.isRunning {
                if Date().timeIntervalSince(startTime) > timeout {
                    process.terminate()
                    return .error("Command timed out after \(timeout) seconds")
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }

            // Wait for process to complete
            process.waitUntilExit()

            // Read output after process completes
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let exitCode = process.terminationStatus
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            // Format result
            var result = ""
            if !output.isEmpty {
                result += output
            }
            if !errorOutput.isEmpty {
                if !result.isEmpty {
                    result += "\n"
                }
                result += "stderr:\n\(errorOutput)"
            }

            if exitCode != 0 {
                result += "\n\nExit code: \(exitCode)"
                return .error(result)
            }

            return .success(result.isEmpty ? "(no output)" : result)

        } catch {
            return .error("Failed to execute command: \(error.localizedDescription)")
        }
    }
}
