import Foundation

struct AICoachReply: Equatable {
    let text: String
}

protocol AICoachServicing {
    func send(messages: [AIChatMessage], context: AICoachContextSnapshot) async throws -> AICoachReply
}

enum AICoachServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidResponse
    case emptyReply
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "AI coach is not configured yet. Add a backend proxy URL before enabling this feature."
        case .invalidResponse:
            return "The AI service returned an invalid response."
        case .emptyReply:
            return "The AI service returned an empty reply."
        case .server(let message):
            return message
        }
    }
}

struct RemoteAICoachService: AICoachServicing {
    let configuration: AICoachConfiguration
    let session: URLSession

    init(
        configuration: AICoachConfiguration = .current,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func send(messages: [AIChatMessage], context: AICoachContextSnapshot) async throws -> AICoachReply {
        guard let proxyURL = configuration.proxyURL else {
            throw AICoachServiceError.missingConfiguration
        }

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AICoachProxyRequest(
            model: configuration.model,
            messages: messages.map(AICoachProxyMessage.init),
            context: context
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AICoachServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverResponse = try? decoder.decode(AICoachProxyResponse.self, from: data)
            throw AICoachServiceError.server(
                serverResponse?.error?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        let proxyResponse = try decoder.decode(AICoachProxyResponse.self, from: data)

        if let reply = proxyResponse.reply?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reply.isEmpty {
            return AICoachReply(text: reply)
        }

        if let reply = proxyResponse.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reply.isEmpty {
            return AICoachReply(text: reply)
        }

        if let reply = proxyResponse.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
           !reply.isEmpty {
            return AICoachReply(text: reply)
        }

        throw AICoachServiceError.emptyReply
    }
}

private struct AICoachProxyRequest: Encodable {
    let model: String
    let messages: [AICoachProxyMessage]
    let context: AICoachContextSnapshot
}

private struct AICoachProxyMessage: Codable {
    let role: String
    let content: String

    init(message: AIChatMessage) {
        self.role = message.role.rawValue
        self.content = message.content
    }
}

private struct AICoachProxyResponse: Decodable {
    let reply: String?
    let outputText: String?
    let message: AICoachProxyMessageResponse?
    let error: AICoachProxyError?
}

private struct AICoachProxyMessageResponse: Decodable {
    let content: String
}

private struct AICoachProxyError: Decodable {
    let message: String
}
