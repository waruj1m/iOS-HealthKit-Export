//
//  ContentView.swift
//  iOS Health Bridge
//

import SwiftUI

struct ContentView: View {
    @State private var healthManager = HealthDataManager()
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @State private var isExporting = false

    var body: some View {
        Group {
            if !hasSeenIntro {
                IntroView(onContinue: { hasSeenIntro = true })
            } else if !healthManager.isAuthorized {
                AuthorizationView(
                    healthManager: healthManager,
                    onAuthorized: { Task { await healthManager.checkAuthorizationStatus() } }
                )
            } else {
                StatusView(
                    healthManager: healthManager,
                    isExporting: $isExporting,
                    onExportNow: exportNow
                )
            }
        }
        .task {
            await healthManager.checkAuthorizationStatus()
        }
    }

    private func exportNow() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            await healthManager.performExport()
            isExporting = false
        }
    }
}

struct IntroView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("iOS Health Bridge")
                        .font(.title.bold())
                    Text("Export your Apple Health data for use in other applications.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("What this app does")
                        .font(.headline)
                    Text("This app reads your health data from Apple Health and exports it as JSON files to a folder you choose. Exports run automatically every day at midnight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your data stays private")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("All data stays in your chosen folder")
                        bulletPoint("Nothing is sent to external servers")
                        bulletPoint("Exports run automatically daily at midnight")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 32)

                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
        }
    }
}

struct AuthorizationView: View {
    @Bindable var healthManager: HealthDataManager
    let onAuthorized: () -> Void
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if healthManager.authorizationStatus == .unavailable {
                    Label("Health data is not available on this device.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if healthManager.authorizationStatus == .denied {
                    Label("Health access was denied. Enable it in Settings > Health > Data Access.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Authorize Health Access")
                            .font(.title2.bold())
                        Text("To export your health data, this app needs permission to read from Apple Health. You will choose which data types to share.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data types we read:")
                            .font(.headline)
                        Text("Steps, distance, active energy, heart rate, sleep, workouts, body measurements, and related health metrics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        requestAuthorization()
                    } label: {
                        if isRequesting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Authorize Health Access")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)
                }
            }
            .padding(24)
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: healthManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorized {
                onAuthorized()
            }
        }
    }

    private func requestAuthorization() {
        isRequesting = true
        errorMessage = nil
        Task {
            do {
                try await healthManager.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
            }
            isRequesting = false
        }
    }
}

struct StatusView: View {
    @Bindable var healthManager: HealthDataManager
    @Binding var isExporting: Bool
    let onExportNow: () -> Void
    @State private var showFolderPicker = false

    var body: some View {
        List {
            Section {
                Label("Health access authorized", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Section("Export folder") {
                if let name = healthManager.exportFolderDisplayName {
                    Label(name, systemImage: "folder.fill")
                } else {
                    Text("No folder set")
                        .foregroundStyle(.secondary)
                }
                Button {
                    showFolderPicker = true
                } label: {
                    Label(healthManager.hasExportFolder ? "Change folder" : "Set folder", systemImage: "folder.badge.gearshape")
                }
            }

            Section("Last export") {
                if let date = healthManager.lastExportDate {
                    Text(date, format: .dateTime)
                } else {
                    Text("No export yet")
                        .foregroundStyle(.secondary)
                }
                if let error = healthManager.exportError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    onExportNow()
                } label: {
                    if isExporting {
                        HStack {
                            ProgressView()
                            Text("Exporting...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isExporting || !healthManager.hasExportFolder)
            }

            Section {
                Text("Exports run automatically every day at midnight. Ensure Background App Refresh is enabled in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Health Bridge")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker(
                onPick: { bookmarkData, displayName in
                    healthManager.setExportFolder(bookmarkData: bookmarkData, displayName: displayName)
                    showFolderPicker = false
                },
                onCancel: {
                    showFolderPicker = false
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
