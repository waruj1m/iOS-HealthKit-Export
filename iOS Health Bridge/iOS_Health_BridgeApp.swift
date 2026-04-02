//
//  iOS_Health_BridgeApp.swift
//  Forma
//

import SwiftUI
import BackgroundTasks

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
        let calendar  = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day!  += 1
        components.hour   = 0
        components.minute = 0
        request.earliestBeginDate      = calendar.date(from: components)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower       = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule health export: \(error)")
        }
    }
}
