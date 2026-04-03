import OSLog

enum AppLogger {
    static let ai = Logger(subsystem: "PolyphasicDevs.iOS-Health-Bridge", category: "ai")
    static let background = Logger(subsystem: "PolyphasicDevs.iOS-Health-Bridge", category: "background")
    static let persistence = Logger(subsystem: "PolyphasicDevs.iOS-Health-Bridge", category: "persistence")
    static let store = Logger(subsystem: "PolyphasicDevs.iOS-Health-Bridge", category: "store")
}
