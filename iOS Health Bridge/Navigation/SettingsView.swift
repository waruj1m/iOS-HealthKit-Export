//
//  SettingsView.swift
//  Forma
//

import SwiftUI

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                List {
                    // Subscription status
                    Section {
                        subscriptionRow
                    }
                    .listRowBackground(FormaColors.card)

                    // App info
                    Section {
                        infoRow(label: "Version",    value: appVersion)
                        infoRow(label: "Build",      value: buildNumber)
                    }
                    .listRowBackground(FormaColors.card)

                    // Support
                    Section {
                        linkRow(label: "Privacy Policy",   url: "https://polyphasicdevs.com/forma-privacy-policy/")
                        linkRow(label: "Terms of Use",     url: "https://polyphasicdevs.com/forma-tos/")
                        linkRow(label: "Send Feedback",    url: "mailto:support@polyphasicdevs.com")
                    }
                    .listRowBackground(FormaColors.card)

                    // IAP management
                    Section {
                        Button {
                            restorePurchases()
                        } label: {
                            Text("Restore Purchases")
                                .foregroundStyle(FormaColors.teal)
                        }
                    }
                    .listRowBackground(FormaColors.card)

                    // AI disclaimer
                    Section(footer: footerContent) { }
                        .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(subscriptionManager)
            }
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(restoreMessage)
            }
        }
    }

    // MARK: Sub-views

    private var subscriptionRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FormaColors.teal.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: subscriptionManager.tier == .premium
                      ? "crown.fill" : "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(subscriptionManager.tier == .premium
                                     ? FormaColors.teal : FormaColors.subtext)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subscriptionManager.tier == .premium ? "Forma Premium" : "Free Plan")
                    .font(FormaType.cardTitle())
                    .foregroundStyle(FormaColors.textPrimary)
                Text(subscriptionManager.tier == .premium
                     ? "Full analytics & insights unlocked"
                     : "Upgrade to unlock all features")
                    .font(FormaType.caption())
                    .foregroundStyle(FormaColors.subtext)
            }

            Spacer()

            if subscriptionManager.tier == .free {
                Button { showPaywall = true } label: {
                    Text("Upgrade")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FormaColors.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FormaColors.teal)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(FormaColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(FormaColors.subtext)
        }
    }

    private func linkRow(label: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(label)
                    .foregroundStyle(FormaColors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(FormaColors.subtext)
            }
        }
    }

    private var footerContent: some View {
        VStack(spacing: 12) {
            Text("AI-generated insights are for informational purposes only and do not constitute medical advice. Always consult a qualified healthcare professional before making health or fitness decisions.")
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.muted)
                .multilineTextAlignment(.center)

            Link("Built by Polyphasic Developers", destination: URL(string: "https://polyphasicdevs.com")!)
                .font(FormaType.caption())
                .foregroundStyle(FormaColors.teal)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: Actions

    private func restorePurchases() {
        Task {
            let restored = await subscriptionManager.restorePurchases()
            restoreMessage = restored
                ? "Your purchases have been restored."
                : "No purchases found to restore."
            showRestoreAlert = true
        }
    }

    // MARK: Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
