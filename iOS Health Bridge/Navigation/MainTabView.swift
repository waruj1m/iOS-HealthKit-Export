//
//  MainTabView.swift
//  Forma
//
//  Root tab bar shown after the user has completed onboarding and authorised
//  HealthKit access. Premium tabs show a paywall overlay when the user is on
//  the free tier.
//

import SwiftUI

struct MainTabView: View {
    @State var healthManager: HealthDataManager
    @State private var selectedTab: Tab = .dashboard
    @State private var showPaywall = false
    @Environment(SubscriptionManager.self) private var subscriptionManager

    enum Tab: Int, CaseIterable {
        case dashboard = 0
        case insights
        case records
        case export
        case settings

        var label: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .insights:  return "Insights"
            case .records:   return "Records"
            case .export:    return "Export"
            case .settings:  return "Settings"
            }
        }

        var sfSymbol: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .insights:  return "sparkles"
            case .records:   return "trophy.fill"
            case .export:    return "square.and.arrow.up.fill"
            case .settings:  return "gearshape.fill"
            }
        }

        var isPremium: Bool {
            switch self {
            case .dashboard, .insights, .records: return true
            case .export, .settings:              return false
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.sfSymbol)
                    }
                    .tag(tab)
            }
        }
        .tint(FormaColors.teal)
        // Apply dark tab bar styling
        .onAppear { styleTabBar() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(subscriptionManager)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        let isPremium = tab.isPremium
        let isLocked  = isPremium && subscriptionManager.tier == .free

        Group {
            switch tab {
            case .dashboard:
                AnalyticsView(healthManager: healthManager)
                    .premiumGated(isLocked: isLocked, onUnlock: { showPaywall = true })
            case .insights:
                InsightsView(healthManager: healthManager)
                    .premiumGated(isLocked: isLocked, onUnlock: { showPaywall = true })
            case .records:
                PersonalRecordsView(healthManager: healthManager)
                    .premiumGated(isLocked: isLocked, onUnlock: { showPaywall = true })
            case .export:
                ExportView(healthManager: healthManager)
            case .settings:
                SettingsView()
                    .environment(subscriptionManager)
            }
        }
    }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(FormaColors.surface)
        UITabBar.appearance().standardAppearance  = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Premium Gate Modifier

private struct PremiumGatedModifier: ViewModifier {
    let isLocked : Bool
    let onUnlock : () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: isLocked ? 8 : 0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                PremiumLockOverlay(onUnlock: onUnlock)
            }
        }
    }
}

extension View {
    func premiumGated(isLocked: Bool, onUnlock: @escaping () -> Void) -> some View {
        modifier(PremiumGatedModifier(isLocked: isLocked, onUnlock: onUnlock))
    }
}
