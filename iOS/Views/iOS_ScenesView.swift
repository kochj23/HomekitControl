//
//  iOS_ScenesView.swift
//  HomekitControl
//
//  iOS scene list and repair view
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
#if canImport(HomeKit)
import HomeKit
#endif

struct iOS_ScenesView: View {
    @StateObject private var homeKitService = HomeKitService.shared
    @StateObject private var sceneAnalyzer = SceneAnalyzerService.shared
    @State private var searchText = ""
    @State private var showingAnalysis = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphicBackground()

                if homeKitService.isLoading {
                    ProgressView("Loading scenes...")
                        .foregroundStyle(.white)
                } else if homeKitService.scenes.isEmpty {
                    ContentUnavailableView {
                        Label("No Scenes", systemImage: "sparkles")
                    } description: {
                        Text("No HomeKit scenes found in your home.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Analysis summary if available
                            if !sceneAnalyzer.analysisResults.isEmpty {
                                analysisSummaryCard
                            }

                            // Scenes list
                            ForEach(filteredScenes, id: \.uniqueIdentifier) { scene in
                                SceneRow(scene: scene, analysisResult: analysisResult(for: scene)) {
                                    Task { try? await homeKitService.executeScene(scene) }
                                } onRepair: {
                                    Task { await repairScene(scene) }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scenes")
            .searchable(text: $searchText, prompt: "Search scenes")
            .refreshable {
                await homeKitService.refreshAll()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Analyze") {
                        Task { await analyzeScenes() }
                    }
                    .disabled(sceneAnalyzer.isAnalyzing)
                }
            }
            .overlay {
                if !homeKitService.statusMessage.isEmpty {
                    VStack {
                        Spacer()
                        Text(homeKitService.statusMessage)
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    // MARK: - Analysis Summary

    private var analysisSummaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(ModernColors.accent)
                    Text("Scene Analysis")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }

                let healthyCount = sceneAnalyzer.analysisResults.filter { $0.healthStatus == .healthy }.count
                let issueCount = sceneAnalyzer.analysisResults.filter { $0.hasIssues }.count

                HStack(spacing: 24) {
                    VStack {
                        Text("\(healthyCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(ModernColors.statusLow)
                        Text("Healthy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(issueCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(issueCount > 0 ? ModernColors.statusCritical : .secondary)
                        Text("Issues")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Filtering

    private var filteredScenes: [HMActionSet] {
        guard !searchText.isEmpty else { return homeKitService.scenes }
        return homeKitService.scenes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func analysisResult(for scene: HMActionSet) -> SceneAnalysisResult? {
        sceneAnalyzer.analysisResults.first { $0.sceneId == scene.uniqueIdentifier }
    }

    // MARK: - Actions

    private func analyzeScenes() async {
        guard let home = homeKitService.currentHome else { return }
        _ = await sceneAnalyzer.analyzeAllScenes(in: home)
    }

    private func repairScene(_ scene: HMActionSet) async {
        #if os(iOS)
        guard let home = homeKitService.currentHome else { return }
        _ = try? await sceneAnalyzer.repairScene(scene, in: home)
        await analyzeScenes()
        #endif
    }
}

// MARK: - Scene Row

struct SceneRow: View {
    let scene: HMActionSet
    let analysisResult: SceneAnalysisResult?
    let onExecute: () -> Void
    let onRepair: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(healthColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: sceneIcon)
                        .font(.title2)
                        .foregroundStyle(healthColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let result = analysisResult {
                        Text("\(result.actionCount) actions • \(result.accessoryNames.count) devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if result.hasIssues {
                            Text("\(result.issueCount) unreachable")
                                .font(.caption)
                                .foregroundStyle(ModernColors.statusCritical)
                        }
                    } else {
                        Text("\(scene.actions.count) actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: 8) {
                    Button {
                        onExecute()
                    } label: {
                        Image(systemName: "play.fill")
                            .padding(10)
                            .background(ModernColors.accent)
                            .clipShape(Circle())
                    }

                    if analysisResult?.hasIssues == true {
                        Button {
                            onRepair()
                        } label: {
                            Image(systemName: "wrench.fill")
                                .font(.caption)
                                .padding(6)
                                .background(ModernColors.statusMedium)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var healthColor: Color {
        analysisResult?.healthStatus.color ?? ModernColors.textTertiary
    }

    private var sceneIcon: String {
        let name = scene.name.lowercased()
        if name.contains("morning") || name.contains("wake") { return "sun.max.fill" }
        if name.contains("night") || name.contains("sleep") || name.contains("bed") { return "moon.stars.fill" }
        if name.contains("away") || name.contains("leave") { return "figure.walk" }
        if name.contains("home") || name.contains("arrive") { return "house.fill" }
        if name.contains("movie") || name.contains("tv") { return "tv.fill" }
        if name.contains("dinner") || name.contains("eat") { return "fork.knife" }
        return "sparkles"
    }
}

#Preview {
    iOS_ScenesView()
}
