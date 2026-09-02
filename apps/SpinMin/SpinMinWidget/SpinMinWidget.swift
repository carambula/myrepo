//
//  SpinMinWidget.swift
//  SpinMinWidget
//
//  Home screen widget: today's ride and default-bike tire pressures.
//  Reads the App Group snapshot written by the main app.
//

import WidgetKit
import SwiftUI

@main
struct SpinMinWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpinMinWidget()
    }
}

// MARK: - Timeline

struct SpinMinEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SpinMinTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpinMinEntry {
        SpinMinEntry(date: Date(), snapshot: .placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SpinMinEntry) -> Void) {
        completion(SpinMinEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .placeholder))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpinMinEntry>) -> Void) {
        let entry = SpinMinEntry(date: Date(), snapshot: WidgetSnapshot.load())
        // Data only changes when the app writes a new snapshot (which
        // reloads timelines), so a slow hourly refresh is enough for
        // date rollover.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

extension WidgetSnapshot {
    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: Date(),
            bikes: [BikePressure(bikeName: "Road Bike", wheelsetName: "Race Wheels", frontPSI: 72, rearPSI: 75)],
            todayRide: UpcomingRide(name: "Endurance Ride", date: Date(), rideTypeName: "Endurance", distanceKm: 60, isPrepared: false),
            nextRide: nil
        )
    }
}

// MARK: - Widget

struct SpinMinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpinMinWidget", provider: SpinMinTimelineProvider()) { entry in
            SpinMinWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ride & Pressures")
        .description("Today's ride and tire pressures for your bike.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct SpinMinWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpinMinEntry
    
    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium:
                mediumView(snapshot)
            default:
                smallView(snapshot)
            }
        } else {
            Text("Open SpinMin to set up your bikes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func smallView(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ride = snapshot.todayRide ?? snapshot.nextRide {
                rideHeader(ride)
                Divider()
            }
            
            if let bike = snapshot.bikes.first {
                pressureRow(bike)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private func mediumView(_ snapshot: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let ride = snapshot.todayRide {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    rideHeader(ride)
                } else if let ride = snapshot.nextRide {
                    Text("Next Ride")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    rideHeader(ride)
                } else {
                    Text("No rides scheduled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.bikes.prefix(2), id: \.bikeName) { bike in
                    pressureRow(bike)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func rideHeader(_ ride: WidgetSnapshot.UpcomingRide) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ride.name)
                .font(.headline)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Text(ride.date, style: .time)
                if let distance = ride.distanceKm {
                    Text("\(Int(distance)) km")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !ride.isPrepared {
                Label("Prep needed", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func pressureRow(_ bike: WidgetSnapshot.BikePressure) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bike.bikeName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Label(String(format: "%.0f", bike.frontPSI), systemImage: "arrow.up.circle")
                Label(String(format: "%.0f", bike.rearPSI), systemImage: "arrow.down.circle")
                Text("psi")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .monospacedDigit()
        }
    }
}
