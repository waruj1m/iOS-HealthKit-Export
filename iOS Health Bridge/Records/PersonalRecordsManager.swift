import Foundation
import HealthKit
import OSLog

@Observable final class PersonalRecordsManager {
    // MARK: - Properties

    private(set) var records: [HealthMetricType: PersonalRecord] = [:]
    private(set) var goals: [UUID: HealthGoal] = [:]
    private(set) var recentlyBrokenRecords: [PersonalRecord] = []

    private let recordsKey = "FormaPRs"
    private let goalsKey = "FormaGoals"

    init() {
        loadFromDisk()
    }

    // MARK: - Persistence

    func loadFromDisk() {
        // Load records
        if let recordsData = UserDefaults.standard.data(forKey: recordsKey) {
            do {
                let decoder = JSONDecoder()
                let recordArray = try decoder.decode([PersonalRecord].self, from: recordsData)
                records = Dictionary(uniqueKeysWithValues: recordArray.map { ($0.metricType, $0) })
            } catch {
                AppLogger.persistence.error("Error loading records from disk: \(String(describing: error), privacy: .public)")
                records = [:]
            }
        } else {
            records = [:]
        }

        // Load goals
        if let goalsData = UserDefaults.standard.data(forKey: goalsKey) {
            do {
                let decoder = JSONDecoder()
                let goalsArray = try decoder.decode([HealthGoal].self, from: goalsData)
                goals = Dictionary(uniqueKeysWithValues: goalsArray.map { ($0.id, $0) })
            } catch {
                AppLogger.persistence.error("Error loading goals from disk: \(String(describing: error), privacy: .public)")
                goals = [:]
            }
        } else {
            goals = [:]
        }
    }

    func saveToDisk() {
        // Save records
        do {
            let encoder = JSONEncoder()
            let recordsArray = Array(records.values)
            let recordsData = try encoder.encode(recordsArray)
            UserDefaults.standard.set(recordsData, forKey: recordsKey)
        } catch {
            AppLogger.persistence.error("Error saving records to disk: \(String(describing: error), privacy: .public)")
        }

        // Save goals
        do {
            let encoder = JSONEncoder()
            let goalsArray = Array(goals.values)
            let goalsData = try encoder.encode(goalsArray)
            UserDefaults.standard.set(goalsData, forKey: goalsKey)
        } catch {
            AppLogger.persistence.error("Error saving goals to disk: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Record Processing

    func processNewData(_ summaries: [MetricSummary]) {
        recentlyBrokenRecords.removeAll()

        for summary in summaries {
            let metricType = summary.metricType
            guard let candidate = recordCandidate(from: summary) else {
                continue
            }

            let newValue = candidate.value

            let isBetter: Bool
            if let existingRecord = records[metricType] {
                if shouldReplaceLegacyRecord(existingRecord, with: candidate, summary: summary) {
                    let correctedRecord = PersonalRecord(
                        metricType: metricType,
                        value: candidate.value,
                        date: candidate.date
                    )
                    records[metricType] = correctedRecord
                    continue
                }

                // Compare with existing record
                if metricType.higherIsBetter {
                    isBetter = newValue > existingRecord.value
                } else {
                    isBetter = newValue < existingRecord.value
                }
            } else {
                // No existing record, so this is a new PR
                isBetter = true
            }

            if isBetter {
                let newRecord = PersonalRecord(
                    metricType: metricType,
                    value: newValue,
                    date: candidate.date
                )
                records[metricType] = newRecord
                recentlyBrokenRecords.append(newRecord)
            }
        }

        saveToDisk()
    }

    // MARK: - Goal Management

    func setGoal(for metric: HealthMetricType, target: Double, period: HealthGoal.GoalPeriod) {
        let goal = HealthGoal(
            metricType: metric,
            target: target,
            period: period
        )
        goals[goal.id] = goal
        saveToDisk()
    }

    func removeGoal(id: UUID) {
        goals.removeValue(forKey: id)
        saveToDisk()
    }

    func progress(for goal: HealthGoal, currentValue: Double) -> Double {
        if goal.target == 0 || currentValue <= 0 {
            return 0.0
        }

        let rawProgress: Double
        if goal.metricType.higherIsBetter {
            rawProgress = currentValue / goal.target
        } else {
            rawProgress = goal.target / currentValue
        }

        return min(max(rawProgress, 0.0), 1.0)
    }

    func activeGoals() -> [HealthGoal] {
        Array(goals.values)
            .filter { $0.isActive }
            .sorted { $0.metricType.id < $1.metricType.id }
    }

    private func recordCandidate(from summary: MetricSummary) -> AggregatedDataPoint? {
        summary.recordPoint
    }

    private func shouldReplaceLegacyRecord(
        _ existingRecord: PersonalRecord,
        with candidate: AggregatedDataPoint,
        summary: MetricSummary
    ) -> Bool {
        let tolerance = 0.001

        if summary.metricType.recordStrategy == .latestValue {
            return candidate.date > existingRecord.date || abs(existingRecord.value - candidate.value) > tolerance
        }

        if summary.metricType.higherIsBetter {
            return existingRecord.value - candidate.value > tolerance
        }

        return candidate.value - existingRecord.value > tolerance
    }
}
