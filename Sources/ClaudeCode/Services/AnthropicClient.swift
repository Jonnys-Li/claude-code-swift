import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

/// Client for Anthropic Claude API
actor AnthropicClient {
    private let apiKey: String
    private let httpClient: HTTPClient
    private let baseURL = "https://api.anthropic.com/v1"

    init(apiKey: String) {
        self.apiKey = apiKey
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }

    deinit {
        try? httpClient.syncShutdown()
    }

    /// Send a message to Claude API with streaming
    func sendMessageStreaming(
        model: String,
        messages: [Message],
        maxTokens: Int,
        system: String? = nil,
        tools: [Tool]? = nil
    ) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // Build request body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": try messages.map { try encodeMessage($0) },
            "stream": true
        ]

        if let system = system {
            body["system"] = system
        }

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.inputSchema
                ]
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var request = HTTPClientRequest(url: "\(baseURL)/messages")
        request.method = .POST
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: jsonData))

        let response = try await httpClient.execute(request, timeout: .seconds(120))

        guard response.status == .ok else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024)
            let errorText = String(buffer: bodyBytes)
            throw APIError.httpError(statusCode: Int(response.status.code), message: errorText)
        }

        // Return streaming events
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""

                    for try await chunk in response.body {
                        let text = String(buffer: chunk)
                        buffer += text

                        // Process SSE events
                        let lines = buffer.components(separatedBy: "\n")
                        buffer = lines.last ?? ""

                        for line in lines.dropLast() {
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))

                                if jsonString == "[DONE]" {
                                    continuation.finish()
                                    return
                                }

                                if let data = jsonString.data(using: .utf8),
                                   let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {
                                    continuation.yield(event)
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Send a message to Claude API
    func sendMessage(
        model: String,
        messages: [Message],
        maxTokens: Int,
        system: String? = nil,
        tools: [Tool]? = nil
    ) async throws -> APIResponse {
        // Build request body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": try messages.map { try encodeMessage($0) }
        ]

        if let system = system {
            body["system"] = system
        }

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.inputSchema
                ]
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var request = HTTPClientRequest(url: "\(baseURL)/messages")
        request.method = .POST
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: jsonData))

        let response = try await httpClient.execute(request, timeout: .seconds(120))

        guard response.status == .ok else {
            let bodyBytes = try await response.body.collect(upTo: 1024 * 1024)
            let errorText = String(buffer: bodyBytes)
            throw APIError.httpError(statusCode: Int(response.status.code), message: errorText)
        }

        let bodyBytes = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let responseData = Data(buffer: bodyBytes)

        do {
            return try JSONDecoder().decode(APIResponse.self, from: responseData)
        } catch {
            throw APIError.decodingError("Failed to decode response: \(error.localizedDescription)")
        }
    }

    private func encodeMessage(_ message: Message) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw APIError.encodingError("Failed to encode message")
        }
        return dict
    }
}

/// API Response from Claude
struct APIResponse: Codable, Sendable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    struct Usage: Codable, Sendable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

/// Stream event from Claude API
struct StreamEvent: Codable, Sendable {
    let type: String
    let index: Int?
    let delta: Delta?
    let contentBlock: ContentBlock?
    let message: StreamMessage?

    enum CodingKeys: String, CodingKey {
        case type, index, delta
        case contentBlock = "content_block"
        case message
    }

    struct Delta: Codable, Sendable {
        let type: String
        let text: String?
        let partialJson: String?

        enum CodingKeys: String, CodingKey {
            case type, text
            case partialJson = "partial_json"
        }
    }

    struct StreamMessage: Codable, Sendable {
        let id: String
        let type: String
        let role: String
        let model: String
        let usage: APIResponse.Usage
    }
}

/// API Errors
enum APIError: Error, CustomStringConvertible {
    case httpError(statusCode: Int, message: String)
    case encodingError(String)
    case decodingError(String)
    case invalidResponse

    var description: String {
        switch self {
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .invalidResponse:
            return "Invalid API response"
        }
    }
}
