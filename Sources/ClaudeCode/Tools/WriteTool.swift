import Foundation

/// Tool for writing content to files
struct WriteTool: Tool {
    let name = "write"
    let description = "Write content to a file. Creates the file if it doesn't exist, overwrites if it does."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "The absolute path to the file to write"
                ],
                "content": [
                    "type": "string",
                    "description": "The content to write to the file"
                ]
            ],
            "required": ["file_path", "content"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] else {
            return .error("Missing required parameter: file_path")
        }

        guard let content = parameters["content"] else {
            return .error("Missing required parameter: content")
        }

        // Expand ~ to home directory
        let expandedPath = NSString(string: filePath).expandingTildeInPath

        // Create parent directory if needed
        let parentDir = (expandedPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parentDir) {
            do {
                try FileManager.default.createDirectory(
                    atPath: parentDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                return .error("Failed to create parent directory: \(error.localizedDescription)")
            }
        }

        // Check if path is a directory
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return .error("Path is a directory, not a file: \(filePath)")
        }

        // Write the file
        do {
            try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)

            // Get file size for confirmation
            let attributes = try FileManager.default.attributesOfItem(atPath: expandedPath)
            let fileSize = attributes[.size] as? Int64 ?? 0

            return .success("File written successfully: \(filePath) (\(fileSize) bytes)")
        } catch {
            return .error("Failed to write file: \(error.localizedDescription)")
        }
    }
}
