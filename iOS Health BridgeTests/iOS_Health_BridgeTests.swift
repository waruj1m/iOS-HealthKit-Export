import Foundation
import HealthKit
import Testing
@testable import iOS_Health_Bridge

struct iOS_Health_BridgeTests {
    @Test func exportDocumentBuilderCSVQuotesFieldsAndSortsByDate() throws {
        let records = [
            ExportRecord(
                type: "heart,rate",
                date: "2026-04-03T09:30:00Z",
                value: 72,
                unit: "beats\"per\"minute",
                source: "Apple Watch"
            ),
            ExportRecord(
                type: "steps",
                date: "2026-04-01T09:30:00Z",
                value: 4000,
                unit: "count",
                source: "iPhone"
            )
        ]

        let csv = try #require(String(data: ExportDocumentBuilder.makeCSV(records: records), encoding: .utf8))
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines[0] == "type,date,value,unit,source")
        #expect(lines[1] == "\"steps\",\"2026-04-01T09:30:00Z\",4000.0,\"count\",\"iPhone\"")
        #expect(lines[2] == "\"heart,rate\",\"2026-04-03T09:30:00Z\",72.0,\"beats\"\"per\"\"minute\",\"Apple Watch\"")
    }

    @Test func exportDocumentBuilderJSONCreatesGroupedEnvelope() throws {
        let startDate = Date(timeIntervalSince1970: 1_500)
        let endDate = Date(timeIntervalSince1970: 2_500)
        let records = [
            ExportRecord(type: "steps", date: "2026-04-01T00:00:00Z", value: 1234, unit: "steps", source: "iPhone"),
            ExportRecord(type: "steps", date: "2026-04-02T00:00:00Z", value: 1500, unit: "steps", source: "Apple Watch"),
            ExportRecord(type: "heartRate", date: "2026-04-02T01:00:00Z", value: 62, unit: "bpm", source: "Apple Watch")
        ]

        let data = try ExportDocumentBuilder.makeJSON(records: records, startDate: startDate, endDate: endDate)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let dateRange = try #require(payload["dateRange"] as? [String: String])
        let dataTypes = try #require(payload["dataTypes"] as? [String: [[String: Any]]])

        #expect(payload["exportVersion"] as? String == "2.0")
        #expect(payload["deduplication"] as? String == "cumulative metrics use daily HealthKit statistics (Watch+iPhone deduplicated)")
        #expect(dateRange["start"] == ISO8601DateFormatter().string(from: startDate))
        #expect(dateRange["end"] == ISO8601DateFormatter().string(from: endDate))
        #expect(dataTypes.keys.sorted() == ["heartRate", "steps"])
        #expect(dataTypes["steps"]?.count == 2)
        #expect(dataTypes["heartRate"]?.first?["unit"] as? String == "bpm")
    }

    @Test func exportDocumentBuilderXLSXIncludesWorkbookPartsAndTruncatesSheetNames() throws {
        let longTypeName = "electrocardiogramVoltageMeasurements1234567890"
        let records = [
            ExportRecord(type: longTypeName, date: "2026-04-02T09:30:00Z", value: 1.2, unit: "mV", source: "Apple Watch"),
            ExportRecord(type: "steps", date: "2026-04-01T09:30:00Z", value: 4200, unit: "steps", source: "iPhone")
        ]

        let xlsx = ExportDocumentBuilder.makeXLSX(records: records)
        let archive = String(decoding: xlsx, as: UTF8.self)
        let truncatedSheetName = String(longTypeName.prefix(31))

        #expect(xlsx.starts(with: Data([0x50, 0x4B, 0x03, 0x04])))
        #expect(archive.contains("[Content_Types].xml"))
        #expect(archive.contains("xl/workbook.xml"))
        #expect(archive.contains("xl/sharedStrings.xml"))
        #expect(archive.contains("xl/worksheets/sheet1.xml"))
        #expect(archive.contains("xl/worksheets/sheet2.xml"))
        #expect(archive.contains("xl/worksheets/sheet3.xml"))
        #expect(archive.contains("All Data"))
        #expect(archive.contains("name=\"\(truncatedSheetName)\""))
        #expect(archive.contains("name=\"electrocardiogramVoltageMeasurements1234567890\"") == false)
    }

    @MainActor
    @Test func healthDataManagerMarksAuthorizedWhenAuthorizationIsUnnecessary() async {
        let manager = HealthDataManager(
            storage: InMemoryHealthDataStore(),
            isHealthDataAvailableProvider: { true },
            authorizationStatusProvider: { _ in .unnecessary }
        )

        await manager.checkAuthorizationStatus()

        #expect(manager.authorizationStatus == .authorized)
    }

    @MainActor
    @Test func healthDataManagerTreatsRequestedButMissingAccessAsDenied() async {
        let storage = InMemoryHealthDataStore()
        storage.set(true, forKey: "hasCompletedHealthAuthorization")
        let manager = HealthDataManager(
            storage: storage,
            isHealthDataAvailableProvider: { true },
            authorizationStatusProvider: { _ in .shouldRequest }
        )

        await manager.checkAuthorizationStatus()

        #expect(manager.authorizationStatus == .denied)
    }

    @MainActor
    @Test func healthDataManagerExportSuccessUpdatesTimestampAndClearsError() async throws {
        let storage = InMemoryHealthDataStore()
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let bookmark = try folderURL.bookmarkData()
        storage.set(bookmark, forKey: "exportFolderBookmark")

        var exportedURL: URL?
        var exportedFormat: ExportFormat?

        let manager = HealthDataManager(
            storage: storage,
            isHealthDataAvailableProvider: { true },
            authorizationStatusProvider: { _ in .unnecessary },
            exportHandler: { url, format in
                exportedURL = url
                exportedFormat = format
            }
        )

        await manager.checkAuthorizationStatus()
        await manager.performExport(format: .csv)

        #expect(exportedURL == folderURL)
        #expect(exportedFormat == .csv)
        #expect(manager.exportError == nil)
        #expect(manager.lastExportDate != nil)
    }

    @MainActor
    @Test func healthDataManagerSetExportFolderUpdatesObservableStateAndPersistsLatestSelection() throws {
        let storage = InMemoryHealthDataStore()
        let firstFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let secondFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: firstFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondFolderURL, withIntermediateDirectories: true)

        let firstBookmark = try firstFolderURL.bookmarkData()
        let secondBookmark = try secondFolderURL.bookmarkData()

        let manager = HealthDataManager(storage: storage)
        manager.exportError = "Previous export failure"

        manager.setExportFolder(bookmarkData: firstBookmark, displayName: "First")

        #expect(manager.hasExportFolder)
        #expect(manager.exportFolderDisplayName == "First")
        #expect(storage.data(forKey: "exportFolderBookmark") == firstBookmark)
        #expect(storage.string(forKey: "exportFolderDisplayName") == "First")
        #expect(manager.exportError == nil)

        manager.setExportFolder(bookmarkData: secondBookmark, displayName: "Second")

        #expect(manager.hasExportFolder)
        #expect(manager.exportFolderDisplayName == "Second")
        #expect(storage.data(forKey: "exportFolderBookmark") == secondBookmark)
        #expect(storage.string(forKey: "exportFolderDisplayName") == "Second")
    }

    @MainActor
    @Test func subscriptionManagerLoadsPremiumTierFromEntitlements() async {
        let manager = SubscriptionManager(
            productLoader: { _ in [] },
            entitlementIDsProvider: {
                AsyncStream { continuation in
                    continuation.yield(PremiumProductID.annual.rawValue)
                    continuation.finish()
                }
            },
            startTransactionListener: false
        )

        await manager.loadSubscriptionStatus()

        #expect(manager.tier == .premium)
    }

    @MainActor
    @Test func subscriptionManagerRestoreReturnsFalseWhenSyncFails() async {
        let manager = SubscriptionManager(
            productLoader: { _ in [] },
            entitlementIDsProvider: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            },
            syncHandler: {
                struct SyncFailure: Error {}
                throw SyncFailure()
            },
            startTransactionListener: false
        )

        let restored = await manager.restorePurchases()

        #expect(restored == false)
        #expect(manager.tier == .free)
    }

    @Test func analyticsComputationAverageReturnsMean() {
        let dataPoints = makeDataPoints([2, 4, 6])

        let average = AnalyticsComputation.average(for: dataPoints)

        #expect(average == 4)
    }

    @Test func analyticsComputationTrendHandlesLowerIsBetterMetrics() {
        let dataPoints = makeDataPoints([70, 68, 65])

        let trend = AnalyticsComputation.trend(from: dataPoints, metric: .restingHeartRate)

        if case .up = trend {
            #expect(Bool(true))
        } else {
            Issue.record("Expected an improving trend for lower-is-better metrics.")
        }
    }

    @Test func analyticsComputationDateIntervalUsesMonthlyBucketsForYearViews() {
        let interval = AnalyticsComputation.dateInterval(for: .year)

        #expect(interval.month == 1)
        #expect(interval.day == nil)
    }

    @Test func backgroundExportSchedulerSchedulesNextMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let current = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 2,
            hour: 14,
            minute: 37,
            second: 20
        ))!

        let nextRun = BackgroundExportScheduler.nextMidnight(after: current, calendar: calendar)
        let expected = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 3,
            hour: 0,
            minute: 0,
            second: 0
        ))

        #expect(nextRun == expected)
    }

    @Test func backgroundExportSchedulerRequiresPremiumAndOptIn() {
        #expect(BackgroundExportScheduler.shouldSchedule(tier: .free, automaticExportEnabled: false) == false)
        #expect(BackgroundExportScheduler.shouldSchedule(tier: .free, automaticExportEnabled: true) == false)
        #expect(BackgroundExportScheduler.shouldSchedule(tier: .premium, automaticExportEnabled: false) == false)
        #expect(BackgroundExportScheduler.shouldSchedule(tier: .premium, automaticExportEnabled: true) == true)
    }

    @Test func backgroundExportSettingsDefaultsToDisabledAndPersistsChanges() {
        let storage = InMemoryHealthDataStore()
        let settings = BackgroundExportSettings(storage: storage)

        #expect(settings.isAutomaticExportEnabled == false)

        settings.isAutomaticExportEnabled = true

        #expect(settings.isAutomaticExportEnabled == true)
        #expect(storage.bool(forKey: "automaticBackgroundExportEnabled") == true)

        let reloaded = BackgroundExportSettings(storage: storage)

        #expect(reloaded.isAutomaticExportEnabled == true)
    }

    @Test func measurementSettingsDefaultsToMetricAndPersistsImperialSelection() {
        let storage = InMemoryHealthDataStore()
        let settings = MeasurementSettings(storage: storage)

        #expect(settings.measurementSystem == .metric)

        settings.measurementSystem = .imperial

        #expect(settings.measurementSystem == .imperial)
        #expect(storage.string(forKey: "measurementSystem") == "imperial")
        #expect(MeasurementSettings(storage: storage).measurementSystem == .imperial)
    }

    @Test func metricDisplayFormattingConvertsDistanceAndBodyMassForImperial() {
        let distanceSummary = makeSummary(
            metric: .distance,
            points: [5.0, 6.0],
            average: 5.5,
            total: 11.0
        )
        let bodyMassRecord = PersonalRecord(metricType: .bodyMass, value: 80, date: .now)

        #expect(distanceSummary.formattedDisplay(measurementSystem: .metric) == "11.00")
        #expect(distanceSummary.formattedDisplay(measurementSystem: .imperial) == "6.84")
        #expect(HealthMetricType.distance.displayUnit(for: .imperial) == "mi")
        #expect(HealthMetricType.bodyMass.displayUnit(for: .imperial) == "lb")
        #expect(bodyMassRecord.formattedValue(measurementSystem: .imperial) == "176.4 lb")
    }

    @Test func timePeriodShiftedEndDateMovesByWholePeriods() {
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 3,
            hour: 12
        ))!

        let shiftedDay = TimePeriod.day.shiftedEndDate(relativeTo: reference, by: -1, calendar: calendar)
        let shiftedWeek = TimePeriod.week.shiftedEndDate(relativeTo: reference, by: 1, calendar: calendar)

        #expect(calendar.component(.day, from: shiftedDay) == 2)
        #expect(calendar.component(.day, from: shiftedWeek) == 10)
    }

    @Test func timePeriodDayStartsAtBeginningOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        let midday = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 2,
            hour: 14,
            minute: 37
        ))!

        let start = TimePeriod.day.startDate(relativeTo: midday)
        let expected = calendar.startOfDay(for: midday)

        #expect(start == expected)
    }

    @Test func timePeriodWeekAnchorsToStartOfDayBeforeSubtractingWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let midday = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: 2026,
            month: 4,
            day: 2,
            hour: 14,
            minute: 37
        ))!

        let start = TimePeriod.week.startDate(relativeTo: midday)
        let expected = calendar.date(byAdding: .weekOfYear, value: -1, to: calendar.startOfDay(for: midday))!

        #expect(start == expected)
    }

    @Test func goalPeriodDailyIntervalSpansCurrentCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let referenceDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 3,
            hour: 9,
            minute: 52
        ))!

        let interval = HealthGoal.GoalPeriod.daily.interval(
            containing: referenceDate,
            calendar: calendar
        )

        #expect(interval.start == calendar.startOfDay(for: referenceDate))
        #expect(interval.end == calendar.date(byAdding: .day, value: 1, to: interval.start))
    }

    @Test func goalPeriodWeeklyIntervalUsesCalendarWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let referenceDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 3,
            hour: 9,
            minute: 52
        ))!

        let interval = HealthGoal.GoalPeriod.weekly.interval(
            containing: referenceDate,
            calendar: calendar
        )
        let expected = calendar.dateInterval(of: .weekOfYear, for: referenceDate)

        #expect(interval == expected)
    }

    @Test func analyticsGoalValueUsesIntervalSumForCumulativeMetrics() {
        let value = AnalyticsComputation.goalValue(
            from: makeDataPoints([3400, 2800, 3900]),
            metric: .steps
        )

        #expect(value == 10_100)
    }

    @Test func analyticsGoalValueUsesLatestReadingForDiscreteMetrics() {
        let value = AnalyticsComputation.goalValue(
            from: makeDataPoints([81.4, 80.9, 80.2]),
            metric: .bodyMass
        )

        #expect(value == 80.2)
    }

    @Test func oxygenSaturationFormattingUsesWholePercentDisplay() {
        let summary = makeSummary(
            metric: .oxygenSaturation,
            points: [0.97, 0.98, 0.99],
            average: 0.98,
            total: nil
        )

        #expect(summary.formattedDisplay() == "98")
    }

    @Test func trendEngineDetectsActiveStepStreak() {
        let engine = TrendEngine()
        let steps = makeSummary(
            metric: .steps,
            points: [6200, 7000, 8100, 9000],
            average: 7575,
            total: 30300
        )

        let insights = engine.generateInsights(from: [steps], period: .week)

        #expect(insights.contains(where: { $0.title.contains("activity streak") }))
    }

    @Test func trendEngineFlagsChronicSleepDebt() {
        let engine = TrendEngine()
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [5.4, 5.8, 5.6],
            average: 5.6,
            total: nil
        )

        let insights = engine.generateInsights(from: [sleep], period: .week)

        #expect(insights.contains(where: { $0.title == "Chronic sleep debt detected" }))
    }

    @Test func trendEngineDetectsTrainingAndRecoveryAlignment() {
        let engine = TrendEngine()
        let workouts = makeSummary(
            metric: .workoutCount,
            points: [0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
            average: 0.71,
            total: 10
        )
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [7.2, 7.4, 7.1, 7.3, 7.5, 7.0, 7.4],
            average: 7.27,
            total: nil
        )

        let insights = engine.generateInsights(from: [workouts, sleep], period: .week)

        #expect(insights.contains(where: { $0.title == "Training and recovery in sync" }))
    }

    @Test func trendEngineReturnsUniqueInsightTitles() {
        let engine = TrendEngine()
        let steps = makeSummary(
            metric: .steps,
            points: [8000, 8100, 8200, 8300],
            average: 8150,
            total: 32600
        )
        let sleep = makeSummary(
            metric: .sleepDuration,
            points: [8.0, 8.1, 8.2, 8.0],
            average: 8.08,
            total: nil
        )
        let bodyMass = makeSummary(
            metric: .bodyMass,
            points: [80.0, 79.7, 79.4, 79.1, 78.8],
            average: 79.4,
            total: nil
        )

        let insights = engine.generateInsights(from: [steps, sleep, bodyMass], period: .month)
        let titles = insights.map(\.title)

        #expect(Set(titles).count == titles.count)
    }

    @Test func aiCoachContextSnapshotFormatsMetricAndInsightPayload() {
        let summaries = [
            makeSummary(
                metric: .distance,
                points: [5.0, 6.0, 7.5],
                average: 6.17,
                total: 18.5
            )
        ]
        let insights = [
            HealthInsight(
                title: "Recovery trending up",
                body: "Your recent sleep and resting HR suggest solid recovery.",
                severity: .positive,
                category: .recovery,
                relatedMetrics: [.sleepDuration, .restingHeartRate],
                generatedAt: .now
            )
        ]

        let snapshot = AICoachContextSnapshot.make(
            measurementSystem: .imperial,
            weeklySummaries: summaries,
            monthlySummaries: [],
            weeklyInsights: insights,
            monthlyInsights: []
        )

        #expect(snapshot.measurementSystem == "imperial")
        #expect(snapshot.weeklyMetrics.count == 1)
        #expect(snapshot.weeklyMetrics[0].metric == "Distance")
        #expect(snapshot.weeklyMetrics[0].unit == "mi")
        #expect(snapshot.weeklyInsights.first?.category == "Recovery")
    }

    @MainActor
    @Test func aiCoachSessionAppendsAssistantReplyFromService() async {
        let session = AICoachSession(
            healthStore: HKHealthStore(),
            service: MockAICoachService(reply: "Take an easier session today."),
            configuration: AICoachConfiguration(
                proxyURL: URL(string: "https://example.com/coach"),
                model: "gpt-5.4"
            )
        )

        session.contextSnapshot = AICoachContextSnapshot.make(
            measurementSystem: .metric,
            weeklySummaries: [],
            monthlySummaries: [],
            weeklyInsights: [],
            monthlyInsights: []
        )

        await session.send("How am I recovering?", measurementSystem: .metric)

        #expect(session.messages.count == 2)
        #expect(session.messages[0].role == .user)
        #expect(session.messages[1].role == .assistant)
        #expect(session.messages[1].content == "Take an easier session today.")
    }

    @Test func remoteAiCoachServiceRequiresProxyConfiguration() async {
        let service = RemoteAICoachService(
            configuration: AICoachConfiguration(proxyURL: nil, model: "gpt-5.4")
        )

        await #expect(throws: AICoachServiceError.missingConfiguration) {
            _ = try await service.send(
                messages: [],
                context: AICoachContextSnapshot.make(
                    measurementSystem: .metric,
                    weeklySummaries: [],
                    monthlySummaries: [],
                    weeklyInsights: [],
                    monthlyInsights: []
                )
            )
        }
    }

    private func makeSummary(
        metric: HealthMetricType,
        points: [Double],
        average: Double,
        total: Double?
    ) -> MetricSummary {
        let dataPoints = points.enumerated().map { index, value in
            AggregatedDataPoint(
                date: Calendar(identifier: .gregorian).date(from: DateComponents(
                    timeZone: .gmt,
                    year: 2026,
                    month: 4,
                    day: index + 1
                ))!,
                value: value
            )
        }

        return MetricSummary(
            metricType: metric,
            period: .week,
            current: dataPoints.last?.value,
            average: average,
            minimum: dataPoints.map(\.value).min() ?? 0,
            maximum: dataPoints.map(\.value).max() ?? 0,
            total: total,
            dataPoints: dataPoints,
            percentChange: nil,
            trend: .flat
        )
    }

    private func makeDataPoints(_ values: [Double]) -> [AggregatedDataPoint] {
        values.enumerated().map { index, value in
            AggregatedDataPoint(
                date: Calendar(identifier: .gregorian).date(from: DateComponents(
                    timeZone: .gmt,
                    year: 2026,
                    month: 4,
                    day: index + 1
                ))!,
                value: value
            )
        }
    }
}

private struct MockAICoachService: AICoachServicing {
    let reply: String

    func send(messages: [AIChatMessage], context: AICoachContextSnapshot) async throws -> AICoachReply {
        AICoachReply(text: reply)
    }
}

private final class InMemoryHealthDataStore: HealthDataStoring {
    private var values: [String: Any] = [:]

    func double(forKey defaultName: String) -> Double {
        values[defaultName] as? Double ?? 0
    }

    func set(_ value: Double, forKey defaultName: String) {
        values[defaultName] = value
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func set(_ value: String?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func bool(forKey defaultName: String) -> Bool {
        values[defaultName] as? Bool ?? false
    }

    func set(_ value: Bool, forKey defaultName: String) {
        values[defaultName] = value
    }

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Data?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
