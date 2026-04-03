import SwiftUI

struct AICoachView: View {
    let healthManager: HealthDataManager

    @Environment(MeasurementSettings.self) private var measurementSettings
    @State private var session: AICoachSession
    @State private var draft = ""

    init(healthManager: HealthDataManager) {
        self.healthManager = healthManager
        _session = State(initialValue: AICoachSession(healthStore: healthManager.healthStore))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if let errorMessage = session.errorMessage {
                        errorBanner(message: errorMessage)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if session.messages.isEmpty {
                        starterState
                    } else {
                        messageList
                    }

                    composer
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(FormaColors.surface)
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", action: session.resetConversation)
                        .foregroundStyle(FormaColors.teal)
                        .disabled(session.messages.isEmpty && session.isLoading == false)
                }
            }
            .task {
                await session.refreshContext(measurementSystem: measurementSettings.measurementSystem)
            }
            .onChange(of: measurementSettings.measurementSystem) { _, newValue in
                Task { await session.refreshContext(measurementSystem: newValue) }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [FormaColors.teal.opacity(0.24), Color(hex: "155E75").opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "bubble.left.and.sparkles.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tailored training and recovery guidance")
                        .font(.headline)
                        .foregroundStyle(FormaColors.textPrimary)
                    Text(session.isConfigured
                         ? "Replies are grounded in your recent metrics and generated insights."
                         : "Add your AI proxy URL in Info.plist before enabling live responses.")
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.subtext)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                MetricBadge(
                    text: "Premium",
                    color: FormaColors.teal
                )
                MetricBadge(
                    text: measurementSettings.measurementSystem.displayName,
                    color: FormaColors.orange
                )
                if let generatedAt = session.contextSnapshot?.generatedAt {
                    Text("Updated \(generatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.subtext)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [FormaColors.card, Color(hex: "16202E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var starterState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FormaCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What this coach can do")
                            .font(.headline)
                            .foregroundStyle(FormaColors.textPrimary)

                        starterBullet("Summarize your recent recovery and training load.")
                        starterBullet("Spot changes in sleep, effort, and cardiovascular metrics.")
                        starterBullet("Suggest practical next steps without giving medical advice.")
                    }
                }

                if !session.isConfigured {
                    FormaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Setup required")
                                .font(.headline)
                                .foregroundStyle(FormaColors.textPrimary)
                            Text("Set `FORMA_AI_PROXY_URL` in [Info.plist](/Users/james/Dev/iOS Health Bridge/iOS Health Bridge/Info.plist) and point it at your backend proxy. The iOS app should never hold the OpenAI secret directly.")
                                .font(FormaType.caption())
                                .foregroundStyle(FormaColors.subtext)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FormaSectionHeader(title: "Suggested Prompts")

                    ForEach(session.suggestions) { suggestion in
                        Button {
                            draft = suggestion.prompt
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
                                        .font(FormaType.cardTitle())
                                        .foregroundStyle(FormaColors.textPrimary)
                                    Text(suggestion.prompt)
                                        .font(FormaType.caption())
                                        .foregroundStyle(FormaColors.subtext)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .foregroundStyle(FormaColors.teal)
                            }
                            .padding(16)
                            .background(FormaColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if session.isLoading {
                        typingBubble
                            .id("typing")
                    }
                }
                .padding(16)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let lastID = session.messages.last?.id {
                    withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: session.isLoading) { _, isLoading in
                guard isLoading else { return }
                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                bubbleBody(message.content, isAssistant: true)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubbleBody(message.content, isAssistant: false)
            }
        }
    }

    private func bubbleBody(_ content: String, isAssistant: Bool) -> some View {
        Text(content)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(isAssistant ? FormaColors.textPrimary : FormaColors.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(backgroundStyle(isAssistant: isAssistant))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var typingBubble: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(FormaColors.subtext.opacity(0.75))
                        .frame(width: 7, height: 7)
                        .opacity(session.isLoading ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.12),
                            value: session.isLoading
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FormaColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 40)
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            Text("For informational purposes only. This coach does not provide medical advice.")
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about recovery, sleep, training, or trends…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(FormaColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(FormaColors.textPrimary)

                Button {
                    let prompt = draft
                    draft = ""
                    Task { await session.send(prompt, measurementSystem: measurementSettings.measurementSystem) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(canSend ? FormaColors.teal : FormaColors.subtext)
                }
                .disabled(!canSend)
            }
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isLoading
    }

    private func starterBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FormaColors.teal)
            Text(text)
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.subtext)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FormaColors.background)
            Text(message)
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.background)
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "FF9F0A"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func backgroundStyle(isAssistant: Bool) -> some View {
        if isAssistant {
            FormaColors.card
        } else {
            LinearGradient(
                colors: [FormaColors.teal, Color(hex: "1CB5A3")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

#Preview {
    AICoachView(healthManager: HealthDataManager())
        .environment(MeasurementSettings())
}
