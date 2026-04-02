//
//  HealthModels.swift
//  Forma
//
//  Shared types used across Analytics, Insights, Records, and Premium modules.
//

import SwiftUI
import HealthKit

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case day    = "Day"
    case week   = "Week"
    case month  = "Month"
    case year   = "Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .day:     return "1D"
        case .week:    return "1W"
        case .month:   return "1M"
        case .year:    return "1Y"
        case .allTime: return "All"
        }
    }

    func startDate(relativeTo end: Date = Date()) -> Date {
        let cal = Calendar.current
        switch self {
        case .day:     return cal.date(byAdding: .hour,       value: -24, to: end) ?? end
        case .week:    return cal.date(byAdding: .weekOfYear, value: -1,  to: end) ?? end
        case .month:   return cal.date(byAdding: .month,      value: -1,  to: end) ?? end
        case .year:    return cal.date(byAdding: .year,       value: -1,  to: end) ?? end
        case .allTime: return cal.date(byAdding: .year,       value: -10, to: end) ?? end
        }
    }

    /// The calendar component used to bucket data points for charting
    var bucketComponent: Calendar.Component {
        switch self {
        case .day:     return .hour
        case .week:    return .day
        case .month:   return .day
        case .year:    return .month
        case .allTime: return .month
        }
    }
}

// MARK: - Metric Type

enum HealthMetricType: String, CaseIterable, Codable, Identifiable {
    case steps            = "Steps"
    case distance         = "Distance"
    case activeEnergy     = "Active Energy"
    case heartRate        = "Heart Rate"
    case restingHeartRate = "Resting HR"
    case sleepDuration    = "Sleep"
    case workoutCount     = "Workouts"
    case bodyMass         = "Weight"
    case oxygenSaturation = "Blood Oxygen"
    case respiratoryRate  = "Resp. Rate"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .steps:            return "steps"
        case .distance:         return "km"
        case .activeEnergy:     return "kcal"
        case .heartRate,
             .restingHeartRate: return "bpm"
        case .sleepDuration:    return "hrs"
        case .workoutCount:     return "workouts"
        case .bodyMass:         return "kg"
        case .oxygenSaturation: return "%"
        case .respiratoryRate:  return "brpm"
        }
    }

    /// The correct HKUnit to pass to HealthKit queries for this metric type.
    var hkUnit: HKUnit {
        switch self {
        case .steps:            return .count()
        case .distance:         return .meter()
        case .activeEnergy:     return .kilocalorie()
        case .heartRate,
             .restingHeartRate,
             .respiratoryRate:  return HKUnit(from: "count/min")
        case .bodyMass:         return .gramUnit(with: .kilo)
        case .oxygenSaturation: return .percent()
        case .sleepDuration,
             .workoutCount:     return .count()  // handled by dedicated fetchers, not used
        }
    }

    var sfSymbol: String {
        switch self {
        case .steps:            return "figure.walk"
        case .distance:         return "map"
        case .activeEnergy:     return "flame.fill"
        case .heartRate:        return "heart.fill"
        case .restingHeartRate: return "heart"
        case .sleepDuration:    return "moon.fill"
        case .workoutCount:     return "dumbbell.fill"
        case .bodyMass:         return "scalemass.fill"
        case .oxygenSaturation: return "lungs.fill"
        case .respiratoryRate:  return "waveform"
        }
    }

    var accentColor: Color {
        switch self {
        case .steps:            return FormaColors.teal
        case .distance:         return Color(hex: "0A84FF")
        case .activeEnergy:     return FormaColors.orange
        case .heartRate:        return Color(hex: "FF453A")
        case .restingHeartRate: return Color(hex: "FF6B8A")
        case .sleepDuration:    return Color(hex: "7B7BFF")
        case .workoutCount:     return FormaColors.green
        case .bodyMass:         return Color(hex: "FF9F0A")
        case .oxygenSaturation: return Color(hex: "00C7BE")
        case .respiratoryRate:  return FormaColors.subtext
        }
    }

    /// Whether a higher value is generally considered better
    var higherIsBetter: Bool {
        switch self {
        case .steps, .distance, .activeEnergy,
             .sleepDuration, .workoutCount, .oxygenSaturation:
            return true
        case .heartRate, .restingHeartRate, .bodyMass, .respiratoryRate:
            return false
        }
    }

    var aggregationMethod: AggregationMethod {
        switch self {
        case .steps, .distance, .activeEnergy, .workoutCount:
            return .sum
        default:
            return .average
        }
    }

    enum AggregationMethod: Equatable {
        case sum, average
    }
}

// MARK: - Aggregated Data

struct AggregatedDataPoint: Identifiable, Equatable {
    let id    = UUID()
    let date  : Date
    let value : Double
}

struct MetricSummary: Identifiable {
    let id            = UUID()
    let metricType    : HealthMetricType
    let period        : TimePeriod
    let current       : Double?          // most recent sample / current-period total
    let average       : Double
    let minimum       : Double
    let maximum       : Double
    let total         : Double?          // populated for .sum metrics
    let dataPoints    : [AggregatedDataPoint]
    let percentChange : Double?          // vs prior equivalent period; positive = increase
    let trend         : TrendDirection

    enum TrendDirection { case up, down, flat, insufficient }

    /// The headline number shown on cards
    var displayValue: Double {
        switch metricType.aggregationMethod {
        case .sum:     return total   ?? current ?? 0
        case .average: return average
        }
    }

    /// Whether the current trend is positive given the metric's direction preference
    var isTrendPositive: Bool {
        switch trend {
        case .up:               return metricType.higherIsBetter
        case .down:             return !metricType.higherIsBetter
        case .flat, .insufficient: return true
        }
    }

    func formatted(_ value: Double) -> String {
        switch metricType {
        case .steps:
            return value >= 1000
                ? String(format: "%.1fk", value / 1000)
                : String(format: "%.0f", value)
        case .distance:
            return String(format: "%.2f", value)
        case .activeEnergy:
            return String(format: "%.0f", value)
        case .heartRate, .restingHeartRate, .respiratoryRate:
            return String(format: "%.0f", value)
        case .sleepDuration:
            return String(format: "%.1f", value)
        case .workoutCount:
            return String(format: "%.0f", value)
        case .bodyMass:
            return String(format: "%.1f", value)
        case .oxygenSaturation:
            return String(format: "%.0f", value * 100)
        }
    }

    var formattedDisplay: String { formatted(displayValue) }
}

// MARK: - Insights

struct HealthInsight: Identifiable {
    let id             = UUID()
    let title          : String
    let body           : String
    let severity       : Severity
    let category       : Category
    let relatedMetrics : [HealthMetricType]
    let generatedAt    : Date

    enum Severity {
        case positive, info, warning, negative

        var color: Color {
            switch self {
            case .positive: return FormaColors.green
            case .info:     return FormaColors.teal
            case .warning:  return Color(hex: "FF9F0A")
            case .negative: return Color(hex: "FF453A")
            }
        }

        var sfSymbol: String {
            switch self {
            case .positive: return "arrow.up.circle.fill"
            case .info:     return "info.circle.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .negative: return "arrow.down.circle.fill"
            }
        }
    }

    enum Category: String, CaseIterable {
        case activity    = "Activity"
        case recovery    = "Recovery"
        case trend       = "Trend"
        case streak      = "Streak"
        case correlation = "Correlation"
        case milestone   = "Milestone"
    }
}

// MARK: - Personal Records

struct PersonalRecord: Codable, Identifiable, Equatable {
    let id         : UUID
    let metricType : HealthMetricType
    let value      : Double
    let date       : Date

    init(metricType: HealthMetricType, value: Double, date: Date) {
        self.id         = UUID()
        self.metricType = metricType
        self.value      = value
        self.date       = date
    }

    var formattedValue: String {
        switch metricType {
        case .steps:
            return value >= 1000
                ? String(format: "%.1fk steps", value / 1000)
                : String(format: "%.0f steps", value)
        case .distance:         return String(format: "%.2f km", value)
        case .activeEnergy:     return String(format: "%.0f kcal", value)
        case .heartRate,
             .restingHeartRate,
             .respiratoryRate:  return String(format: "%.0f \(metricType.unit)", value)
        case .sleepDuration:    return String(format: "%.1f hrs", value)
        case .workoutCount:     return "\(Int(value)) workouts"
        case .bodyMass:         return String(format: "%.1f kg", value)
        case .oxygenSaturation: return String(format: "%.0f%%", value * 100)
        }
    }
}

// MARK: - Goal

struct HealthGoal: Codable, Identifiable {
    let id         : UUID
    let metricType : HealthMetricType
    var target     : Double
    var period     : GoalPeriod
    var isActive   : Bool

    init(metricType: HealthMetricType, target: Double, period: GoalPeriod) {
        self.id         = UUID()
        self.metricType = metricType
        self.target     = target
        self.period     = period
        self.isActive   = true
    }

    enum GoalPeriod: String, Codable, CaseIterable {
        case daily   = "Daily"
        case weekly  = "Weekly"
        case monthly = "Monthly"
    }
}

// MARK: - Subscription

enum SubscriptionTier: Equatable {
    case free
    case premium
}

enum PremiumProductID: String, CaseIterable {
    case monthly  = "com.polyphasicdevs.forma.premium.monthly"
    case annual   = "com.polyphasicdevs.forma.premium.annual"
    case lifetime = "com.polyphasicdevs.forma.premium.lifetime"
}
