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

    /// Send a message to Claude API
    func sendMessage(
        model: String,
        messages: [Message],
        maxTokens: Int,
        system: String? = nil,
        tools: [[String: String]]? = nil
    ) async throws -> APIResponse {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": try messages.map { try encodeMessage($0) }
        ]

        if let system = system {
            body["system"] = system
        }

        if let tools = tools {
            body["tools"] = tools
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

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

        return try JSONDecoder().decode(APIResponse.self, from: responseData)
    }

    private func encodeMessage(_ message: Message) throws -> [String: Any] {
        let encoder = JSONEncoder()
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
