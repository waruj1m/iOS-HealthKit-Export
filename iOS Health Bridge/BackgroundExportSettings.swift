import Foundation

@Observable
final class BackgroundExportSettings {
    private static let automaticBackgroundExportEnabledKey = "automaticBackgroundExportEnabled"

    private let storage: HealthDataStoring

    var isAutomaticExportEnabled: Bool {
        didSet {
            storage.set(isAutomaticExportEnabled, forKey: Self.automaticBackgroundExportEnabledKey)
        }
    }

    init(storage: HealthDataStoring = UserDefaults.standard) {
        self.storage = storage
        self.isAutomaticExportEnabled = storage.bool(forKey: Self.automaticBackgroundExportEnabledKey)
    }
}
