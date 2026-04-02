//
//  iOS_Health_BridgeApp.swift
//  Forma
//

import SwiftUI
import BackgroundTasks
import OSLog

enum BackgroundExportScheduler {
    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.day = (components.day ?? 0) + 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }
}

@main
struct iOS_Health_BridgeApp: App {

    @State private var subscriptionManager = SubscriptionManager()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environment(subscriptionManager)
            .preferredColorScheme(.dark)
            .onAppear {
                scheduleNextExport()
            }
            .task {
                await subscriptionManager.loadSubscriptionStatus()
            }
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        // BGProcessingTask gives minutes of execution time — necessary for all
        // parallel HealthKit queries to complete before the task expires.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "PolyphasicDevs.iOS-Health-Bridge.HealthExport",
            using: nil
        ) { task in
            handleHealthExport(task: task as? BGProcessingTask)
        }
    }

    private func handleHealthExport(task: BGProcessingTask?) {
        scheduleNextExport()

        let exportTask = Task { @MainActor in
            let manager = HealthDataManager()
            await manager.checkAuthorizationStatus()
            guard manager.isAuthorized else {
                task?.setTaskCompleted(success: true)
                return
            }
            await manager.performExport()
            task?.setTaskCompleted(success: true)
        }

        task?.expirationHandler = {
            exportTask.cancel()
            task?.setTaskCompleted(success: false)
        }
    }

    private func scheduleNextExport() {
        let request = BGProcessingTaskRequest(
            identifier: "PolyphasicDevs.iOS-Health-Bridge.HealthExport"
        )
        request.earliestBeginDate = BackgroundExportScheduler.nextMidnight(after: Date())
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower       = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.background.error("Could not schedule health export: \(String(describing: error), privacy: .public)")
        }
    }
}
