import XCTest
@testable import ClaudeCode

final class PermissionTests: XCTestCase {
    func testAutoModeAllowsAllTools() async {
        let manager = PermissionManager(mode: .auto)

        let allowed = await manager.isAllowed(toolName: "Bash")
        XCTAssertTrue(allowed, "Auto mode should allow all tools")
    }

    func testPromptModeRequiresConfirmation() async {
        let manager = PermissionManager(mode: .prompt)

        let requiresConfirm = await manager.requiresConfirmation(toolName: "Bash")
        XCTAssertTrue(requiresConfirm, "Prompt mode should require confirmation")
    }

    func testManualModeRequiresConfirmation() async {
        let manager = PermissionManager(mode: .manual)

        let requiresConfirm = await manager.requiresConfirmation(toolName: "Read")
        XCTAssertTrue(requiresConfirm, "Manual mode should require confirmation")
    }

    func testAllowAlwaysDecision() async {
        let manager = PermissionManager(mode: .prompt)

        // Initially requires confirmation
        var requiresConfirm = await manager.requiresConfirmation(toolName: "Bash")
        XCTAssertTrue(requiresConfirm)

        // Apply allow always decision
        await manager.applyDecision(.allowAlways(toolName: "Bash"))

        // Should no longer require confirmation
        requiresConfirm = await manager.requiresConfirmation(toolName: "Bash")
        XCTAssertFalse(requiresConfirm)

        // Should be allowed
        let allowed = await manager.isAllowed(toolName: "Bash")
        XCTAssertTrue(allowed)
    }

    func testDenyAlwaysDecision() async {
        let manager = PermissionManager(mode: .auto)

        // Initially allowed in auto mode
        var allowed = await manager.isAllowed(toolName: "Bash")
        XCTAssertTrue(allowed)

        // Apply deny always decision
        await manager.applyDecision(.denyAlways(toolName: "Bash"))

        // Should now be denied
        allowed = await manager.isAllowed(toolName: "Bash")
        XCTAssertFalse(allowed)
    }

    func testResetClearsDecisions() async {
        let manager = PermissionManager(mode: .prompt)

        // Apply allow always
        await manager.applyDecision(.allowAlways(toolName: "Bash"))
        let allowed = await manager.isAllowed(toolName: "Bash")
        XCTAssertTrue(allowed)

        // Reset
        await manager.reset()

        // Should require confirmation again
        let requiresConfirm = await manager.requiresConfirmation(toolName: "Bash")
        XCTAssertTrue(requiresConfirm)
    }

    func testDangerousToolDetection() {
        XCTAssertTrue(PermissionPrompt.isDangerousTool("Bash"))
        XCTAssertTrue(PermissionPrompt.isDangerousTool("Write"))
        XCTAssertTrue(PermissionPrompt.isDangerousTool("Edit"))
        XCTAssertTrue(PermissionPrompt.isDangerousTool("Agent"))
        XCTAssertFalse(PermissionPrompt.isDangerousTool("Read"))
    }
}
