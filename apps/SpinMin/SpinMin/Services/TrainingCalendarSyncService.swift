//
//  TrainingCalendarSyncService.swift
//  SpinMin
//
//  Syncs scheduled workouts from training platform calendar feeds (ICS).
//
//  TrainingPeaks, intervals.icu, TrainerRoad, and Final Surge all publish
//  per-user iCalendar (ICS) feed URLs, which makes this work today without
//  partner API approval. TrainingPeaks: Settings → Calendar Sync → copy URL.
//

import Foundation
import SwiftData

// MARK: - Parsed ICS Event

struct ICSEvent {
    let uid: String
    let summary: String
    let eventDescription: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
    
    var duration: TimeInterval {
        guard let end = end else { return 3600 }
        let interval = end.timeIntervalSince(start)
        return interval > 0 ? interval : 3600
    }
}

// MARK: - Sync Errors

enum CalendarSyncError: LocalizedError {
    case invalidURL
    case networkError(String)
    case emptyFeed
    case parseFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The calendar URL is not valid. Copy the full webcal or https link from your training platform."
        case .networkError(let detail):
            return "Could not download the calendar feed: \(detail)"
        case .emptyFeed:
            return "The feed downloaded but contained no calendar data. Check that the URL is a calendar (ICS) link."
        case .parseFailure:
            return "The calendar feed could not be read."
        }
    }
}

// MARK: - Sync Result

struct CalendarSyncResult {
    var imported: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
    
    var summary: String {
        var parts: [String] = []
        if imported > 0 { parts.append("\(imported) new") }
        if updated > 0 { parts.append("\(updated) updated") }
        if parts.isEmpty { return "Already up to date" }
        return "Synced " + parts.joined(separator: ", ")
    }
}

// MARK: - Sync Service

struct TrainingCalendarSyncService {
    
    /// How far ahead to import scheduled workouts
    static let syncWindowDays = 60
    
    // MARK: - Public API
    
    /// Downloads an ICS feed and merges its events into ScheduledRide records.
    @MainActor
    static func sync(feedURLString: String, context: ModelContext) async throws -> CalendarSyncResult {
        let icsText = try await fetchFeed(urlString: feedURLString)
        let events = parseICS(icsText)
        return try mergeEvents(events, context: context)
    }
    
    // MARK: - Fetch
    
    static func fetchFeed(urlString: String) async throws -> String {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Calendar apps use webcal:// but it is plain https underneath
        if normalized.lowercased().hasPrefix("webcal://") {
            normalized = "https://" + normalized.dropFirst("webcal://".count)
        }
        
        guard let url = URL(string: normalized), url.scheme?.hasPrefix("http") == true else {
            throw CalendarSyncError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw CalendarSyncError.networkError("Server returned status \(http.statusCode)")
            }
            guard let text = String(data: data, encoding: .utf8), text.contains("BEGIN:VCALENDAR") else {
                throw CalendarSyncError.emptyFeed
            }
            return text
        } catch let error as CalendarSyncError {
            throw error
        } catch {
            throw CalendarSyncError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - ICS Parsing
    
    /// Parses VEVENT blocks from iCalendar text (RFC 5545).
    static func parseICS(_ text: String) -> [ICSEvent] {
        let unfolded = unfoldLines(text)
        var events: [ICSEvent] = []
        
        var inEvent = false
        var fields: [String: (params: [String: String], value: String)] = [:]
        
        for line in unfolded {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                fields = [:]
                continue
            }
            if line == "END:VEVENT" {
                inEvent = false
                if let event = buildEvent(from: fields) {
                    events.append(event)
                }
                continue
            }
            guard inEvent else { continue }
            
            // Split "NAME;PARAM=X;PARAM2=Y:value"
            guard let colonIndex = findPropertyColon(in: line) else { continue }
            let head = String(line[line.startIndex..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...])
            
            let headParts = head.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
            guard let name = headParts.first?.uppercased() else { continue }
            
            var params: [String: String] = [:]
            for param in headParts.dropFirst() {
                let kv = param.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 {
                    params[kv[0].uppercased()] = kv[1]
                }
            }
            fields[name] = (params, value)
        }
        
        return events
    }
    
    /// ICS wraps long lines; continuation lines start with a space or tab.
    private static func unfoldLines(_ text: String) -> [String] {
        var result: [String] = []
        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix(" ") || line.hasPrefix("\t"), !result.isEmpty {
                result[result.count - 1] += String(line.dropFirst())
            } else {
                result.append(line)
            }
        }
        return result
    }
    
    /// The property colon is the first colon not inside a quoted parameter value.
    private static func findPropertyColon(in line: String) -> String.Index? {
        var inQuotes = false
        for index in line.indices {
            let char = line[index]
            if char == "\"" { inQuotes.toggle() }
            if char == ":" && !inQuotes { return index }
        }
        return nil
    }
    
    private static func buildEvent(from fields: [String: (params: [String: String], value: String)]) -> ICSEvent? {
        guard let uidField = fields["UID"],
              let dtstartField = fields["DTSTART"] else {
            return nil
        }
        
        let isAllDay = dtstartField.params["VALUE"] == "DATE" || dtstartField.value.count == 8
        guard let start = parseICSDate(dtstartField.value, params: dtstartField.params) else {
            return nil
        }
        
        var end: Date?
        if let dtendField = fields["DTEND"] {
            end = parseICSDate(dtendField.value, params: dtendField.params)
        } else if let durationField = fields["DURATION"] {
            if let seconds = parseICSDuration(durationField.value) {
                end = start.addingTimeInterval(seconds)
            }
        }
        
        let summary = unescapeICSText(fields["SUMMARY"]?.value ?? "Workout")
        let description = unescapeICSText(fields["DESCRIPTION"]?.value ?? "")
        
        return ICSEvent(
            uid: uidField.value,
            summary: summary,
            eventDescription: description,
            start: start,
            end: end,
            isAllDay: isAllDay
        )
    }
    
    /// Handles the three ICS date shapes: 20260812 (all-day),
    /// 20260812T070000Z (UTC), 20260812T070000 (floating/TZID local).
    static func parseICSDate(_ value: String, params: [String: String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if value.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.date(from: value)
        }
        
        if value.contains("T") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            if let tzid = params["TZID"], let tz = TimeZone(identifier: tzid) {
                formatter.timeZone = tz
            } else {
                formatter.timeZone = .current
            }
            return formatter.date(from: value)
        }
        
        // All-day event: treat as 8 AM local (a sensible default ride start)
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = .current
        guard let day = formatter.date(from: value) else { return nil }
        return Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: day)
    }
    
    /// Parses ISO 8601 durations like PT1H30M or P1DT2H.
    static func parseICSDuration(_ value: String) -> TimeInterval? {
        var seconds: Double = 0
        var number = ""
        var inTime = false
        
        for char in value.uppercased() {
            switch char {
            case "P", "+": continue
            case "T": inTime = true
            case "0"..."9": number.append(char)
            case "D":
                seconds += (Double(number) ?? 0) * 86400
                number = ""
            case "H":
                seconds += (Double(number) ?? 0) * 3600
                number = ""
            case "M":
                seconds += (Double(number) ?? 0) * (inTime ? 60 : 2_592_000)
                number = ""
            case "S":
                seconds += Double(number) ?? 0
                number = ""
            case "W":
                seconds += (Double(number) ?? 0) * 604800
                number = ""
            default: return nil
            }
        }
        return seconds > 0 ? seconds : nil
    }
    
    private static func unescapeICSText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
    
    // MARK: - Ride Type Inference
    
    /// Guesses the ride type from workout title and description keywords.
    /// The title is checked first: descriptions often mention other zones
    /// in passing ("2x20 at FTP with 5min recovery").
    static func inferRideType(title: String, description: String) -> RideType {
        if let fromTitle = matchRideType(in: title) {
            return fromTitle
        }
        if let fromDescription = matchRideType(in: description) {
            return fromDescription
        }
        return .training
    }
    
    private static func matchRideType(in rawText: String) -> RideType? {
        let text = rawText.lowercased()
        
        let keywordMap: [(keywords: [String], type: RideType)] = [
            (["race", "crit", "criterium", "gran fondo", "event"], .race),
            (["recovery", "easy spin", "active recovery", "z1"], .recovery),
            (["vo2", "vo2max", "5x3", "3x3"], .vo2max),
            (["sprint", "neuromuscular", "anaerobic"], .sprint),
            (["threshold", "ftp", "sweet spot", "sweetspot", "2x20"], .threshold),
            (["interval", "repeats"], .interval),
            (["tempo", "z3"], .tempo),
            (["long ride", "century"], .longRide),
            (["endurance", "z2", "base"], .endurance),
            (["group", "club ride", "shop ride"], .groupRide),
            (["commute"], .commute),
        ]
        
        for entry in keywordMap {
            if entry.keywords.contains(where: { text.contains($0) }) {
                return entry.type
            }
        }
        return nil
    }
    
    /// Extracts a planned distance in km from text like "60km", "40 mi", "100 km".
    /// Word boundary after the unit prevents matching the "mi" in "15min".
    static func inferDistance(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(kilometers|km|miles|mi)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }
        let unit = text[unitRange].lowercased()
        return unit.hasPrefix("mi") ? value * 1.60934 : value
    }
    
    // MARK: - Merge Into SwiftData
    
    @MainActor
    static func mergeEvents(_ events: [ICSEvent], context: ModelContext) throws -> CalendarSyncResult {
        var result = CalendarSyncResult()
        
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: syncWindowDays, to: now) ?? now
        let startOfToday = Calendar.current.startOfDay(for: now)
        
        let relevantEvents = events.filter { $0.start >= startOfToday && $0.start <= windowEnd }
        
        let existingRides = try context.fetch(FetchDescriptor<ScheduledRide>())
        var ridesByEventId: [String: ScheduledRide] = [:]
        for ride in existingRides {
            if let eventId = ride.calendarEventId {
                ridesByEventId[eventId] = ride
            }
        }
        
        for event in relevantEvents {
            let rideType = inferRideType(title: event.summary, description: event.eventDescription)
            let distance = inferDistance(from: event.summary + " " + event.eventDescription)
            
            if let existing = ridesByEventId[event.uid] {
                // Update if the platform changed the plan; never touch completed rides
                guard !existing.isCompleted else {
                    result.skipped += 1
                    continue
                }
                var changed = false
                if existing.name != event.summary { existing.name = event.summary; changed = true }
                if existing.scheduledDate != event.start { existing.scheduledDate = event.start; changed = true }
                if abs(existing.duration - event.duration) > 60 { existing.duration = event.duration; changed = true }
                if existing.notes != event.eventDescription && !event.eventDescription.isEmpty {
                    existing.notes = event.eventDescription
                    changed = true
                }
                if let distance = distance, existing.distance == nil {
                    existing.distance = distance
                    changed = true
                }
                existing.lastSynced = now
                if changed { result.updated += 1 } else { result.skipped += 1 }
            } else {
                let ride = ScheduledRide(
                    name: event.summary,
                    scheduledDate: event.start,
                    duration: event.duration,
                    rideType: rideType,
                    distance: distance,
                    notes: event.eventDescription
                )
                ride.calendarEventId = event.uid
                ride.lastSynced = now
                context.insert(ride)
                result.imported += 1
            }
        }
        
        try context.save()
        return result
    }
}
