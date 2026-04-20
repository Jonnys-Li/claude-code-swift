import Foundation

/// Tool for editing files with precise string replacement
struct EditTool: Tool {
    let name = "Edit"
    let description = "Edit files by replacing exact string matches"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "Absolute path to the file to edit"
                ],
                "old_string": [
                    "type": "string",
                    "description": "The exact string to replace"
                ],
                "new_string": [
                    "type": "string",
                    "description": "The replacement string"
                ],
                "replace_all": [
                    "type": "boolean",
                    "description": "Replace all occurrences (default: false, only first occurrence)"
                ]
            ],
            "required": ["file_path", "old_string", "new_string"]
        ]
    }

    func execute(parameters: [String: String]) async throws -> ToolResult {
        guard let filePath = parameters["file_path"] else {
            return .error("Missing required parameter: file_path")
        }

        guard let oldString = parameters["old_string"] else {
            return .error("Missing required parameter: old_string")
        }

        guard let newString = parameters["new_string"] else {
            return .error("Missing required parameter: new_string")
        }

        let replaceAll = parameters["replace_all"] == "true"

        // Check if file exists
        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return .error("File not found: \(filePath)")
        }

        // Read file content
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return .error("Failed to read file: \(filePath)")
        }

        // Check if old_string exists in content
        guard content.contains(oldString) else {
            return .error("String not found in file: '\(oldString)'")
        }

        // Check for uniqueness if not replace_all
        if !replaceAll {
            let occurrences = content.components(separatedBy: oldString).count - 1
            if occurrences > 1 {
                return .error("String appears \(occurrences) times in file. Use replace_all: true to replace all occurrences, or provide a more specific old_string.")
            }
        }

        // Perform replacement
        let newContent: String
        if replaceAll {
            newContent = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            // Replace only first occurrence
            if let range = content.range(of: oldString) {
                newContent = content.replacingCharacters(in: range, with: newString)
            } else {
                return .error("String not found in file")
            }
        }

        // Write back to file
        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)

            let occurrenceCount = replaceAll ?
                (content.components(separatedBy: oldString).count - 1) : 1

            return .success("Successfully edited \(filePath) (\(occurrenceCount) replacement\(occurrenceCount > 1 ? "s" : ""))")
        } catch {
            return .error("Failed to write file: \(error.localizedDescription)")
        }
    }
}
