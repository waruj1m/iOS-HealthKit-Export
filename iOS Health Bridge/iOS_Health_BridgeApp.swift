//
//  iOS_Health_BridgeApp.swift
//  Forma
//

import SwiftUI
import BackgroundTasks
import OSLog

enum BackgroundExportScheduler {
    static let taskIdentifier = "PolyphasicDevs.iOS-Health-Bridge.HealthExport"

    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.day = (components.day ?? 0) + 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    static func shouldSchedule(tier: SubscriptionTier, automaticExportEnabled: Bool) -> Bool {
        tier == .premium && automaticExportEnabled
    }
}

@main
struct iOS_Health_BridgeApp: App {

    @State private var subscriptionManager = SubscriptionManager()
    @State private var backgroundExportSettings = BackgroundExportSettings()
    @State private var measurementSettings = MeasurementSettings()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environment(subscriptionManager)
            .environment(backgroundExportSettings)
            .environment(measurementSettings)
            .preferredColorScheme(.dark)
            .onAppear {
                reconcileBackgroundExportSchedule()
            }
            .task {
                await subscriptionManager.loadSubscriptionStatus()
                reconcileBackgroundExportSchedule()
            }
            .onChange(of: subscriptionManager.tier) { _, _ in
                reconcileBackgroundExportSchedule()
            }
            .onChange(of: backgroundExportSettings.isAutomaticExportEnabled) { _, _ in
                reconcileBackgroundExportSchedule()
            }
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        // BGProcessingTask gives minutes of execution time — necessary for all
        // parallel HealthKit queries to complete before the task expires.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundExportScheduler.taskIdentifier,
            using: nil
        ) { task in
            handleHealthExport(task: task as? BGProcessingTask)
        }
    }

    private func handleHealthExport(task: BGProcessingTask?) {
        reconcileBackgroundExportSchedule()

        let exportTask = Task { @MainActor in
            let exportSettings = BackgroundExportSettings()
            let subscriptionManager = SubscriptionManager()
            await subscriptionManager.loadSubscriptionStatus()

            guard BackgroundExportScheduler.shouldSchedule(
                tier: subscriptionManager.tier,
                automaticExportEnabled: exportSettings.isAutomaticExportEnabled
            ) else {
                task?.setTaskCompleted(success: true)
                return
            }

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

    private func reconcileBackgroundExportSchedule() {
        guard BackgroundExportScheduler.shouldSchedule(
            tier: subscriptionManager.tier,
            automaticExportEnabled: backgroundExportSettings.isAutomaticExportEnabled
        ) else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundExportScheduler.taskIdentifier)
            return
        }

        scheduleNextExport()
    }

    private func scheduleNextExport() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundExportScheduler.taskIdentifier)

        let request = BGProcessingTaskRequest(
            identifier: BackgroundExportScheduler.taskIdentifier
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
