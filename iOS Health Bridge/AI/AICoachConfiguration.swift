import Foundation

struct AICoachConfiguration: Equatable {
    static let proxyURLKey = "FORMA_AI_PROXY_URL"
    static let modelKey = "FORMA_AI_MODEL"

    let proxyURL: URL?
    let model: String

    var isConfigured: Bool {
        proxyURL != nil
    }

    nonisolated static var current: AICoachConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        let proxyURLString = info[proxyURLKey] as? String
        let model = (info[modelKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (info[modelKey] as? String ?? "gpt-5.4")
            : "gpt-5.4"

        return AICoachConfiguration(
            proxyURL: proxyURLString.flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : URL(string: trimmed)
            },
            model: model
        )
    }
}
