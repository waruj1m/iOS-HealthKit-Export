import Foundation
import HealthKit

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
                print("Error loading records from disk: \(error)")
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
                print("Error loading goals from disk: \(error)")
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
            print("Error saving records to disk: \(error)")
        }

        // Save goals
        do {
            let encoder = JSONEncoder()
            let goalsArray = Array(goals.values)
            let goalsData = try encoder.encode(goalsArray)
            UserDefaults.standard.set(goalsData, forKey: goalsKey)
        } catch {
            print("Error saving goals to disk: \(error)")
        }
    }

    // MARK: - Record Processing

    func processNewData(_ summaries: [MetricSummary]) {
        recentlyBrokenRecords.removeAll()

        for summary in summaries {
            let metricType = summary.metricType
            let newValue = summary.displayValue

            let isBetter: Bool
            if let existingRecord = records[metricType] {
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
                    date: Date()
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
        if goal.target == 0 {
            return 0.0
        }

        let rawProgress = currentValue / goal.target
        return min(max(rawProgress, 0.0), 1.0)
    }

    func activeGoals() -> [HealthGoal] {
        Array(goals.values)
            .filter { $0.isActive }
            .sorted { $0.metricType.id < $1.metricType.id }
    }
}
