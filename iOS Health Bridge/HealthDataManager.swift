//
//  HealthDataManager.swift
//  iOS Health Bridge
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthDataManager {
    private let healthStore = HKHealthStore()

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var lastExportDate: Date? = {
        let raw = UserDefaults.standard.double(forKey: "lastExportDate")
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }() {
        didSet {
            UserDefaults.standard.set(lastExportDate?.timeIntervalSince1970 ?? 0, forKey: "lastExportDate")
        }
    }
    var exportError: String?
    var exportFolderDisplayName: String? {
        get { UserDefaults.standard.string(forKey: Self.exportFolderNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.exportFolderNameKey) }
    }

    private static let exportFolderBookmarkKey = "exportFolderBookmark"
    private static let exportFolderNameKey = "exportFolderDisplayName"

    enum AuthorizationStatus {
        case notDetermined
        case unavailable
        case denied
        case authorized
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private static let hasCompletedAuthorizationKey = "hasCompletedHealthAuthorization"

    func checkAuthorizationStatus() async {
        guard isHealthDataAvailable else {
            authorizationStatus = .unavailable
            return
        }

        if UserDefaults.standard.bool(forKey: Self.hasCompletedAuthorizationKey) {
            authorizationStatus = .authorized
            return
        }

        authorizationStatus = .notDetermined
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            authorizationStatus = .unavailable
            throw HealthBridgeError.healthDataUnavailable
        }

        let typesToRead = Self.readTypes
        try await healthStore.requestAuthorization(toShare: [], read: Set(typesToRead))

        UserDefaults.standard.set(true, forKey: Self.hasCompletedAuthorizationKey)
        authorizationStatus = .authorized
    }

    var hasExportFolder: Bool {
        UserDefaults.standard.data(forKey: Self.exportFolderBookmarkKey) != nil
    }

    func setExportFolder(bookmarkData: Data, displayName: String?) {
        UserDefaults.standard.set(bookmarkData, forKey: Self.exportFolderBookmarkKey)
        exportFolderDisplayName = displayName ?? "Folder"
    }

    func performExport() async {
        guard isAuthorized else { return }
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.exportFolderBookmarkKey) else {
            exportError = "Set export folder first"
            return
        }
        var isStale = false
        guard let folderURL = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            exportError = "Export folder no longer accessible. Set a new folder."
            return
        }
        var didStartAccess = false
        if folderURL.startAccessingSecurityScopedResource() {
            didStartAccess = true
        }
        defer { if didStartAccess { folderURL.stopAccessingSecurityScopedResource() } }
        let service = HealthExportService(healthStore: healthStore)
        do {
            try await service.exportToFolder(folderURL)
            lastExportDate = Date()
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

    static var readTypes: [HKObjectType] {
        var types: [HKObjectType] = []

        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.append(stepCount)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.append(distance)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.append(activeEnergy)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.append(heartRate)
        }
        if let restingHeartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.append(restingHeartRate)
        }
        if let walkingHeartRate = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.append(walkingHeartRate)
        }
        if let oxygenSaturation = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            types.append(oxygenSaturation)
        }
        if let respiratoryRate = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
            types.append(respiratoryRate)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.append(bodyMass)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.append(height)
        }
        if let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.append(sleepAnalysis)
        }
        if let mindfulMinutes = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.append(mindfulMinutes)
        }
        types.append(HKWorkoutType.workoutType())

        return types
    }
}

enum HealthBridgeError: LocalizedError {
    case healthDataUnavailable
    case iCloudUnavailable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .iCloudUnavailable:
            return "iCloud is not available. Sign in to iCloud in Settings."
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
