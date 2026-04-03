//
//  HealthDataManager.swift
//  iOS Health Bridge
//

import Foundation
import HealthKit

protocol HealthDataStoring: AnyObject {
    func double(forKey defaultName: String) -> Double
    func set(_ value: Double, forKey defaultName: String)
    func string(forKey defaultName: String) -> String?
    func set(_ value: String?, forKey defaultName: String)
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Bool, forKey defaultName: String)
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Data?, forKey defaultName: String)
}

extension UserDefaults: HealthDataStoring {
    func set(_ value: String?, forKey defaultName: String) {
        set(value as Any?, forKey: defaultName)
    }

    func set(_ value: Data?, forKey defaultName: String) {
        set(value as Any?, forKey: defaultName)
    }
}

@MainActor
@Observable
final class HealthDataManager {
    let healthStore = HKHealthStore()
    private let storage: HealthDataStoring
    private let isHealthDataAvailableProvider: () -> Bool
    private let authorizationStatusProvider: @MainActor @Sendable ([HKObjectType]) async throws -> HKAuthorizationRequestStatus
    private let requestAuthorizationHandler: @MainActor @Sendable ([HKObjectType]) async throws -> Void
    private let exportHandler: @MainActor @Sendable (URL, ExportFormat) async throws -> Void

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var lastExportDate: Date? {
        didSet {
            storage.set(lastExportDate?.timeIntervalSince1970 ?? 0, forKey: Self.lastExportDateKey)
        }
    }
    var exportError: String?
    var exportFolderDisplayName: String? {
        didSet {
            storage.set(exportFolderDisplayName, forKey: Self.exportFolderNameKey)
        }
    }
    private var exportFolderBookmarkData: Data? {
        didSet {
            storage.set(exportFolderBookmarkData, forKey: Self.exportFolderBookmarkKey)
        }
    }

    private static let lastExportDateKey = "lastExportDate"
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
        isHealthDataAvailableProvider()
    }

    private static let hasCompletedAuthorizationKey = "hasCompletedHealthAuthorization"

    init(
        storage: HealthDataStoring = UserDefaults.standard,
        isHealthDataAvailableProvider: @escaping () -> Bool = HKHealthStore.isHealthDataAvailable,
        authorizationStatusProvider: (@MainActor @Sendable ([HKObjectType]) async throws -> HKAuthorizationRequestStatus)? = nil,
        requestAuthorizationHandler: (@MainActor @Sendable ([HKObjectType]) async throws -> Void)? = nil,
        exportHandler: (@MainActor @Sendable (URL, ExportFormat) async throws -> Void)? = nil
    ) {
        self.storage = storage
        self.isHealthDataAvailableProvider = isHealthDataAvailableProvider
        self.authorizationStatusProvider = authorizationStatusProvider ?? { [healthStore] readTypes in
            try await healthStore.statusForAuthorizationRequest(toShare: [], read: Set(readTypes))
        }
        self.requestAuthorizationHandler = requestAuthorizationHandler ?? { [healthStore] readTypes in
            try await healthStore.requestAuthorization(toShare: [], read: Set(readTypes))
        }
        self.exportHandler = exportHandler ?? { [healthStore] folderURL, format in
            let service = HealthExportService(healthStore: healthStore)
            try await service.exportToFolder(folderURL, format: format)
        }

        let raw = storage.double(forKey: Self.lastExportDateKey)
        self.lastExportDate = raw > 0 ? Date(timeIntervalSince1970: raw) : nil
        self.exportFolderDisplayName = storage.string(forKey: Self.exportFolderNameKey)
        self.exportFolderBookmarkData = storage.data(forKey: Self.exportFolderBookmarkKey)
    }

    func checkAuthorizationStatus() async {
        guard isHealthDataAvailable else {
            authorizationStatus = .unavailable
            return
        }

        do {
            let requestStatus = try await authorizationStatusProvider(Self.readTypes)

            switch requestStatus {
            case .unnecessary:
                authorizationStatus = .authorized
            case .shouldRequest:
                authorizationStatus = storage.bool(forKey: Self.hasCompletedAuthorizationKey)
                    ? .denied
                    : .notDetermined
            case .unknown:
                authorizationStatus = .notDetermined
            @unknown default:
                authorizationStatus = .notDetermined
            }
        } catch {
            authorizationStatus = storage.bool(forKey: Self.hasCompletedAuthorizationKey)
                ? .denied
                : .notDetermined
        }
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            authorizationStatus = .unavailable
            throw HealthBridgeError.healthDataUnavailable
        }

        let typesToRead = Self.readTypes
        try await requestAuthorizationHandler(typesToRead)

        storage.set(true, forKey: Self.hasCompletedAuthorizationKey)
        await checkAuthorizationStatus()
    }

    var hasExportFolder: Bool {
        exportFolderBookmarkData != nil
    }

    func setExportFolder(bookmarkData: Data, displayName: String?) {
        exportFolderBookmarkData = bookmarkData
        exportFolderDisplayName = displayName ?? "Folder"
        exportError = nil
    }

    func performExport(format: ExportFormat = .json) async {
        guard isAuthorized else { return }
        guard let bookmarkData = exportFolderBookmarkData else {
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
        do {
            try await exportHandler(folderURL, format)
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
