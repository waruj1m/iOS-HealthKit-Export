//
//  DesignSystem.swift
//  Forma
//
//  Dark athletic design language: colors, typography helpers, and reusable
//  SwiftUI components shared across the entire app.
//

import SwiftUI

// MARK: - Color Palette

enum FormaColors {
    // Backgrounds
    static let background  = Color(hex: "0D0F14")   // near-black
    static let surface     = Color(hex: "1A1D26")   // dark card bg
    static let card        = Color(hex: "242838")   // slightly lighter card
    static let divider     = Color(hex: "2E3347")

    // Accents
    static let teal        = Color(hex: "00E5CC")   // primary accent
    static let orange      = Color(hex: "FF6B35")   // secondary / energy
    static let green       = Color(hex: "34C759")
    static let red         = Color(hex: "FF453A")
    static let amber       = Color(hex: "FF9F0A")
    static let purple      = Color(hex: "7B7BFF")

    // Text
    static let textPrimary = Color.white
    static let subtext     = Color(hex: "8E9BB4")
    static let muted       = Color(hex: "4A5568")
}

// MARK: - Hex Color Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

enum FormaType {
    /// Large hero number on metric cards
    static func heroNumber() -> Font { .system(size: 42, weight: .bold, design: .rounded) }
    /// Section headers
    static func sectionHeader() -> Font { .system(size: 13, weight: .semibold).uppercaseSmallCaps() }
    /// Card title
    static func cardTitle() -> Font { .system(size: 15, weight: .semibold) }
    /// Caption / label
    static func caption() -> Font { .system(size: 12, weight: .regular) }
    /// Badge / pill text
    static func badge() -> Font { .system(size: 11, weight: .bold) }
}

// MARK: - Forma Card

struct FormaCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(FormaColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let text  : String
    let color : Color

    var body: some View {
        Text(text)
            .font(FormaType.badge())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Period Picker

struct PeriodPicker: View {
    @Binding var selected: TimePeriod

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases) { period in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = period
                    }
                } label: {
                    Text(period.shortLabel)
                        .font(FormaType.badge())
                        .foregroundStyle(selected == period ? FormaColors.background : FormaColors.subtext)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selected == period
                                ? FormaColors.teal
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(FormaColors.surface)
        .clipShape(Capsule())
    }
}

// MARK: - Trend Arrow

struct TrendArrow: View {
    let direction  : MetricSummary.TrendDirection
    let isPositive : Bool
    let percent    : Double?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: arrowSymbol)
                .font(.system(size: 11, weight: .bold))
            if let pct = percent {
                Text(String(format: "%.0f%%", abs(pct)))
                    .font(FormaType.caption())
            }
        }
        .foregroundStyle(arrowColor)
    }

    private var arrowSymbol: String {
        switch direction {
        case .up:               return "arrow.up.right"
        case .down:             return "arrow.down.right"
        case .flat, .insufficient: return "minus"
        }
    }

    private var arrowColor: Color {
        switch direction {
        case .up:               return isPositive ? FormaColors.green : FormaColors.red
        case .down:             return isPositive ? FormaColors.red   : FormaColors.green
        case .flat, .insufficient: return FormaColors.subtext
        }
    }
}

// MARK: - Premium Lock Overlay

struct PremiumLockOverlay: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(FormaColors.teal)

                VStack(spacing: 6) {
                    Text("Forma Premium")
                        .font(.headline.bold())
                        .foregroundStyle(FormaColors.textPrimary)
                    Text("Unlock deep analytics, trends\nand personal records")
                        .font(.subheadline)
                        .foregroundStyle(FormaColors.subtext)
                        .multilineTextAlignment(.center)
                }

                Button(action: onUnlock) {
                    Text("Unlock Premium")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FormaColors.background)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(FormaColors.teal)
                        .clipShape(Capsule())
                }
            }
            .padding(32)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section Header

struct FormaSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FormaType.sectionHeader())
            .foregroundStyle(FormaColors.subtext)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Loading Shimmer

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [FormaColors.surface, FormaColors.card, FormaColors.surface],
                    startPoint: UnitPoint(x: phase - 0.5, y: 0),
                    endPoint:   UnitPoint(x: phase + 0.5, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - View Modifiers

extension View {
    func formaBackground() -> some View {
        self.background(FormaColors.background.ignoresSafeArea())
    }
}
