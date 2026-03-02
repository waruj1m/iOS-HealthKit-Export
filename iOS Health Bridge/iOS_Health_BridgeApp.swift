//
//  iOS_Health_BridgeApp.swift
//  iOS Health Bridge
//

import SwiftUI
import BackgroundTasks

@main
struct iOS_Health_BridgeApp: App {
    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .onAppear {
                        scheduleNextExport()
                    }
            }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "PolyphasicDevs.iOS-Health-Bridge.HealthExport",
            using: nil
        ) { task in
            handleHealthExport(task: task as? BGAppRefreshTask)
        }
    }

    private func handleHealthExport(task: BGAppRefreshTask?) {
        scheduleNextExport()

        Task { @MainActor in
            let manager = HealthDataManager()
            await manager.checkAuthorizationStatus()
            guard manager.isAuthorized else {
                task?.setTaskCompleted(success: true)
                return
            }
            await manager.performExport()
            task?.setTaskCompleted(success: true)
        }
    }

    private func scheduleNextExport() {
        let request = BGAppRefreshTaskRequest(identifier: "PolyphasicDevs.iOS-Health-Bridge.HealthExport")
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 0
        components.minute = 0
        request.earliestBeginDate = calendar.date(from: components)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule health export: \(error)")
        }
    }
}
