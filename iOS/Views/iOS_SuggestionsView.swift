//
//  iOS_SuggestionsView.swift
//  HomekitControl
//
//  ML-based scene suggestions for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct iOS_SuggestionsView: View {
    @StateObject private var suggestionService = SceneSuggestionService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Learning Status
                GlassCard {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Learning")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(suggestionService.isLearning ? "Analyzing your patterns" : "Learning paused")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $suggestionService.isLearning)
                                .tint(ModernColors.cyan)
                        }

                        // Progress bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Learning Progress")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(suggestionService.learningProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(ModernColors.cyan)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(ModernColors.glassBackground)
                                        .frame(height: 8)

                                    Capsule()
                                        .fill(ModernColors.cyan)
                                        .frame(width: geo.size.width * suggestionService.learningProgress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding()
                }

                // Suggestions
                if suggestionService.suggestions.isEmpty {
                    GlassCard {
                        VStack(spacing: 16) {
                            Image(systemName: "brain")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)

                            Text("No Suggestions Yet")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Keep using your devices normally. We'll suggest automations based on your patterns.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Suggestions")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                suggestionService.clearAllSuggestions()
                            } label: {
                                Text("Clear All")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(suggestionService.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                        }
                    }
                }

                // Patterns Found
                if !suggestionService.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Patterns Detected")
                            .font(.headline)
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(Dictionary(grouping: suggestionService.patterns) { $0.deviceName }.prefix(6)), id: \.key) { deviceName, patterns in
                                GlassCard {
                                    VStack(spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(ModernColors.yellow)

                                        Text(deviceName)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        Text("\(patterns.count) patterns")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Text("Minimum Confidence")
                            Spacer()
                            Text("\(Int(suggestionService.minimumConfidence * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $suggestionService.minimumConfidence, in: 0.3...0.9, step: 0.1)
                            .tint(ModernColors.cyan)

                        Text("Higher confidence means fewer but more accurate suggestions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Stats
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            VStack {
                                Text("\(suggestionService.usageLogs.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.cyan)
                                Text("Events")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(suggestionService.patterns.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.purple)
                                Text("Patterns")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            VStack {
                                Text("\(suggestionService.suggestions.count)")
                                    .font(.title2.bold())
                                    .foregroundStyle(ModernColors.orange)
                                Text("Suggestions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("AI Suggestions")
    }
}

struct SuggestionCard: View {
    let suggestion: SceneSuggestion
    @StateObject private var suggestionService = SceneSuggestionService.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(ModernColors.yellow)

                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(confidenceColor.opacity(0.3))
                        .clipShape(Capsule())
                        .foregroundStyle(confidenceColor)
                }

                Text(suggestion.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !suggestion.suggestedActions.isEmpty {
                    HStack {
                        ForEach(suggestion.suggestedActions.prefix(3)) { action in
                            Text(action.deviceName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ModernColors.glassBackground)
                                .clipShape(Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        suggestionService.acceptSuggestion(suggestion)
                    } label: {
                        Text("Create Automation")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(ModernColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        suggestionService.dismissSuggestion(suggestion)
                    } label: {
                        Text("Dismiss")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(ModernColors.glassBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
    }

    private var confidenceColor: Color {
        if suggestion.confidence >= 0.8 { return ModernColors.accentGreen }
        if suggestion.confidence >= 0.6 { return ModernColors.yellow }
        return ModernColors.orange
    }
}
