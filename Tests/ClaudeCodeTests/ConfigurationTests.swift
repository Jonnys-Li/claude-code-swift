import XCTest
@testable import ClaudeCode

final class ConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = Configuration.default
        XCTAssertEqual(config.model, "claude-opus-4-6")
        XCTAssertEqual(config.permissionMode, .alwaysAsk)
        XCTAssertEqual(config.maxTokens, 4096)
    }

    func testConfigurationDecoding() throws {
        let json = """
        {
            "apiKey": "test-key",
            "model": "claude-sonnet-4-6",
            "permissionMode": "always-allow",
            "maxTokens": 8192
        }
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(Configuration.self, from: data)

        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.model, "claude-sonnet-4-6")
        XCTAssertEqual(config.permissionMode, .alwaysAllow)
        XCTAssertEqual(config.maxTokens, 8192)
    }
}
