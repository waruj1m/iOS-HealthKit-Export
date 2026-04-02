import Foundation

/// Pure logic engine for analyzing health metrics and generating insights.
/// This is a stateless utility class that processes metric summaries
/// and produces actionable insights for display.
final class TrendEngine {

    // MARK: - Public API

    /// Analyzes metric summaries over a given period and generates insights.
    /// Results are deduplicated, sorted by severity (positive first), and limited to meaningful insights.
    func generateInsights(from summaries: [MetricSummary], period: TimePeriod) -> [HealthInsight] {
        var allInsights: [HealthInsight] = []

        // Run all analysis functions
        if let stepSummary = summaries.first(where: { $0.metricType == .steps }) {
            allInsights.append(contentsOf: analyseStepStreak(stepSummary))
        }

        if let sleepSummary = summaries.first(where: { $0.metricType == .sleepDuration }) {
            allInsights.append(contentsOf: analyseSleepTrend(sleepSummary))
        }

        if let restingHRSummary = summaries.first(where: { $0.metricType == .restingHeartRate }) {
            allInsights.append(contentsOf: analyseRestingHR(restingHRSummary))
        }

        allInsights.append(contentsOf: analyseTrainingLoad(summaries))
        allInsights.append(contentsOf: analyseConsistency(summaries))

        if let bodyMassSummary = summaries.first(where: { $0.metricType == .bodyMass }) {
            allInsights.append(contentsOf: analyseWeightTrend(bodyMassSummary))
        }

        allInsights.append(contentsOf: analyseMilestones(summaries))

        // Deduplicate by title (simple approach: keep first occurrence)
        var seenTitles = Set<String>()
        let deduplicated = allInsights.filter { insight in
            guard !seenTitles.contains(insight.title) else { return false }
            seenTitles.insert(insight.title)
            return true
        }

        // Sort: positive → info → warning → negative
        let sorted = deduplicated.sorted { lhs, rhs in
            let severityOrder: [HealthInsight.Severity] = [.positive, .info, .warning, .negative]
            let lhsIndex = severityOrder.firstIndex(of: lhs.severity) ?? 4
            let rhsIndex = severityOrder.firstIndex(of: rhs.severity) ?? 4
            return lhsIndex < rhsIndex
        }

        return sorted
    }

    // MARK: - Analysis Functions

    /// Detects activity streaks (consecutive days with steps > 5000).
    private func analyseStepStreak(_ summary: MetricSummary) -> [HealthInsight] {
        let dataPoints = summary.dataPoints.sorted { $0.date < $1.date }
        guard !dataPoints.isEmpty else { return [] }

        // Find consecutive days > 5000 steps
        var currentStreak = 0
        var longestStreak = 0
        var streakEndedRecently = false

        for (index, point) in dataPoints.enumerated() {
            if point.value > 5000 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                if index == dataPoints.count - 1 && currentStreak > 0 {
                    streakEndedRecently = true
                }
                currentStreak = 0
            }
        }

        var insights: [HealthInsight] = []

        // Check if active streak (last day was > 5000)
        let lastDayValue = dataPoints.last?.value ?? 0
        if longestStreak >= 3 && lastDayValue > 5000 {
            insights.append(HealthInsight(
                title: "\(longestStreak)-day activity streak 🔥",
                body: "You've maintained excellent daily activity for \(longestStreak) consecutive days. Keep it up!",
                severity: .positive,
                category: .streak,
                relatedMetrics: [.steps],
                generatedAt: Date()
            ))
        }

        // Check for streak at risk
        if longestStreak >= 3 && lastDayValue <= 5000 && streakEndedRecently {
            insights.append(HealthInsight(
                title: "Streak at risk",
                body: "Your activity streak has ended. Get moving today to start a new one!",
                severity: .warning,
                category: .streak,
                relatedMetrics: [.steps],
                generatedAt: Date()
            ))
        }

        return insights
    }

    /// Analyzes sleep duration trends and consistency.
    private func analyseSleepTrend(_ summary: MetricSummary) -> [HealthInsight] {
        let dataPoints = summary.dataPoints.sorted { $0.date < $1.date }
        guard !dataPoints.isEmpty else { return [] }

        var insights: [HealthInsight] = []

        // Check for chronic sleep debt (last 3 days < 6 hours)
        let lastThree = dataPoints.suffix(3)
        if lastThree.count == 3 && lastThree.allSatisfy({ $0.value < 6.0 }) {
            insights.append(HealthInsight(
                title: "Chronic sleep debt detected",
                body: "Your sleep has been consistently below 6 hours. Prioritize recovery to maintain athletic performance.",
                severity: .warning,
                category: .trend,
                relatedMetrics: [.sleepDuration],
                generatedAt: Date()
            ))
        }

        // Check for excellent sleep consistency
        if summary.average > 7.5 {
            insights.append(HealthInsight(
                title: "Excellent sleep consistency",
                body: "You're averaging \(String(format: "%.1f", summary.average)) hours nightly. This supports recovery and performance.",
                severity: .positive,
                category: .trend,
                relatedMetrics: [.sleepDuration],
                generatedAt: Date()
            ))
        }

        return insights
    }

    /// Analyzes resting heart rate trends via linear regression.
    private func analyseRestingHR(_ summary: MetricSummary) -> [HealthInsight] {
        let dataPoints = summary.dataPoints.sorted { $0.date < $1.date }
        guard dataPoints.count >= 3 else { return [] }

        // Prepare data for regression (x = days since first, y = HR)
        let firstDate = dataPoints.first!.date
        var regressionPoints: [(x: Double, y: Double)] = []

        for point in dataPoints {
            let daysSinceStart = point.date.timeIntervalSince(firstDate) / 86400
            regressionPoints.append((x: daysSinceStart, y: point.value))
        }

        let (slope, _) = linearRegression(regressionPoints)
        var insights: [HealthInsight] = []

        // Interpret slope
        if slope > 0.5 {
            insights.append(HealthInsight(
                title: "Resting HR trending up",
                body: "Your resting heart rate is rising (\(String(format: "+%.2f", slope)) bpm/day). Monitor recovery and reduce training intensity if needed.",
                severity: .warning,
                category: .trend,
                relatedMetrics: [.restingHeartRate],
                generatedAt: Date()
            ))
        } else if slope < -0.5 {
            insights.append(HealthInsight(
                title: "Resting HR improving",
                body: "Your resting heart rate is decreasing (\(String(format: "%.2f", slope)) bpm/day). Great sign of improved fitness and recovery!",
                severity: .positive,
                category: .trend,
                relatedMetrics: [.restingHeartRate],
                generatedAt: Date()
            ))
        }

        return insights
    }

    /// Analyzes training load vs recovery balance.
    private func analyseTrainingLoad(_ summaries: [MetricSummary]) -> [HealthInsight] {
        let activeEnergySummary = summaries.first(where: { $0.metricType == .activeEnergy })
        let restingHRSummary = summaries.first(where: { $0.metricType == .restingHeartRate })
        let workoutSummary = summaries.first(where: { $0.metricType == .workoutCount })
        let sleepSummary = summaries.first(where: { $0.metricType == .sleepDuration })

        var insights: [HealthInsight] = []

        // Check for accumulated fatigue
        if let activeEnergy = activeEnergySummary, let restingHR = restingHRSummary {
            let energyRange = activeEnergy.maximum - activeEnergy.minimum
            let threshold75 = activeEnergy.minimum + (energyRange * 0.75)

            let recentEnergy = activeEnergy.dataPoints.last?.value ?? 0
            let recentHR = restingHR.dataPoints.last?.value ?? 0

            if recentEnergy > threshold75 && recentHR > restingHR.average {
                insights.append(HealthInsight(
                    title: "High training load detected",
                    body: "You're training hard but resting heart rate is elevated. Prioritize sleep and recovery.",
                    severity: .warning,
                    category: .correlation,
                    relatedMetrics: [.activeEnergy, .restingHeartRate, .sleepDuration],
                    generatedAt: Date()
                ))
            }
        }

        // Check for strong training + recovery
        if let workouts = workoutSummary, let sleep = sleepSummary {
            let recentWorkouts = workouts.dataPoints.suffix(7)
            let previousWeekWorkouts = workouts.dataPoints.dropLast(7).suffix(7)

            let recentCount = recentWorkouts.map { $0.value }.reduce(0, +)
            let previousCount = previousWeekWorkouts.map { $0.value }.reduce(0, +)

            if recentCount > previousCount && sleep.average >= 7.0 {
                insights.append(HealthInsight(
                    title: "Training and recovery in sync",
                    body: "Great work! You're increasing training volume while maintaining solid sleep. Perfect balance.",
                    severity: .positive,
                    category: .correlation,
                    relatedMetrics: [.workoutCount, .sleepDuration],
                    generatedAt: Date()
                ))
            }
        }

        return insights
    }

    /// Analyzes consistency of activity levels via coefficient of variation.
    private func analyseConsistency(_ summaries: [MetricSummary]) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        for metricType in [HealthMetricType.steps, .activeEnergy] {
            guard let summary = summaries.first(where: { $0.metricType == metricType }) else { continue }

            let values = summary.dataPoints.map { $0.value }
            guard values.count >= 3 else { continue }

            let cv = coefficientOfVariation(values)

            if cv < 0.20 {
                insights.append(HealthInsight(
                    title: "Very consistent \(metricType.rawValue)",
                    body: "Your \(metricType.rawValue) pattern is steady and predictable. Excellent routine!",
                    severity: .positive,
                    category: .trend,
                    relatedMetrics: [metricType],
                    generatedAt: Date()
                ))
            } else if cv > 0.50 {
                insights.append(HealthInsight(
                    title: "High variation in \(metricType.rawValue)",
                    body: "Your daily \(metricType.rawValue) fluctuates significantly. Consider building a more consistent routine.",
                    severity: .info,
                    category: .trend,
                    relatedMetrics: [metricType],
                    generatedAt: Date()
                ))
            }
        }

        return insights
    }

    /// Analyzes weight/body mass trends via linear regression.
    private func analyseWeightTrend(_ summary: MetricSummary) -> [HealthInsight] {
        let dataPoints = summary.dataPoints.sorted { $0.date < $1.date }
        guard dataPoints.count >= 5 else { return [] }

        let firstDate = dataPoints.first!.date
        var regressionPoints: [(x: Double, y: Double)] = []

        for point in dataPoints {
            let daysSinceStart = point.date.timeIntervalSince(firstDate) / 86400
            regressionPoints.append((x: daysSinceStart, y: point.value))
        }

        let (slope, _) = linearRegression(regressionPoints)
        var insights: [HealthInsight] = []

        if slope != 0 {
            let direction = slope > 0 ? "gaining" : "losing"
            let ratePerWeek = abs(slope) * 7
            insights.append(HealthInsight(
                title: "Body mass trending \(direction)",
                body: "You're \(direction) approximately \(String(format: "%.1f", ratePerWeek)) kg per week.",
                severity: .info,
                category: .trend,
                relatedMetrics: [.bodyMass],
                generatedAt: Date()
            ))
        }

        return insights
    }

    /// Detects milestones (personal bests in current period).
    private func analyseMilestones(_ summaries: [MetricSummary]) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        if let stepSummary = summaries.first(where: { $0.metricType == .steps }) {
            let dataPoints = stepSummary.dataPoints.sorted { $0.date < $1.date }
            let totalSteps = dataPoints.map { $0.value }.reduce(0, +)
            // Check if close to personal best (within 5%)
            if totalSteps > (stepSummary.maximum * Double(dataPoints.count) * 0.95) {
                insights.append(HealthInsight(
                    title: "Personal best steps this period 🏆",
                    body: "You've achieved an outstanding step total! Keep crushing it.",
                    severity: .positive,
                    category: .milestone,
                    relatedMetrics: [.steps],
                    generatedAt: Date()
                ))
            }
        }

        return insights
    }

    // MARK: - Helper Functions

    /// Performs simple least-squares linear regression on (x, y) points.
    /// Returns (slope, intercept) of the best-fit line.
    private func linearRegression(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double) {
        guard points.count >= 2 else { return (0, 0) }

        let n = Double(points.count)
        let meanX = points.map { $0.x }.reduce(0, +) / n
        let meanY = points.map { $0.y }.reduce(0, +) / n

        let numerator = points.reduce(0) { acc, point in
            acc + (point.x - meanX) * (point.y - meanY)
        }

        let denominator = points.reduce(0) { acc, point in
            acc + (point.x - meanX) * (point.x - meanX)
        }

        guard denominator != 0 else { return (0, meanY) }

        let slope = numerator / denominator
        let intercept = meanY - slope * meanX

        return (slope, intercept)
    }

    /// Calculates coefficient of variation (stddev / mean).
    /// Used to measure relative variability in data.
    private func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2, values.allSatisfy({ $0 > 0 }) else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }

        let variance = values.reduce(0) { acc, val in
            acc + pow(val - mean, 2)
        } / Double(values.count)

        let stdDev = sqrt(variance)
        return stdDev / mean
    }
}
