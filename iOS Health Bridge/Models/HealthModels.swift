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
        case .day:     return cal.startOfDay(for: end)
        case .week:    return cal.date(byAdding: .weekOfYear, value: -1,  to: cal.startOfDay(for: end)) ?? end
        case .month:   return cal.date(byAdding: .month,      value: -1,  to: cal.startOfDay(for: end)) ?? end
        case .year:    return cal.date(byAdding: .year,       value: -1,  to: cal.startOfDay(for: end)) ?? end
        case .allTime: return cal.date(byAdding: .year,       value: -10, to: cal.startOfDay(for: end)) ?? end
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

    func shiftedEndDate(
        relativeTo end: Date,
        by periods: Int,
        calendar: Calendar = .current
    ) -> Date {
        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: periods, to: end) ?? end
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: periods, to: end) ?? end
        case .month:
            return calendar.date(byAdding: .month, value: periods, to: end) ?? end
        case .year:
            return calendar.date(byAdding: .year, value: periods, to: end) ?? end
        case .allTime:
            return calendar.date(byAdding: .year, value: periods, to: end) ?? end
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
        displayUnit(for: .metric)
    }

    func displayUnit(for measurementSystem: MeasurementSystem) -> String {
        switch self {
        case .steps:            return "steps"
        case .distance:         return measurementSystem == .imperial ? "mi" : "km"
        case .activeEnergy:     return "kcal"
        case .heartRate,
             .restingHeartRate: return "bpm"
        case .sleepDuration:    return "hrs"
        case .workoutCount:     return "workouts"
        case .bodyMass:         return measurementSystem == .imperial ? "lb" : "kg"
        case .oxygenSaturation: return "%"
        case .respiratoryRate:  return "brpm"
        }
    }

    func convertedValue(_ value: Double, for measurementSystem: MeasurementSystem) -> Double {
        switch self {
        case .distance:
            return measurementSystem == .imperial ? value * 0.621_371 : value
        case .bodyMass:
            return measurementSystem == .imperial ? value * 2.204_62 : value
        default:
            return value
        }
    }

    func formattedGoalValue(
        _ value: Double,
        measurementSystem: MeasurementSystem = .metric
    ) -> String {
        let displayValue = convertedValue(value, for: measurementSystem)

        switch self {
        case .steps, .activeEnergy, .heartRate, .restingHeartRate, .respiratoryRate:
            return String(format: "%.0f", displayValue)
        case .distance:
            return String(format: "%.1f", displayValue)
        case .sleepDuration, .bodyMass:
            return String(format: "%.1f", displayValue)
        case .workoutCount:
            return "\(Int(displayValue.rounded()))"
        case .oxygenSaturation:
            return String(format: "%.0f", displayValue)
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

    func formatted(_ value: Double, measurementSystem: MeasurementSystem = .metric) -> String {
        let displayValue = metricType.convertedValue(value, for: measurementSystem)

        switch metricType {
        case .steps:
            return displayValue >= 1000
                ? String(format: "%.1fk", displayValue / 1000)
                : String(format: "%.0f", displayValue)
        case .distance:
            return String(format: "%.2f", displayValue)
        case .activeEnergy:
            return String(format: "%.0f", displayValue)
        case .heartRate, .restingHeartRate, .respiratoryRate:
            return String(format: "%.0f", displayValue)
        case .sleepDuration:
            return String(format: "%.1f", displayValue)
        case .workoutCount:
            return String(format: "%.0f", displayValue)
        case .bodyMass:
            return String(format: "%.1f", displayValue)
        case .oxygenSaturation:
            return String(format: "%.0f", displayValue * 100)
        }
    }

    func formattedDisplay(measurementSystem: MeasurementSystem = .metric) -> String {
        formatted(displayValue, measurementSystem: measurementSystem)
    }
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

    func formattedValue(measurementSystem: MeasurementSystem = .metric) -> String {
        let displayValue = metricType.convertedValue(value, for: measurementSystem)
        let displayUnit = metricType.displayUnit(for: measurementSystem)

        switch metricType {
        case .steps:
            return displayValue >= 1000
                ? String(format: "%.1fk steps", displayValue / 1000)
                : String(format: "%.0f steps", displayValue)
        case .distance:         return String(format: "%.2f %@", displayValue, displayUnit)
        case .activeEnergy:     return String(format: "%.0f kcal", displayValue)
        case .heartRate,
             .restingHeartRate,
             .respiratoryRate:  return String(format: "%.0f %@", displayValue, displayUnit)
        case .sleepDuration:    return String(format: "%.1f hrs", displayValue)
        case .workoutCount:     return "\(Int(displayValue)) workouts"
        case .bodyMass:         return String(format: "%.1f %@", displayValue, displayUnit)
        case .oxygenSaturation: return String(format: "%.0f%%", displayValue * 100)
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

        var label: String {
            switch self {
            case .daily:
                return "Today"
            case .weekly:
                return "This Week"
            case .monthly:
                return "This Month"
            }
        }

        func interval(
            containing referenceDate: Date = Date(),
            calendar: Calendar = .current
        ) -> DateInterval {
            switch self {
            case .daily:
                let start = calendar.startOfDay(for: referenceDate)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? referenceDate
                return DateInterval(start: start, end: end)
            case .weekly:
                if let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) {
                    return interval
                }
            case .monthly:
                if let interval = calendar.dateInterval(of: .month, for: referenceDate) {
                    return interval
                }
            }

            return DateInterval(start: referenceDate, end: referenceDate)
        }
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
