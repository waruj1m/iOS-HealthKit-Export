import SwiftUI
import HealthKit

struct PersonalRecordsView: View {
    // MARK: - Properties

    let healthManager: HealthDataManager

    @State private var dataService: AnalyticsDataService
    @State private var recordsManager = PersonalRecordsManager()
    @State private var summaries: [MetricSummary] = []
    @State private var isLoading = false
    @State private var showAddGoal = false
    @State private var newlyBrokenRecord: PersonalRecord?

    // MARK: - Init

    init(healthManager: HealthDataManager) {
        self.healthManager = healthManager
        _dataService = State(initialValue: AnalyticsDataService(healthStore: healthManager.healthStore))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ShimmerView()
                            .frame(height: 120)
                        ShimmerView()
                            .frame(height: 240)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // New record banner
                            if let record = newlyBrokenRecord {
                                NewRecordBanner(record: record)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // Personal Records Section
                            recordsSection

                            // Goals Section
                            goalsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .task {
                await loadRecords()
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet(recordsManager: recordsManager)
            }
        }
    }

    // MARK: - Sections

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormaSectionHeader(title: "Personal Records")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(HealthMetricType.allCases) { metricType in
                    RecordCard(
                        metricType: metricType,
                        record: recordsManager.records[metricType]
                    )
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormaSectionHeader(title: "Active Goals")

            if recordsManager.activeGoals().isEmpty {
                VStack(spacing: 8) {
                    Text("No active goals")
                        .font(.system(size: 15))
                        .foregroundColor(FormaColors.subtext)
                    Text("Set a goal to get started")
                        .font(FormaType.caption())
                        .foregroundColor(FormaColors.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(FormaColors.card)
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(recordsManager.activeGoals()) { goal in
                        let currentValue = summaries
                            .first { $0.metricType == goal.metricType }
                            .map { $0.displayValue } ?? 0.0
                        let progress = recordsManager.progress(
                            for: goal,
                            currentValue: currentValue
                        )

                        GoalProgressRow(
                            goal: goal,
                            progress: progress,
                            currentValue: currentValue,
                            onDelete: {
                                recordsManager.removeGoal(id: goal.id)
                            }
                        )
                    }
                }
            }

            Button(action: { showAddGoal = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Goal")
                        .font(.system(size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .foregroundColor(FormaColors.teal)
                .background(FormaColors.teal.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Data Loading

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            recordsManager.loadFromDisk()

            let newSummaries = await dataService.fetchAllSummaries(period: .allTime)
            self.summaries = newSummaries

            recordsManager.processNewData(newSummaries)

            if let record = recordsManager.recentlyBrokenRecords.first {
                newlyBrokenRecord = record
                try await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation {
                    newlyBrokenRecord = nil
                }
            }

            recordsManager.saveToDisk()
        } catch {
            print("Error loading records: \(error)")
        }
    }
}

// MARK: - RecordCard

struct RecordCard: View {
    let metricType: HealthMetricType
    let record: PersonalRecord?

    var body: some View {
        FormaCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Icon + Name + PR Badge
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: metricType.sfSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(metricType.accentColor)

                        Text(metricType.id.uppercased())
                            .font(FormaType.caption())
                            .foregroundColor(FormaColors.subtext)
                    }

                    Spacer()

                    if record != nil {
                        Text("PR")
                            .font(FormaType.caption())
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(metricType.accentColor)
                            .cornerRadius(6)
                    }
                }

                // Value
                if let record = record {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.formattedValue)
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(FormaColors.textPrimary)

                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                            .font(FormaType.caption())
                            .foregroundColor(FormaColors.muted)
                    }
                } else {
                    Text("--")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(FormaColors.muted)
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            metricType.accentColor.opacity(0.05),
                            metricType.accentColor.opacity(0.02),
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - GoalProgressRow

struct GoalProgressRow: View {
    let goal: HealthGoal
    let progress: Double
    let currentValue: Double
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        FormaCard {
            HStack(spacing: 12) {
                // Left: Icon
                Image(systemName: goal.metricType.sfSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(goal.metricType.accentColor)
                    .frame(width: 40)

                // Center: Name + Progress Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.metricType.id.uppercased())
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(FormaColors.textPrimary)

                    Text("\(currentValue.formatted(.number.precision(.fractionLength(1)))) / \(goal.target.formatted(.number.precision(.fractionLength(1)))) \(goal.metricType.unit) · \(goal.period.rawValue.capitalized)")
                        .font(FormaType.caption())
                        .foregroundColor(FormaColors.subtext)
                }

                Spacer()

                // Right: Circular Progress Ring
                ZStack {
                    Circle()
                        .stroke(FormaColors.card, lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            goal.metricType.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    Text("\((progress * 100).formatted(.number.precision(.fractionLength(0))))%")
                        .font(FormaType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(FormaColors.textPrimary)
                }
                .frame(width: 60, height: 60)
            }
            .padding(12)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: {
                isConfirmingDelete = true
            }) {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .alert("Delete Goal?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This goal will be permanently removed.")
        }
    }
}

// MARK: - AddGoalSheet

struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let recordsManager: PersonalRecordsManager

    @State private var selectedMetric: HealthMetricType = .steps
    @State private var targetValue: Double = 10000
    @State private var selectedPeriod: HealthGoal.GoalPeriod = .daily

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        FormaSectionHeader(title: "Metric")

                        Picker("Metric", selection: $selectedMetric) {
                            ForEach(HealthMetricType.allCases) { metric in
                                HStack {
                                    Image(systemName: metric.sfSymbol)
                                        .foregroundColor(metric.accentColor)
                                    Text(metric.id.uppercased())
                                }
                                .tag(metric)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                        .background(FormaColors.card)
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FormaSectionHeader(title: "Target")

                        HStack {
                            TextField("Enter target", value: $targetValue, format: .number)
                                .font(.system(size: 15))
                                .foregroundColor(FormaColors.textPrimary)
                                .keyboardType(.decimalPad)

                            Text(selectedMetric.unit)
                                .font(.system(size: 15))
                                .foregroundColor(FormaColors.subtext)
                        }
                        .padding(12)
                        .background(FormaColors.card)
                        .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        FormaSectionHeader(title: "Period")

                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(HealthGoal.GoalPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue.capitalized).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Spacer()

                    Button(action: saveGoal) {
                        Text("Save Goal")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundColor(.white)
                            .background(FormaColors.teal)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(FormaColors.teal)
                }
            }
        }
    }

    private func saveGoal() {
        recordsManager.setGoal(
            for: selectedMetric,
            target: targetValue,
            period: selectedPeriod
        )
        dismiss()
    }
}

// MARK: - NewRecordBanner

struct NewRecordBanner: View {
    let record: PersonalRecord

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(FormaColors.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Personal Record!")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(FormaColors.textPrimary)

                    Text("\(record.metricType.id.uppercased()) – \(record.formattedValue)")
                        .font(FormaType.caption())
                        .foregroundColor(FormaColors.subtext)
                }

                Spacer()

                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundColor(FormaColors.orange)
            }
            .padding(12)
            .background(FormaColors.orange.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(FormaColors.orange.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    let mockHealthManager = HealthDataManager()
    PersonalRecordsView(healthManager: mockHealthManager)
}
