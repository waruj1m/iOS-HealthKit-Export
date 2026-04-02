//
//  ExportView.swift
//  Forma
//
//  The free-tier export tab — lets users manually trigger a JSON export and
//  manage the destination folder. Carries over the core functionality from the
//  original StatusView.
//

import SwiftUI

struct ExportView: View {
    @Bindable var healthManager : HealthDataManager
    @State private var isExporting      = false
    @State private var showFolderPicker = false
    @State private var showSuccess      = false
    @State private var exportFormat: ExportFormat = .json

    var body: some View {
        NavigationStack {
            ZStack {
                FormaColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Status card
                        statusCard

                        // Folder card
                        folderCard

                        // Format picker card
                        formatCard

                        // Last export card
                        lastExportCard

                        // Export button
                        exportButton

                        // Info footer
                        infoFooter
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FormaColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker(
                    onPick: { bookmarkData, displayName in
                        healthManager.setExportFolder(bookmarkData: bookmarkData,
                                                      displayName: displayName)
                        showFolderPicker = false
                    },
                    onCancel: { showFolderPicker = false }
                )
            }
            .overlay(successToast, alignment: .bottom)
        }
    }

    // MARK: Sub-views

    private var statusCard: some View {
        FormaCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(FormaColors.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HealthKit Connected")
                        .font(FormaType.cardTitle())
                        .foregroundStyle(FormaColors.textPrimary)
                    Text("Authorized to read health data")
                        .font(FormaType.caption())
                        .foregroundStyle(FormaColors.subtext)
                }
                Spacer()
            }
        }
    }

    private var folderCard: some View {
        FormaCard {
            VStack(alignment: .leading, spacing: 12) {
                FormaSectionHeader(title: "Export Destination")

                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(FormaColors.teal)
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = healthManager.exportFolderDisplayName {
                            Text(name)
                                .font(FormaType.cardTitle())
                                .foregroundStyle(FormaColors.textPrimary)
                                .lineLimit(1)
                        } else {
                            Text("No folder selected")
                                .font(FormaType.cardTitle())
                                .foregroundStyle(FormaColors.subtext)
                        }
                    }
                    Spacer()
                    Button {
                        showFolderPicker = true
                    } label: {
                        Text(healthManager.hasExportFolder ? "Change" : "Set Folder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FormaColors.teal)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(FormaColors.teal.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var formatCard: some View {
        FormaCard {
            VStack(alignment: .leading, spacing: 12) {
                FormaSectionHeader(title: "Export Format")

                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var lastExportCard: some View {
        FormaCard {
            VStack(alignment: .leading, spacing: 12) {
                FormaSectionHeader(title: "Last Export")

                if let date = healthManager.lastExportDate {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(FormaColors.subtext)
                        Text("\(date, style: .relative) ago")
                        Spacer()
                        Text(date, format: .dateTime.day().month().year())
                            .font(FormaType.caption())
                            .foregroundStyle(FormaColors.subtext)
                    }
                    .font(FormaType.cardTitle())
                    .foregroundStyle(FormaColors.textPrimary)
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(FormaColors.subtext)
                        Text("No export yet")
                            .foregroundStyle(FormaColors.subtext)
                    }
                    .font(FormaType.cardTitle())
                }

                if let error = healthManager.exportError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FormaColors.red)
                        Text(error)
                            .font(FormaType.caption())
                            .foregroundStyle(FormaColors.red)
                    }
                }
            }
        }
    }

    private var exportButton: some View {
        Button {
            triggerExport()
        } label: {
            HStack(spacing: 10) {
                if isExporting {
                    ProgressView()
                        .tint(FormaColors.background)
                    Text("Exporting…")
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text("Export Now")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(FormaColors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isExporting || !healthManager.hasExportFolder
                    ? FormaColors.muted
                    : FormaColors.teal
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isExporting || !healthManager.hasExportFolder)
    }

    private var infoFooter: some View {
        Text("Exports run automatically every night at midnight.\nEnsure Background App Refresh is enabled in Settings.")
            .font(FormaType.caption())
            .foregroundStyle(FormaColors.subtext)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var successToast: some View {
        if showSuccess {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FormaColors.green)
                Text("Export complete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FormaColors.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(FormaColors.card)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func triggerExport() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            await healthManager.performExport(format: exportFormat)
            isExporting = false
            if healthManager.exportError == nil {
                withAnimation { showSuccess = true }
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { showSuccess = false }
            }
        }
    }
}
