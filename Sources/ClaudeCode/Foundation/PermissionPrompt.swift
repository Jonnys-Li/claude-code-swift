import Foundation

/// Handles user prompts for permission decisions
struct PermissionPrompt {
    /// Prompt user for permission to execute a tool
    static func promptForPermission(toolName: String, parameters: [String: Any]) async -> PermissionDecision {
        print("\n⚠️  Permission required:")
        print("Tool: \(toolName)")
        print("Parameters:")
        for (key, value) in parameters {
            print("  \(key): \(value)")
        }
        print("\nOptions:")
        print("  [a] Allow once")
        print("  [d] Deny once")
        print("  [A] Allow always for \(toolName)")
        print("  [D] Deny always for \(toolName)")
        print("\nYour choice: ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return .deny
        }

        switch input {
        case "a":
            return .allow
        case "d":
            return .deny
        case "A":
            return .allowAlways(toolName: toolName)
        case "D":
            return .denyAlways(toolName: toolName)
        default:
            print("Invalid choice, denying by default.")
            return .deny
        }
    }

    /// Check if a tool is considered dangerous and should always prompt
    static func isDangerousTool(_ toolName: String) -> Bool {
        let dangerousTools = [
            "Bash",
            "Write",
            "Edit",
            "Agent"
        ]
        return dangerousTools.contains(toolName)
    }
}
