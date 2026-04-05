import Foundation
import UserNotifications

actor SavedRaceNotificationManager {
    static let shared = SavedRaceNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let savedRaceIdsKey = "Cyclismo.savedRaceIds"
    private let identifierPrefix = "Cyclismo.saved-race-live."
    private let maxScheduledNotifications = 60

    private init() {}

    func refreshSavedRaceNotifications(requestAuthorization: Bool = false) async {
        if requestAuthorization {
            _ = await requestAuthorizationIfNeeded()
        }

        let settings = await notificationSettings()
        let hasPermission = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        let existingIdentifiers = await pendingCyclismoIdentifiers()
        if !existingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
        }

        guard hasPermission else { return }

        let savedRaceIds = loadSavedRaceIds()
        guard !savedRaceIds.isEmpty else { return }

        let allRaces = await BootstrapDataStore.shared.fetchRaces(
            filters: RaceFilters(limit: Int.max, sortOrder: .date)
        )
        guard !allRaces.isEmpty else { return }

        let streamerNamesByRaceId = await BootstrapDataStore.shared.fetchRaceIdToStreamerNames()
        let now = Date()

        let scheduledItems = allRaces
            .filter { savedRaceIds.contains($0.raceId) }
            .compactMap { race -> ScheduledRaceNotification? in
                let streamers = resolvedStreamerNames(for: race, explicitNames: streamerNamesByRaceId[race.raceId] ?? [])
                guard !streamers.isEmpty else { return nil }
                guard let fireDate = notificationDate(for: race), fireDate > now else { return nil }
                return ScheduledRaceNotification(race: race, streamers: streamers, fireDate: fireDate)
            }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(maxScheduledNotifications)

        for item in scheduledItems {
            let content = UNMutableNotificationContent()
            content.title = "\(item.race.name) is live"
            content.body = "Now streaming on \(item.streamers.joined(separator: ", "))."
            content.sound = .default
            content.userInfo = ["raceId": item.race.raceId]

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: item.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: item.race.raceId),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingCyclismoIdentifiers() async -> [String] {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        return requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
    }

    private func loadSavedRaceIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: savedRaceIdsKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    private func notificationIdentifier(for raceId: String) -> String {
        "\(identifierPrefix)\(raceId)"
    }

    private func resolvedStreamerNames(for race: Race, explicitNames: [String]) -> [String] {
        if !explicitNames.isEmpty {
            return explicitNames
        }
        return StreamerFallback.inferredDisplayNames(for: race.name)
    }

    private func notificationDate(for race: Race) -> Date? {
        if let utcDate = parseISO8601(race.startDatetimeUtc) {
            return utcDate
        }

        let timezone = resolvedTimeZone(rawValue: race.startTimezone)
        let baseDate = parseDateOnly(race.startDate, timezone: timezone)
        guard let date = baseDate else { return nil }
        var components = Calendar.current.dateComponents(in: timezone, from: date)

        if let localTime = parseLocalTime(race.startTimeLocal) {
            components.hour = localTime.hour
            components.minute = localTime.minute
        } else {
            // Fall back to mid-morning when only date is available.
            components.hour = 9
            components.minute = 0
        }
        components.second = 0
        components.timeZone = timezone
        return Calendar.current.date(from: components)
    }

    private func parseISO8601(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func parseDateOnly(_ value: String, timezone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func parseLocalTime(_ value: String?) -> (hour: Int, minute: Int)? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        let formats = ["H:mm", "HH:mm", "h:mm a", "h:mma", "HH:mm:ss", "H:mm:ss"]
        for format in formats {
            parser.dateFormat = format
            if let date = parser.date(from: value) {
                let components = Calendar.current.dateComponents(in: .gmt, from: date)
                if let hour = components.hour, let minute = components.minute {
                    return (hour, minute)
                }
            }
        }
        return nil
    }

    private func resolvedTimeZone(rawValue: String?) -> TimeZone {
        let value = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            if let timezone = TimeZone(identifier: value) {
                return timezone
            }
            if let timezone = TimeZone(abbreviation: value.uppercased()) {
                return timezone
            }
        }
        return .current
    }
}

private struct ScheduledRaceNotification {
    let race: Race
    let streamers: [String]
    let fireDate: Date
}
