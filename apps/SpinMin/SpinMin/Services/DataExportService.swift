//
//  DataExportService.swift
//  SpinMin
//
//  CSV and JSON export of maintenance records, tire history, and
//  ride logs.
//

import Foundation
import SwiftData

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"
    
    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

struct DataExportService {
    
    // MARK: - Export Entry Points
    
    @MainActor
    static func exportMaintenanceRecords(context: ModelContext, format: ExportFormat) throws -> URL {
        let records = try context.fetch(FetchDescriptor<MaintenanceRecord>(
            sortBy: [SortDescriptor(\.maintenanceDate, order: .reverse)]
        ))
        
        let rows = records.map { record in
            ExportRow(fields: [
                ("date", isoDate(record.maintenanceDate)),
                ("bike", record.bikeConfiguration?.name ?? ""),
                ("type", record.type.displayName),
                ("category", record.type.category.displayName),
                ("component_brand", record.componentBrand ?? ""),
                ("component_model", record.componentModel ?? ""),
                ("odometer_km", number(record.bikeOdometerKm)),
                ("cost", record.cost.map { number($0) } ?? ""),
                ("performed_by", record.performedBy ?? ""),
                ("is_replacement", record.isReplacement ? "true" : "false"),
                ("component_lifespan_km", record.componentLifespanKm.map { number($0) } ?? ""),
                ("notes", record.notes),
            ])
        }
        return try write(rows, name: "spinmin-maintenance", format: format)
    }
    
    @MainActor
    static func exportTireHistory(context: ModelContext, format: ExportFormat) throws -> URL {
        let history = try context.fetch(FetchDescriptor<TireHistory>(
            sortBy: [SortDescriptor(\.removeDate, order: .reverse)]
        ))
        
        let rows = history.map { tire in
            ExportRow(fields: [
                ("brand", tire.tireBrand ?? ""),
                ("model", tire.tireModel ?? ""),
                ("position", tire.position),
                ("wheelset", tire.wheelset?.name ?? ""),
                ("install_date", isoDate(tire.installDate)),
                ("removal_date", isoDate(tire.removeDate)),
                ("total_km", number(tire.totalMileageKm)),
                ("duration_days", "\(tire.durationDays)"),
                ("removal_reason", tire.removalReason),
                ("punctures", "\(tire.finalPunctureCount)"),
                ("condition", tire.conditionAtRemoval),
            ])
        }
        return try write(rows, name: "spinmin-tire-history", format: format)
    }
    
    @MainActor
    static func exportRideLogs(context: ModelContext, format: ExportFormat) throws -> URL {
        let rides = try context.fetch(FetchDescriptor<RideLog>(
            sortBy: [SortDescriptor(\.rideDate, order: .reverse)]
        ))
        
        let rows = rides.map { ride in
            ExportRow(fields: [
                ("date", isoDate(ride.rideDate)),
                ("name", ride.rideName),
                ("distance_km", number(ride.distanceKm)),
                ("bike", ride.bikeConfiguration?.name ?? ""),
                ("wheelset", ride.wheelset?.name ?? ""),
                ("terrain", ride.terrainType ?? ""),
                ("strava_activity_id", ride.stravaActivityId ?? ""),
                ("notes", ride.notes),
            ])
        }
        return try write(rows, name: "spinmin-rides", format: format)
    }
    
    // MARK: - Row Model
    
    /// Ordered key/value pairs so CSV columns and JSON keys stay stable
    struct ExportRow {
        let fields: [(key: String, value: String)]
    }
    
    // MARK: - Serialization
    
    private static func write(_ rows: [ExportRow], name: String, format: ExportFormat) throws -> URL {
        let content: String
        switch format {
        case .csv: content = toCSV(rows)
        case .json: content = toJSON(rows)
        }
        
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        let fileName = "\(name)-\(stamp.string(from: Date())).\(format.fileExtension)"
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func toCSV(_ rows: [ExportRow]) -> String {
        guard let first = rows.first else { return "" }
        
        var lines = [first.fields.map { csvEscape($0.key) }.joined(separator: ",")]
        for row in rows {
            lines.append(row.fields.map { csvEscape($0.value) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
    
    static func toJSON(_ rows: [ExportRow]) -> String {
        let objects = rows.map { row in
            Dictionary(uniqueKeysWithValues: row.fields.map { ($0.key, $0.value) })
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: objects,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    /// RFC 4180: quote fields containing commas, quotes, or newlines
    static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
    
    // MARK: - Formatting
    
    private static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
