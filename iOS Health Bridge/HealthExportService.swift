//
//  HealthExportService.swift
//  iOS Health Bridge
//

import Foundation
import HealthKit

struct HealthExportService {
    private let healthStore: HKHealthStore
    private let exportFolderName = "iOSHealthBridge"
    private let healthExportsSubfolder = "HealthExports"

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func generateExportData() async throws -> (Data, String) {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        var allExports: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: endDate),
            "exportVersion": "1.0",
            "dateRange": [
                "start": ISO8601DateFormatter().string(from: startDate),
                "end": ISO8601DateFormatter().string(from: endDate)
            ],
            "dataTypes": [:]
        ]

        var dataTypes: [String: Any] = [:]

        if let stepData = await queryQuantityType(.stepCount, unit: .count(), start: startDate, end: endDate) {
            dataTypes["stepCount"] = stepData
        }
        if let distanceData = await queryQuantityType(.distanceWalkingRunning, unit: .meter(), start: startDate, end: endDate) {
            dataTypes["distanceWalkingRunning"] = distanceData
        }
        if let energyData = await queryQuantityType(.activeEnergyBurned, unit: .kilocalorie(), start: startDate, end: endDate) {
            dataTypes["activeEnergyBurned"] = energyData
        }
        if let heartRateData = await queryQuantityType(.heartRate, unit: HKUnit(from: "count/min"), start: startDate, end: endDate) {
            dataTypes["heartRate"] = heartRateData
        }
        if let restingHRData = await queryQuantityType(.restingHeartRate, unit: HKUnit(from: "count/min"), start: startDate, end: endDate) {
            dataTypes["restingHeartRate"] = restingHRData
        }
        if let oxygenData = await queryQuantityType(.oxygenSaturation, unit: .percent(), start: startDate, end: endDate) {
            dataTypes["oxygenSaturation"] = oxygenData
        }
        if let respiratoryData = await queryQuantityType(.respiratoryRate, unit: HKUnit(from: "count/min"), start: startDate, end: endDate) {
            dataTypes["respiratoryRate"] = respiratoryData
        }
        if let bodyMassData = await queryQuantityType(.bodyMass, unit: .gramUnit(with: .kilo), start: startDate, end: endDate) {
            dataTypes["bodyMass"] = bodyMassData
        }
        if let heightData = await queryQuantityType(.height, unit: .meter(), start: startDate, end: endDate) {
            dataTypes["height"] = heightData
        }
        if let sleepData = await querySleepAnalysis(start: startDate, end: endDate) {
            dataTypes["sleepAnalysis"] = sleepData
        }
        if let mindfulData = await queryMindfulSessions(start: startDate, end: endDate) {
            dataTypes["mindfulSessions"] = mindfulData
        }
        if let workoutData = await queryWorkouts(start: startDate, end: endDate) {
            dataTypes["workouts"] = workoutData
        }

        allExports["dataTypes"] = dataTypes

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: endDate)
        let fileName = "health_export_\(dateString).json"
        let data = try JSONSerialization.data(withJSONObject: allExports, options: [.prettyPrinted, .sortedKeys])
        return (data, fileName)
    }

    func exportToiCloud() async throws {
        let containerURL = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.PolyphasicDevs.iOS-Health-Bridge")
                ?? FileManager.default.url(forUbiquityContainerIdentifier: nil)
        }.value

        guard let containerURL else {
            throw HealthBridgeError.iCloudUnavailable
        }

        let (data, fileName) = try await generateExportData()

        let exportBaseURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent(exportFolderName)
            .appendingPathComponent(healthExportsSubfolder)

        try FileManager.default.createDirectory(at: exportBaseURL, withIntermediateDirectories: true)

        let fileURL = exportBaseURL.appendingPathComponent(fileName)
        try await coordinateWrite(to: fileURL, data: data)
    }

    func exportToFolder(_ folderURL: URL) async throws {
        let (data, fileName) = try await generateExportData()
        let fileURL = folderURL.appendingPathComponent(fileName)
        try await coordinateWrite(to: fileURL, data: data)
    }

    private func coordinateWrite(to url: URL, data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                do {
                    try data.write(to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error = coordinationError {
                continuation.resume(throwing: error)
            }
        }
    }

    private func queryQuantityType(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> [[String: Any]]? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let results = samples.map { sample in
                    [
                        "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                        "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                        "value": sample.quantity.doubleValue(for: unit),
                        "unit": unit.unitString,
                        "source": sample.sourceRevision.source.name
                    ] as [String: Any]
                }
                continuation.resume(returning: results.isEmpty ? nil : results)
            }
            healthStore.execute(query)
        }
    }

    private func querySleepAnalysis(start: Date, end: Date) async -> [[String: Any]]? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let valueStrings: [Int: String] = [
                    0: "inBed",
                    1: "asleepUnspecified",
                    2: "awake",
                    3: "asleepCore",
                    4: "asleepDeep",
                    5: "asleepREM"
                ]
                let results = samples.map { sample in
                    [
                        "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                        "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                        "value": valueStrings[sample.value] ?? "unknown",
                        "source": sample.sourceRevision.source.name
                    ] as [String: Any]
                }
                continuation.resume(returning: results.isEmpty ? nil : results)
            }
            healthStore.execute(query)
        }
    }

    private func queryMindfulSessions(start: Date, end: Date) async -> [[String: Any]]? {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return nil }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let results = samples.map { sample in
                    [
                        "startDate": ISO8601DateFormatter().string(from: sample.startDate),
                        "endDate": ISO8601DateFormatter().string(from: sample.endDate),
                        "durationSeconds": sample.endDate.timeIntervalSince(sample.startDate),
                        "source": sample.sourceRevision.source.name
                    ] as [String: Any]
                }
                continuation.resume(returning: results.isEmpty ? nil : results)
            }
            healthStore.execute(query)
        }
    }

    private func queryWorkouts(start: Date, end: Date) async -> [[String: Any]]? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let results = workouts.map { workout in
                    var dict: [String: Any] = [
                        "startDate": ISO8601DateFormatter().string(from: workout.startDate),
                        "endDate": ISO8601DateFormatter().string(from: workout.endDate),
                        "durationSeconds": workout.duration,
                        "workoutActivityType": workout.workoutActivityType.rawValue,
                        "source": workout.sourceRevision.source.name
                    ]
                    if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        dict["totalEnergyBurned"] = energy
                    }
                    if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                        dict["totalDistance"] = distance
                    }
                    return dict
                }
                continuation.resume(returning: results.isEmpty ? nil : results)
            }
            healthStore.execute(query)
        }
    }
}
