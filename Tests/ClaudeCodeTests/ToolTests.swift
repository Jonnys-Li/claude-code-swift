import XCTest
@testable import ClaudeCode

final class ToolTests: XCTestCase {

    func testReadTool() async throws {
        let tool = ReadTool()

        // Create a test file
        let testPath = "/tmp/test_read_tool.txt"
        let testContent = "Line 1\nLine 2\nLine 3\n"
        try testContent.write(toFile: testPath, atomically: true, encoding: .utf8)

        // Test reading entire file
        let result = try await tool.execute(parameters: ["file_path": testPath])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Line 1"))
        XCTAssertTrue(result.content.contains("Line 2"))

        // Clean up
        try? FileManager.default.removeItem(atPath: testPath)
    }

    func testWriteTool() async throws {
        let tool = WriteTool()

        let testPath = "/tmp/test_write_tool.txt"
        let testContent = "Hello, World!"

        // Test writing
        let result = try await tool.execute(parameters: [
            "file_path": testPath,
            "content": testContent
        ])

        XCTAssertFalse(result.isError)

        // Verify file was written
        let writtenContent = try String(contentsOfFile: testPath, encoding: .utf8)
        XCTAssertEqual(writtenContent, testContent)

        // Clean up
        try? FileManager.default.removeItem(atPath: testPath)
    }

    func testBashTool() async throws {
        let tool = BashTool()

        // Test simple command
        let result = try await tool.execute(parameters: ["command": "echo 'Hello'"])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Hello"))
    }

    func testEchoTool() async throws {
        let tool = EchoTool()

        let result = try await tool.execute(parameters: ["message": "Test message"])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("Test message"))
    }
}
