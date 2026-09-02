//
//  StravaSettingsView.swift
//  SpinMin
//
//  Connect Strava, map Strava bikes to local bikes, and sync rides
//

import SwiftUI
import SwiftData

struct StravaSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var auth = StravaAuthService.shared
    
    @Query private var bikes: [BikeConfiguration]
    @Query(
        filter: #Predicate<RideLog> { $0.stravaActivityId != nil && $0.bikeConfiguration == nil },
        sort: \RideLog.rideDate,
        order: .reverse
    ) private var unassignedRides: [RideLog]
    
    @AppStorage("stravaLastSync") private var lastSyncTimestamp = 0.0
    
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var stravaBikes: [StravaGear] = []
    @State private var isConnecting = false
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    
    var body: some View {
        Form {
            if !auth.isConnected {
                credentialsSection
                connectSection
                setupInstructionsSection
            } else {
                connectionSection
                syncSection
                bikeMappingSection
                if !unassignedRides.isEmpty {
                    unassignedRidesSection
                }
                disconnectSection
            }
        }
        .navigationTitle("Strava")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            clientId = auth.clientId ?? ""
            clientSecret = auth.clientSecret ?? ""
            if auth.isConnected {
                Task { await loadStravaBikes() }
            }
        }
    }
    
    // MARK: - Not Connected
    
    private var credentialsSection: some View {
        Section {
            TextField("Client ID", text: $clientId)
                .keyboardType(.numberPad)
            SecureField("Client Secret", text: $clientSecret)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("API Credentials")
        } footer: {
            Text("Stored securely in the keychain and only sent to Strava.")
        }
    }
    
    private var connectSection: some View {
        Section {
            Button {
                Task { await connect() }
            } label: {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .padding(.trailing, DesignSystem.Spacing.sm)
                        Text("Connecting…")
                    } else {
                        Image(systemName: "link")
                        Text("Connect Strava")
                    }
                }
            }
            .disabled(clientId.isEmpty || clientSecret.isEmpty || isConnecting)
            
            statusRow
        }
    }
    
    private var setupInstructionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                instructionStep(1, "Go to strava.com/settings/api and create an API application")
                instructionStep(2, "Set Authorization Callback Domain to: localhost")
                instructionStep(3, "Copy the Client ID and Client Secret into the fields above")
                instructionStep(4, "Tap Connect Strava and authorize the app")
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        } header: {
            Text("One-Time Setup")
        } footer: {
            Text("Strava requires each personal app to register its own API application. This takes about two minutes.")
        }
    }
    
    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Text("\(number).")
                .bodySmall()
                .foregroundStyle(.secondary)
            Text(text)
                .bodySmall()
        }
    }
    
    // MARK: - Connected
    
    private var connectionSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(auth.athleteName.isEmpty ? "Connected" : auth.athleteName)
                Spacer()
            }
        } header: {
            Text("Connection")
        }
    }
    
    private var syncSection: some View {
        Section {
            Button {
                Task { await syncNow() }
            } label: {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .padding(.trailing, DesignSystem.Spacing.sm)
                        Text("Syncing…")
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Rides Now")
                    }
                }
            }
            .disabled(isSyncing)
            
            statusRow
            
            if lastSyncTimestamp > 0 {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(Date(timeIntervalSince1970: lastSyncTimestamp).formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Ride Sync")
        } footer: {
            Text("New cycling activities become ride logs and update bike, tire, and component mileage. Same-day scheduled rides are marked completed automatically.")
        }
    }
    
    private var bikeMappingSection: some View {
        Section {
            if stravaBikes.isEmpty {
                Text("No bikes found on your Strava profile")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stravaBikes) { stravaBike in
                    bikeMappingRow(stravaBike)
                }
            }
        } header: {
            Text("Bike Matching")
        } footer: {
            Text("Rides are attributed to the matched bike's default wheelset. Bikes are matched automatically by name; adjust here if needed.")
        }
    }
    
    private func bikeMappingRow(_ stravaBike: StravaGear) -> some View {
        Picker(stravaBike.name, selection: mappingBinding(for: stravaBike)) {
            Text("Not linked").tag(nil as UUID?)
            ForEach(bikes) { bike in
                Text(bike.name).tag(bike.id as UUID?)
            }
        }
    }
    
    private func mappingBinding(for stravaBike: StravaGear) -> Binding<UUID?> {
        Binding<UUID?>(
            get: {
                bikes.first { $0.stravaGearId == stravaBike.id }?.id
            },
            set: { newBikeId in
                // Unlink any bike currently claiming this Strava gear
                for bike in bikes where bike.stravaGearId == stravaBike.id {
                    bike.stravaGearId = nil
                }
                if let newBikeId = newBikeId,
                   let bike = bikes.first(where: { $0.id == newBikeId }) {
                    bike.stravaGearId = stravaBike.id
                }
            }
        )
    }
    
    private var unassignedRidesSection: some View {
        Section {
            ForEach(unassignedRides) { ride in
                UnassignedRideRow(ride: ride, bikes: bikes)
            }
        } header: {
            Text("Rides Needing a Bike")
        } footer: {
            Text("These rides came from Strava with an unrecognized bike. Assign one to update its mileage.")
        }
    }
    
    private var disconnectSection: some View {
        Section {
            Button(role: .destructive) {
                auth.disconnect()
                stravaBikes = []
                statusMessage = nil
            } label: {
                Text("Disconnect Strava")
            }
        }
    }
    
    @ViewBuilder
    private var statusRow: some View {
        if let message = statusMessage {
            HStack {
                Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(statusIsError ? .red : .green)
                Text(message)
                    .bodySmall()
            }
        }
    }
    
    // MARK: - Actions
    
    private func connect() async {
        isConnecting = true
        statusMessage = nil
        defer { isConnecting = false }
        
        auth.clientId = clientId.trimmingCharacters(in: .whitespaces)
        auth.clientSecret = clientSecret.trimmingCharacters(in: .whitespaces)
        
        do {
            try await auth.connect()
            statusIsError = false
            statusMessage = "Connected"
            await loadStravaBikes()
            await syncNow()
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
    
    private func loadStravaBikes() async {
        do {
            let token = try await auth.validAccessToken()
            let athlete = try await StravaAPI.fetchAthlete(accessToken: token)
            stravaBikes = athlete.bikes ?? []
            StravaSyncService.autoMatchBikes(stravaBikes: stravaBikes, localBikes: bikes)
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
    
    private func syncNow() async {
        isSyncing = true
        statusMessage = nil
        defer { isSyncing = false }
        
        do {
            let result = try await StravaSyncService.sync(context: modelContext)
            statusIsError = false
            statusMessage = result.summary
            lastSyncTimestamp = Date().timeIntervalSince1970
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Unassigned Ride Row

private struct UnassignedRideRow: View {
    let ride: RideLog
    let bikes: [BikeConfiguration]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(ride.rideName)
                .bodyMedium()
            Text("\(String(format: "%.1f", ride.distanceKm)) km   \(ride.rideDate.formatted(date: .abbreviated, time: .omitted))")
                .captionMedium()
                .foregroundStyle(.secondary)
            
            Menu {
                ForEach(bikes) { bike in
                    Button(bike.name) {
                        RideLogger.assignBike(ride, to: bike)
                    }
                }
            } label: {
                Label("Assign Bike", systemImage: "bicycle")
                    .bodySmall()
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
