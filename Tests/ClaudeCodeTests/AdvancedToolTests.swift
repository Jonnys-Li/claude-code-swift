import XCTest
@testable import ClaudeCode

final class AdvancedToolTests: XCTestCase {

    // MARK: - Edit Tool Tests

    func testEditToolReplaceFirst() async throws {
        let tool = EditTool()

        // Create a test file
        let testFile = "/tmp/test_edit_\(UUID().uuidString).txt"
        let content = "Hello World\nGoodbye Swift\nHello World"
        try content.write(toFile: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: testFile)
        }

        // Replace unique string
        let result = try await tool.execute(parameters: [
            "file_path": testFile,
            "old_string": "Goodbye Swift",
            "new_string": "Hi Swift"
        ])

        XCTAssertFalse(result.isError)

        let newContent = try String(contentsOfFile: testFile, encoding: .utf8)
        XCTAssertEqual(newContent, "Hello World\nHi Swift\nHello World")
    }

    func testEditToolReplaceAll() async throws {
        let tool = EditTool()

        // Create a test file
        let testFile = "/tmp/test_edit_all_\(UUID().uuidString).txt"
        let content = "Hello World\nHello Swift\nHello World"
        try content.write(toFile: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: testFile)
        }

        // Replace all occurrences
        let result = try await tool.execute(parameters: [
            "file_path": testFile,
            "old_string": "Hello",
            "new_string": "Hi",
            "replace_all": "true"
        ])

        XCTAssertFalse(result.isError)

        let newContent = try String(contentsOfFile: testFile, encoding: .utf8)
        XCTAssertEqual(newContent, "Hi World\nHi Swift\nHi World")
    }

    func testEditToolNonUniqueString() async throws {
        let tool = EditTool()

        // Create a test file
        let testFile = "/tmp/test_edit_nonunique_\(UUID().uuidString).txt"
        let content = "Hello World\nHello Swift"
        try content.write(toFile: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: testFile)
        }

        // Try to replace non-unique string without replace_all
        let result = try await tool.execute(parameters: [
            "file_path": testFile,
            "old_string": "Hello",
            "new_string": "Hi"
        ])

        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("appears 2 times"))
    }

    // MARK: - Glob Tool Tests

    func testGlobToolFindSwiftFiles() async throws {
        let tool = GlobTool()

        // Create test directory with files
        let testDir = "/tmp/test_glob_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(atPath: testDir)
        }

        // Create test files
        try "test".write(toFile: "\(testDir)/file1.swift", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(testDir)/file2.swift", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(testDir)/file3.txt", atomically: true, encoding: .utf8)

        // Search for .swift files
        let result = try await tool.execute(parameters: [
            "pattern": "*.swift",
            "path": testDir
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("file1.swift"))
        XCTAssertTrue(result.content.contains("file2.swift"))
        XCTAssertFalse(result.content.contains("file3.txt"))
    }

    func testGlobToolRecursiveSearch() async throws {
        let tool = GlobTool()

        // Create nested directory structure
        let testDir = "/tmp/test_glob_recursive_\(UUID().uuidString)"
        let subDir = "\(testDir)/subdir"
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(atPath: testDir)
        }

        // Create test files
        try "test".write(toFile: "\(testDir)/root.swift", atomically: true, encoding: .utf8)
        try "test".write(toFile: "\(subDir)/nested.swift", atomically: true, encoding: .utf8)

        // Recursive search
        let result = try await tool.execute(parameters: [
            "pattern": "**/*.swift",
            "path": testDir
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("root.swift"))
        XCTAssertTrue(result.content.contains("nested.swift"))
    }

    // MARK: - Grep Tool Tests

    func testGrepToolBasicSearch() async throws {
        let tool = GrepTool()

        // Create test file
        let testDir = "/tmp/test_grep_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(atPath: testDir)
        }

        let testFile = "\(testDir)/test.txt"
        let content = "Hello World\nSwift is great\nHello Swift"
        try content.write(toFile: testFile, atomically: true, encoding: .utf8)

        // Search for "Swift"
        let result = try await tool.execute(parameters: [
            "pattern": "Swift",
            "path": testDir,
            "output_mode": "files_with_matches"
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("test.txt"))
    }

    func testGrepToolCaseInsensitive() async throws {
        let tool = GrepTool()

        // Create test file
        let testDir = "/tmp/test_grep_case_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(atPath: testDir)
        }

        let testFile = "\(testDir)/test.txt"
        let content = "HELLO world\nhello WORLD"
        try content.write(toFile: testFile, atomically: true, encoding: .utf8)

        // Case-insensitive search
        let result = try await tool.execute(parameters: [
            "pattern": "hello",
            "path": testDir,
            "case_insensitive": "true",
            "output_mode": "content"
        ])

        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("HELLO"))
        XCTAssertTrue(result.content.contains("hello"))
    }
}
