import Foundation

/// Permission mode for tool execution
enum PermissionMode: String, Codable {
    /// Always allow tool execution without prompting
    case auto

    /// Prompt user for confirmation before executing tools
    case prompt

    /// Never execute tools automatically (manual mode)
    case manual
}

/// Permission decision for a specific tool call
enum PermissionDecision {
    case allow
    case deny
    case allowAlways(toolName: String)
    case denyAlways(toolName: String)
}

/// Manages permission decisions and persistence
actor PermissionManager {
    private let mode: PermissionMode
    private var allowedTools: Set<String> = []
    private var deniedTools: Set<String> = []

    init(mode: PermissionMode) {
        self.mode = mode
    }

    /// Check if a tool execution requires user confirmation
    func requiresConfirmation(toolName: String) -> Bool {
        // If tool is in allowed list, no confirmation needed
        if allowedTools.contains(toolName) {
            return false
        }

        // If tool is in denied list, always deny
        if deniedTools.contains(toolName) {
            return false
        }

        // Check mode
        switch mode {
        case .auto:
            return false
        case .prompt:
            return true
        case .manual:
            return true
        }
    }

    /// Apply a permission decision
    func applyDecision(_ decision: PermissionDecision) {
        switch decision {
        case .allow:
            break // One-time allow, no persistence
        case .deny:
            break // One-time deny, no persistence
        case .allowAlways(let toolName):
            allowedTools.insert(toolName)
            deniedTools.remove(toolName)
        case .denyAlways(let toolName):
            deniedTools.insert(toolName)
            allowedTools.remove(toolName)
        }
    }

    /// Check if a tool is allowed to execute
    func isAllowed(toolName: String) async -> Bool {
        // Check denied list first
        if deniedTools.contains(toolName) {
            return false
        }

        // Check allowed list
        if allowedTools.contains(toolName) {
            return true
        }

        // Check mode
        switch mode {
        case .auto:
            return true
        case .prompt, .manual:
            return false // Requires explicit confirmation
        }
    }

    /// Reset all permission decisions
    func reset() {
        allowedTools.removeAll()
        deniedTools.removeAll()
    }
}
