import XCTest
@testable import ClaudeCode

final class StreamingTests: XCTestCase {
    func testStreamEventDecoding() throws {
        // Test message_start event
        let messageStartJSON = """
        {
            "type": "message_start",
            "message": {
                "id": "msg_123",
                "type": "message",
                "role": "assistant",
                "model": "claude-opus-4-6",
                "usage": {
                    "input_tokens": 10,
                    "output_tokens": 0
                }
            }
        }
        """

        let messageStartData = messageStartJSON.data(using: .utf8)!
        let messageStartEvent = try JSONDecoder().decode(StreamEvent.self, from: messageStartData)
        XCTAssertEqual(messageStartEvent.type, "message_start")
        XCTAssertNotNil(messageStartEvent.message)
        XCTAssertEqual(messageStartEvent.message?.id, "msg_123")
    }

    func testTextDeltaDecoding() throws {
        // Test content_block_delta with text
        let textDeltaJSON = """
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {
                "type": "text_delta",
                "text": "Hello"
            }
        }
        """

        let textDeltaData = textDeltaJSON.data(using: .utf8)!
        let textDeltaEvent = try JSONDecoder().decode(StreamEvent.self, from: textDeltaData)
        XCTAssertEqual(textDeltaEvent.type, "content_block_delta")
        XCTAssertEqual(textDeltaEvent.index, 0)
        XCTAssertNotNil(textDeltaEvent.delta)
        XCTAssertEqual(textDeltaEvent.delta?.type, "text_delta")
        XCTAssertEqual(textDeltaEvent.delta?.text, "Hello")
    }

    func testContentBlockStartDecoding() throws {
        // Test content_block_start with text block
        let blockStartJSON = """
        {
            "type": "content_block_start",
            "index": 0,
            "content_block": {
                "type": "text",
                "text": ""
            }
        }
        """

        let blockStartData = blockStartJSON.data(using: .utf8)!
        let blockStartEvent = try JSONDecoder().decode(StreamEvent.self, from: blockStartData)
        XCTAssertEqual(blockStartEvent.type, "content_block_start")
        XCTAssertEqual(blockStartEvent.index, 0)
        XCTAssertNotNil(blockStartEvent.contentBlock)
    }

    func testMessageStopDecoding() throws {
        // Test message_stop event
        let messageStopJSON = """
        {
            "type": "message_stop"
        }
        """

        let messageStopData = messageStopJSON.data(using: .utf8)!
        let messageStopEvent = try JSONDecoder().decode(StreamEvent.self, from: messageStopData)
        XCTAssertEqual(messageStopEvent.type, "message_stop")
    }
}
