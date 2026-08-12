//
//  RideScheduleView.swift
//  SpinMin
//
//  Views for ride scheduling and preparation
//

import SwiftUI
import SwiftData

// MARK: - Main Schedule View

struct RideScheduleView: View {
    @Query(sort: \ScheduledRide.scheduledDate, order: .forward) private var allRides: [ScheduledRide]
    @Query private var bikes: [BikeConfiguration]
    @Query private var routes: [Route]
    @Query(filter: #Predicate<GearItem> { $0.retirementDate == nil }) private var activeGear: [GearItem]
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("trainingCalendarFeedURL") private var calendarFeedURL = ""
    @AppStorage("trainingCalendarLastSync") private var lastSyncTimestamp = 0.0
    
    @State private var showingAddRide = false
    @State private var showingCalendarSettings = false
    @State private var selectedRide: ScheduledRide?
    @State private var rideToComplete: ScheduledRide?
    @State private var isSyncing = false
    @State private var syncErrorMessage: String?
    
    var upcomingRides: [ScheduledRide] {
        allRides.filter { $0.isUpcoming && !$0.isCompleted }
    }
    
    var todayRides: [ScheduledRide] {
        upcomingRides.filter { $0.isToday }
    }
    
    var ridesNeedingPrep: [ScheduledRide] {
        upcomingRides.filter { $0.needsPreparation }
    }
    
    /// Past rides never completed (last 7 days) awaiting manual completion
    var ridesAwaitingCompletion: [ScheduledRide] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allRides.filter {
            !$0.isCompleted && $0.scheduledDate < Date() && $0.scheduledDate > weekAgo
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Past rides awaiting completion
                    if !ridesAwaitingCompletion.isEmpty {
                        awaitingCompletionSection
                    }
                    
                    // Today's rides
                    if !todayRides.isEmpty {
                        todaySection
                    }
                    
                    // Rides needing preparation
                    if !ridesNeedingPrep.isEmpty {
                        needsPrepSection
                    }
                    
                    // Upcoming rides
                    if !upcomingRides.isEmpty {
                        upcomingSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Ride Schedule")
            .refreshable {
                await syncCalendarAndWeather()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if calendarFeedURL.trimmingCharacters(in: .whitespaces).isEmpty {
                            showingCalendarSettings = true
                        } else {
                            Task { await syncCalendarAndWeather() }
                        }
                    } label: {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isSyncing)
                    .contextMenu {
                        Button {
                            showingCalendarSettings = true
                        } label: {
                            Label("Calendar Settings", systemImage: "gearshape")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddRide = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        RoutesView()
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .alert("Sync Failed", isPresented: .init(
                get: { syncErrorMessage != nil },
                set: { if !$0 { syncErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
                Button("Settings") { showingCalendarSettings = true }
            } message: {
                Text(syncErrorMessage ?? "")
            }
            .sheet(isPresented: $showingAddRide) {
                AddRideView()
            }
            .sheet(isPresented: $showingCalendarSettings) {
                CalendarSyncSettingsView()
            }
            .sheet(item: $rideToComplete) { ride in
                CompleteRideView(ride: ride)
            }
            .sheet(item: $selectedRide) { ride in
                PreRidePreparationView(
                    ride: ride,
                    bikes: bikes,
                    routes: routes,
                    allGear: activeGear
                )
            }
        }
    }
    
    private var awaitingCompletionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Awaiting Completion")
                .h3()
            
            ForEach(ridesAwaitingCompletion) { ride in
                Button {
                    rideToComplete = ride
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(ride.name)
                                .bodyMedium()
                                .foregroundStyle(.primary)
                            Text(ride.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Complete")
                            .bodySmall()
                            .foregroundAccent()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Sync
    
    private func syncCalendarAndWeather() async {
        isSyncing = true
        defer { isSyncing = false }
        
        // 1. Pull scheduled workouts from the connected calendar feed
        let feedURL = calendarFeedURL.trimmingCharacters(in: .whitespaces)
        if !feedURL.isEmpty {
            do {
                _ = try await TrainingCalendarSyncService.sync(
                    feedURLString: feedURL,
                    context: modelContext
                )
                lastSyncTimestamp = Date().timeIntervalSince1970
            } catch {
                syncErrorMessage = error.localizedDescription
            }
        }
        
        // 2. Refresh weather forecasts for upcoming rides (best effort)
        let location = await LocationProvider.shared.currentLocation()
        await WeatherForecastService.refreshForecasts(
            for: upcomingRides,
            fallbackLocation: location
        )
        
        // 3. Reschedule notifications against the fresh data
        await NotificationService.refreshAll(context: modelContext)
    }
    
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Today")
                .h3()
            
            ForEach(todayRides) { ride in
                RideCard(ride: ride) {
                    selectedRide = ride
                }
            }
        }
    }
    
    private var needsPrepSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Needs Preparation")
                .h3()
            
            ForEach(ridesNeedingPrep) { ride in
                RideCard(ride: ride, showPrepBadge: true) {
                    selectedRide = ride
                }
            }
        }
    }
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Upcoming")
                .h3()
            
            ForEach(upcomingRides.filter { !$0.isToday }) { ride in
                RideCard(ride: ride) {
                    selectedRide = ride
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundAccent()
            
            Text("No Upcoming Rides")
                .h3()
            
            Text("Add your first ride or sync with TrainingPeaks/Garmin")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddRide = true
            } label: {
                Text("Add Ride")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }
}

// MARK: - Ride Card

struct RideCard: View {
    let ride: ScheduledRide
    var showPrepBadge: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon & time
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: ride.rideType.icon)
                        .font(.title2)
                        .foregroundAccent()
                    
                    Text(ride.scheduledDate, style: .time)
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(ride.name)
                            .bodyLarge()
                        
                        Spacer()
                        
                        if showPrepBadge {
                            Label("Prep", systemImage: "exclamationmark.circle.fill")
                                .captionSmall()
                                .foregroundStyle(.orange)
                        }
                        
                        if ride.isPrepared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    
                    HStack {
                        Text(ride.rideType.displayName)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        
                        Text("   ")
                            .captionMedium()
                        
                        Text(formatDuration(ride.duration))
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        
                        if let distance = ride.distance {
                            Text("   ")
                                .captionMedium()
                            Text(String(format: "%.0f km", distance))
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let bike = ride.selectedBike ?? ride.recommendedBike {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "bicycle")
                                .font(.caption)
                            Text(bike.name)
                                .captionSmall()
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Add Ride View

struct AddRideView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var scheduledDate = Date().addingTimeInterval(3600 * 24)  // Tomorrow
    @State private var duration: TimeInterval = 3600  // 1 hour
    @State private var distance: Double?
    @State private var rideType: RideType = .training
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Ride Details") {
                    TextField("Ride name", text: $name)
                    
                    DatePicker("Date & Time", selection: $scheduledDate)
                    
                    Picker("Type", selection: $rideType) {
                        ForEach(RideType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                Section("Duration & Distance") {
                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("1.5 hours").tag(TimeInterval(5400))
                        Text("2 hours").tag(TimeInterval(7200))
                        Text("3 hours").tag(TimeInterval(10800))
                        Text("4 hours").tag(TimeInterval(14400))
                        Text("5+ hours").tag(TimeInterval(18000))
                    }
                    
                    HStack {
                        Text("Distance (km)")
                        Spacer()
                        TextField("Optional", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveRide()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveRide() {
        let ride = ScheduledRide(
            name: name,
            scheduledDate: scheduledDate,
            duration: duration,
            rideType: rideType,
            distance: distance,
            notes: notes
        )
        
        modelContext.insert(ride)
        dismiss()
    }
}

// MARK: - Pre-Ride Preparation View

struct PreRidePreparationView: View {
    let ride: ScheduledRide
    let bikes: [BikeConfiguration]
    let routes: [Route]
    let allGear: [GearItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var preparation: PreRidePreparation?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let prep = preparation {
                        // Header
                        prepHeader(prep)
                        
                        // Recommended bike & route
                        recommendationsSection(prep)
                        
                        // Weather alert
                        if let alert = prep.weatherAlert {
                            weatherAlertCard(alert)
                        }
                        
                        // Weather-based clothing recommendations
                        if let temp = ride.temperature, let precip = ride.precipitationChance {
                            weatherClothingSection(temperature: temp, precipitation: precip, duration: ride.duration, intensity: ride.rideType.intensityLevel)
                        }
                        
                        // Bike checks
                        checksSection(title: "Bike Checks", checks: prep.bikeChecks)
                        
                        // Gear checks
                        gearChecksSection(prep)
                        
                        // Actions
                        if !prep.isReadyToRide {
                            Button {
                                markPrepared()
                            } label: {
                                Text("Mark as Prepared")
                            }
                            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                            .disabled(!prep.isReadyToRide)
                        } else {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Ready to ride!")
                                    .h3()
                            }
                            .padding(DesignSystem.Spacing.md)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Ride Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPreparation()
            }
        }
    }
    
    private func prepHeader(_ prep: PreRidePreparation) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: ride.rideType.icon)
                    .font(.largeTitle)
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(ride.name)
                        .h2()
                    Text(ride.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .bodyMedium()
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Progress bar
            ProgressView(value: prep.completionPercentage, total: 100)
                .tint(.green)
            
            Text("\(Int(prep.completionPercentage))% Ready")
                .captionMedium()
                .foregroundStyle(.secondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func recommendationsSection(_ prep: PreRidePreparation) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recommendations")
                .h3()
            
            if let bike = prep.recommendedBike {
                HStack {
                    Image(systemName: "bicycle")
                        .foregroundAccent()
                    Text(bike.name)
                        .bodyLarge()
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color(.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            if let route = prep.recommendedRoute {
                HStack {
                    Image(systemName: "map")
                        .foregroundAccent()
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(route.name)
                            .bodyLarge()
                        Text(String(format: "%.0f km", route.distance))
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color(.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private func weatherAlertCard(_ alert: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            Text(alert)
                .bodyMedium()
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func weatherClothingSection(temperature: Double, precipitation: Double, duration: TimeInterval, intensity: Int) -> some View {
        let recommendations = WeatherService.recommendClothing(
            temperature: temperature,
            precipitationChance: precipitation,
            rideDuration: duration
        )
        let hydration = WeatherService.recommendHydration(
            temperature: temperature,
            rideDuration: duration,
            rideIntensity: intensity
        )
        let tempCategory = WeatherService.TemperatureCategory(celsius: temperature)
        let precipLevel = WeatherService.PrecipitationLevel(probability: precipitation)
        
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Weather Gear")
                    .h3()
                Spacer()
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(tempCategory.emoji)
                    Text(String(format: "%.0f°C", temperature))
                        .captionMedium()
                        .foregroundStyle(.secondary)
                    Text(precipLevel.emoji)
                    Text("\(Int(precipitation * 100))%")
                        .captionMedium()
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Jacket
                if let jacket = recommendations.jacket {
                    clothingItemRow(
                        name: jacket.name,
                        priority: jacket.priority,
                        reason: jacket.reason
                    )
                }
                
                // Gloves
                if let gloves = recommendations.gloves {
                    clothingItemRow(
                        name: gloves.name,
                        priority: gloves.priority,
                        reason: gloves.reason
                    )
                }
                
                // Leg covering
                if let legs = recommendations.legCovering {
                    clothingItemRow(
                        name: legs.name,
                        priority: legs.priority,
                        reason: legs.reason
                    )
                }
                
                // Base layer
                if let base = recommendations.baseLayer {
                    clothingItemRow(
                        name: base.name,
                        priority: base.priority,
                        reason: base.reason
                    )
                }
                
                // Accessories
                ForEach(recommendations.accessories, id: \.name) { accessory in
                    clothingItemRow(
                        name: accessory.name,
                        priority: accessory.priority,
                        reason: accessory.reason
                    )
                }
                
                // Hydration
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Hydration: \(hydration)")
                            .bodyMedium()
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color(.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private func clothingItemRow(name: String, priority: WeatherService.ClothingRecommendations.ClothingItem.Priority, reason: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: priorityIcon(for: priority))
                .foregroundStyle(priorityColor(for: priority))
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(name)
                        .bodyMedium()
                    Spacer()
                    Text(priority.displayName)
                        .captionSmall()
                        .foregroundStyle(priorityColor(for: priority))
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(priorityColor(for: priority).opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                }
                Text(reason)
                    .captionSmall()
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private func priorityIcon(for priority: WeatherService.ClothingRecommendations.ClothingItem.Priority) -> String {
        switch priority {
        case .essential: return "exclamationmark.circle.fill"
        case .recommended: return "checkmark.circle.fill"
        case .optional: return "circle"
        }
    }
    
    private func priorityColor(for priority: WeatherService.ClothingRecommendations.ClothingItem.Priority) -> Color {
        switch priority {
        case .essential: return .red
        case .recommended: return .orange
        case .optional: return .secondary.opacity(0.6)
        }
    }
    
    private func checksSection(title: String, checks: [PreRidePreparation.BikeCheck]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .h3()
            
            ForEach(checks, id: \.item) { check in
                HStack {
                    Image(systemName: check.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(check.isComplete ? .green : .secondary)
                    
                    Text(check.item)
                        .bodyMedium()
                    
                    Spacer()
                    
                    if check.priority == .critical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color(.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private func gearChecksSection(_ prep: PreRidePreparation) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Gear Checks")
                .h3()
            
            ForEach(prep.gearChecks, id: \.gear.id) { check in
                HStack {
                    Image(systemName: check.isReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(check.isReady ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(check.gear.displayName)
                            .bodyMedium()
                        
                        if let issue = check.issue {
                            Text(issue)
                                .captionSmall()
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Spacer()
                    
                    if check.priority == .critical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color(.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private func loadPreparation() {
        preparation = RidePreparationService.prepareForRide(
            ride,
            bikes: bikes,
            routes: routes,
            allGear: allGear
        )
    }
    
    private func markPrepared() {
        ride.markPrepared()
        dismiss()
    }
}
