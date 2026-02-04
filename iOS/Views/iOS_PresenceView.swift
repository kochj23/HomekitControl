//
//  iOS_PresenceView.swift
//  HomekitControl
//
//  Presence detection and geofencing for iOS
//  Created by Jordan Koch
//  Copyright 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import MapKit

struct iOS_PresenceView: View {
    @StateObject private var presenceService = PresenceService.shared
    @State private var showAddRegion = false
    @State private var showAddMember = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(presenceService.isHome ? "You're Home" : "Away")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("\(presenceService.membersAtHome.count) of \(presenceService.familyMembers.count) members home")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(presenceService.isHome ? ModernColors.accentGreen : ModernColors.orange)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: presenceService.isHome ? "house.fill" : "figure.walk")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                    }
                    .padding()
                }

                // Map
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Geofence Regions")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Map(coordinateRegion: $mapRegion, annotationItems: presenceService.regions) { region in
                            MapAnnotation(coordinate: region.coordinate) {
                                VStack {
                                    Circle()
                                        .fill(ModernColors.cyan.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundStyle(ModernColors.cyan)
                                        }
                                    Text(region.name)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }

                // Regions List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Regions")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddRegion = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    if presenceService.regions.isEmpty {
                        GlassCard {
                            HStack {
                                Image(systemName: "mappin.slash")
                                    .foregroundStyle(.secondary)
                                Text("No regions configured")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(presenceService.regions) { region in
                            NavigationLink(destination: RegionDetailView(region: region)) {
                                GlassCard {
                                    HStack {
                                        Circle()
                                            .fill(region.isEnabled ? ModernColors.accentGreen : .secondary)
                                            .frame(width: 12, height: 12)

                                        VStack(alignment: .leading) {
                                            Text(region.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text("\(Int(region.radius))m radius")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                }

                // Family Members
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Family Members")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            showAddMember = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ModernColors.cyan)
                        }
                    }

                    ForEach(presenceService.familyMembers) { member in
                        GlassCard {
                            HStack {
                                Circle()
                                    .fill(member.isHome ? ModernColors.accentGreen : ModernColors.orange)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(String(member.name.prefix(1)))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading) {
                                    Text(member.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(member.isHome ? "Home" : member.lastLocation ?? "Away")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let lastSeen = member.lastSeen {
                                    Text(lastSeen, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                        }
                    }
                }

                // Recent Events
                if !presenceService.recentEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(presenceService.recentEvents.prefix(5)) { event in
                            GlassCard {
                                HStack {
                                    Image(systemName: event.eventType == .arrived ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundStyle(event.eventType == .arrived ? ModernColors.accentGreen : ModernColors.orange)

                                    VStack(alignment: .leading) {
                                        Text("\(event.memberName) \(event.eventType.rawValue.lowercased())")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text(event.regionName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(event.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Presence")
        .onAppear {
            presenceService.requestAuthorization()
            if let location = presenceService.currentLocation {
                mapRegion.center = location.coordinate
            }
        }
        .sheet(isPresented: $showAddRegion) {
            AddRegionView()
        }
        .sheet(isPresented: $showAddMember) {
            AddMemberView()
        }
    }
}

struct RegionDetailView: View {
    let region: GeofenceRegion
    @StateObject private var presenceService = PresenceService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(ModernColors.cyan)

                        Text(region.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Radius: \(Int(region.radius))m")
                            .foregroundStyle(.secondary)

                        Toggle("Enabled", isOn: .constant(region.isEnabled))
                            .tint(ModernColors.cyan)
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Triggers")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("On Entry")
                            Spacer()
                            Image(systemName: region.triggerOnEntry ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(region.triggerOnEntry ? ModernColors.accentGreen : .secondary)
                        }
                        .foregroundStyle(.white)

                        HStack {
                            Image(systemName: "arrow.up.circle")
                            Text("On Exit")
                            Spacer()
                            Image(systemName: region.triggerOnExit ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(region.triggerOnExit ? ModernColors.accentGreen : .secondary)
                        }
                        .foregroundStyle(.white)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(LinearGradient.modernBackground.ignoresSafeArea())
        .navigationTitle("Region Details")
    }
}

struct AddRegionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presenceService = PresenceService.shared
    @State private var name = ""
    @State private var radius: Double = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Region Details") {
                    TextField("Name", text: $name)
                    Slider(value: $radius, in: 50...500, step: 10) {
                        Text("Radius: \(Int(radius))m")
                    }
                    Text("Radius: \(Int(radius)) meters")
                }
            }
            .navigationTitle("Add Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let region = GeofenceRegion(
                            name: name,
                            latitude: presenceService.currentLocation?.coordinate.latitude ?? 0,
                            longitude: presenceService.currentLocation?.coordinate.longitude ?? 0,
                            radius: radius
                        )
                        presenceService.addRegion(region)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presenceService = PresenceService.shared
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Member Details") {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let member = FamilyMember(name: name)
                        presenceService.addFamilyMember(member)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
