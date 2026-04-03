import Foundation
import HealthKit
import Observation
import OSLog

@MainActor
@Observable
final class AICoachSession {
    private let contextBuilder: AICoachContextBuilder
    private let service: AICoachServicing
    private let configuration: AICoachConfiguration

    var messages: [AIChatMessage] = []
    var contextSnapshot: AICoachContextSnapshot?
    var isLoading = false
    var errorMessage: String?

    init(
        healthStore: HKHealthStore,
        service: AICoachServicing? = nil,
        configuration: AICoachConfiguration = .current
    ) {
        self.contextBuilder = AICoachContextBuilder(healthStore: healthStore)
        self.configuration = configuration
        self.service = service ?? RemoteAICoachService(configuration: configuration)
    }

    var suggestions: [AICoachPromptSuggestion] {
        AICoachPromptSuggestion.defaults
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    func refreshContext(measurementSystem: MeasurementSystem) async {
        errorMessage = nil
        contextSnapshot = await contextBuilder.build(measurementSystem: measurementSystem)
    }

    func resetConversation() {
        messages = []
        errorMessage = nil
    }

    func send(_ text: String, measurementSystem: MeasurementSystem) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if contextSnapshot == nil {
            await refreshContext(measurementSystem: measurementSystem)
        }

        guard let contextSnapshot else {
            errorMessage = "Unable to prepare your health context."
            return
        }

        errorMessage = nil
        messages.append(AIChatMessage(role: .user, content: trimmed))
        isLoading = true

        do {
            let reply = try await service.send(
                messages: Array(messages.suffix(10)),
                context: contextSnapshot
            )
            messages.append(AIChatMessage(role: .assistant, content: reply.text))
        } catch {
            AppLogger.ai.error("AI coach request failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
