import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PremiumProductID = .annual
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showRedeemSheet = false

    var body: some View {
        ZStack {
            Color(hex: "0D0F14")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.vertical, 32)
                        .padding(.horizontal, 20)

                    Divider()
                        .background(Color(hex: "242838"))

                    featuresSection
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)

                    plansSection
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)

                    ctaSection
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 20)

                    restoreButton
                        .padding(.bottom, 4)

                    redeemCodeButton
                        .padding(.bottom, 12)

                    legalFooter
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .offerCodeRedemption(isPresented: $showRedeemSheet) { result in
            if case .success = result {
                Task { await subscriptionManager.loadSubscriptionStatus() }
                dismiss()
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Train smarter.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Recover faster.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "00E5CC"))
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "bolt.fill", text: "Advanced performance analytics")
                featureRow(icon: "heart.fill", text: "Real-time recovery tracking")
                featureRow(icon: "brain.head.profile", text: "AI-powered insights & recommendations")
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Custom training plans")
                featureRow(icon: "calendar.badge.plus", text: "Unlimited historical data")
                featureRow(icon: "person.badge.shield.checkmark.fill", text: "Priority support")
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "00E5CC"))
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "D4D4D8"))

            Spacer()
        }
    }

    private var plansSection: some View {
        VStack(alignment: .center, spacing: 12) {
            planCard(productID: .monthly)
            planCard(productID: .annual)
            planCard(productID: .lifetime)
        }
    }

    private func planCard(productID: PremiumProductID) -> some View {
        let isSelected = selectedPlan == productID
        let isPopular = productID == .annual

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "242838"))
                .stroke(
                    isSelected ? Color(hex: "00E5CC") : Color(hex: "3B404F"),
                    lineWidth: isSelected ? 2 : 1
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName(for: productID))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        if let product = product(for: productID) {
                            Text(subscriptionManager.formattedPrice(for: product))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(hex: "00E5CC"))
                        } else {
                            shimmerPrice()
                        }
                    }

                    Spacer()

                    if isPopular {
                        Text("Most Popular")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "00E5CC"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "00E5CC").opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                if product(for: productID) != nil,
                   let periodText = periodDescription(for: productID) {
                    Text(periodText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "A1A1A6"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = productID
            }
        }
    }

    private func shimmerPrice() -> some View {
        Text("Loading...")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(Color(hex: "3B404F"))
            .redacted(reason: .placeholder)
    }

    private func productName(for productID: PremiumProductID) -> String {
        switch productID {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .lifetime:
            return "Lifetime"
        }
    }

    private func periodDescription(for productID: PremiumProductID) -> String? {
        switch productID {
        case .monthly:
            return "Renews monthly"
        case .annual:
            return "Best value • Renews yearly"
        case .lifetime:
            return "One-time purchase"
        }
    }

    private func product(for productID: PremiumProductID) -> Product? {
        switch productID {
        case .monthly:
            return subscriptionManager.monthlyProduct
        case .annual:
            return subscriptionManager.annualProduct
        case .lifetime:
            return subscriptionManager.lifetimeProduct
        }
    }

    private var ctaSection: some View {
        Button(action: purchaseSelectedPlan) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(Color(hex: "0D0F14"))
                } else {
                    Text(purchaseButtonTitle)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .font(.system(size: 16, weight: .semibold))
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "0D0F14"))
            .background(Color(hex: "00E5CC"))
            .cornerRadius(12)
        }
        .disabled(isPurchasing || product(for: selectedPlan) == nil)
    }

    private var restoreButton: some View {
        Button(action: restorePurchases) {
            Text("Restore Purchases")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "00E5CC"))
        }
    }

    private var redeemCodeButton: some View {
        Button(action: { showRedeemSheet = true }) {
            Text("Redeem Code")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "717179"))
        }
    }

    private var legalFooter: some View {
        Text("Cancel anytime. Subscription auto-renews unless cancelled 24h before period end.")
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(Color(hex: "717179"))
            .multilineTextAlignment(.center)
    }

    private var purchaseButtonTitle: String {
        switch selectedPlan {
        case .lifetime:
            return "Unlock Lifetime"
        case .monthly, .annual:
            return "Continue"
        }
    }

    private func purchaseSelectedPlan() {
        guard let selectedProduct = product(for: selectedPlan) else { return }

        isPurchasing = true

        Task {
            do {
                let success = try await subscriptionManager.purchase(selectedProduct)
                isPurchasing = false

                if success {
                    dismiss()
                }
            } catch {
                isPurchasing = false
                errorMessage = "Purchase failed. Please try again."
                showError = true
            }
        }
    }

    private func restorePurchases() {
        Task {
            let success = await subscriptionManager.restorePurchases()

            if success {
                dismiss()
            } else {
                errorMessage = "No purchases found to restore."
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaywallView()
            .environment(SubscriptionManager())
    }
}
