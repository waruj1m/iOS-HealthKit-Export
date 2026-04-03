import Foundation

enum MeasurementSystem: String, CaseIterable, Codable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}

@Observable
final class MeasurementSettings {
    private static let measurementSystemKey = "measurementSystem"

    private let storage: HealthDataStoring

    var measurementSystem: MeasurementSystem {
        didSet {
            storage.set(measurementSystem.rawValue, forKey: Self.measurementSystemKey)
        }
    }

    init(storage: HealthDataStoring = UserDefaults.standard) {
        self.storage = storage
        self.measurementSystem = MeasurementSystem(
            rawValue: storage.string(forKey: Self.measurementSystemKey) ?? ""
        ) ?? .metric
    }
}
