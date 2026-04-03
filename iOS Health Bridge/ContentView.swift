//
//  ContentView.swift
//  Forma
//
//  Acts as the onboarding / auth gate. Once the user has seen the intro and
//  authorised HealthKit, it hands off to MainTabView.
//

import SwiftUI

struct ContentView: View {
    @State private var healthManager = HealthDataManager()
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        Group {
            if !hasSeenIntro {
                IntroView(onContinue: { hasSeenIntro = true })
            } else if !healthManager.isAuthorized {
                AuthorizationView(
                    healthManager: healthManager,
                    onAuthorized: {
                        Task { await healthManager.checkAuthorizationStatus() }
                    }
                )
            } else {
                MainTabView(healthManager: healthManager)
            }
        }
        .task {
            await healthManager.checkAuthorizationStatus()
        }
    }
}

// MARK: - Intro View

struct IntroView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            FormaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {

                    // Hero
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(FormaColors.teal.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(FormaColors.teal)
                        }

                        Text("Forma")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(FormaColors.textPrimary)

                        Text("Your health data, finally making sense.")
                            .font(.title3)
                            .foregroundStyle(FormaColors.subtext)
                    }

                    // Feature highlights
                    VStack(spacing: 16) {
                        featureRow(
                            symbol: "chart.bar.fill",
                            color: FormaColors.teal,
                            title: "Deep Analytics",
                            detail: "Daily, weekly, monthly, and yearly breakdowns of every metric."
                        )
                        featureRow(
                            symbol: "sparkles",
                            color: FormaColors.orange,
                            title: "Smart Insights",
                            detail: "Spot trends and correlations across your training and recovery."
                        )
                        featureRow(
                            symbol: "trophy.fill",
                            color: Color(hex: "FF9F0A"),
                            title: "Personal Records",
                            detail: "Track your all-time bests and set goals for what's next."
                        )
                        featureRow(
                            symbol: "square.and.arrow.up.fill",
                            color: FormaColors.green,
                            title: "Premium Automatic Export",
                            detail: "Nightly export to your chosen folder, controlled from Settings."
                        )
                    }

                    Spacer(minLength: 40)

                    // CTA
                    Button(action: onContinue) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(FormaColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(FormaColors.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text("By continuing you agree to our Terms of Use and Privacy Policy.")
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
        }
    }

    private func featureRow(symbol: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FormaType.cardTitle())
                    .foregroundStyle(FormaColors.textPrimary)
                Text(detail)
                    .font(FormaType.caption())
                    .foregroundStyle(FormaColors.subtext)
            }
        }
    }
}

// MARK: - Authorisation View

struct AuthorizationView: View {
    @Bindable var healthManager  : HealthDataManager
    let onAuthorized             : () -> Void
    @State private var isRequesting  = false
    @State private var errorMessage  : String?

    var body: some View {
        ZStack {
            FormaColors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(FormaColors.teal)
                    Text("Connect Health")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaColors.textPrimary)
                    Text("Forma reads your Apple Health data to power analytics and insights. Your data never leaves your device.")
                        .font(.body)
                        .foregroundStyle(FormaColors.subtext)
                }

                if healthManager.authorizationStatus == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FormaColors.amber)
                        Text("Health access denied. Enable it in Settings → Health → Data Access.")
                            .font(.subheadline)
                            .foregroundStyle(FormaColors.amber)
                    }
                    .padding()
                    .background(FormaColors.amber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let error = errorMessage {
                    Text(error)
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.red)
                }

                Spacer()

                Button {
                    requestAuth()
                } label: {
                    Group {
                        if isRequesting {
                            ProgressView().tint(FormaColors.background)
                        } else {
                            Text("Authorise Health Access")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(FormaColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FormaColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRequesting || healthManager.authorizationStatus == .denied)
            }
            .padding(24)
        }
        .onChange(of: healthManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorized { onAuthorized() }
        }
    }

    private func requestAuth() {
        isRequesting  = true
        errorMessage  = nil
        Task {
            do {
                try await healthManager.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRequesting = false
        }
    }
}

#Preview {
    ContentView()
}
