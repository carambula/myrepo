//
//  TVStreamingServicesViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import WatchedItCore

final class TVStreamingServicesViewController: UITableViewController {
    private var preferredServices: [String] = []
    private var hiddenServices: [String] = []
    private var availableServices: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Streaming Services"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .black
        loadData()
    }

    private func loadData() {
        preferredServices = canonicalizeServices(StreamingPreferences.decode(from: StreamingPreferences.preferredServicesData()))
        hiddenServices = canonicalizeServices(StreamingPreferences.decode(from: StreamingPreferences.hiddenServicesData()))
        rebuildAvailableServices()
        tableView.reloadData()
    }

    private func rebuildAvailableServices() {
        var normalized: [String] = []
        for movie in LocalDatabaseManager.shared.movies {
            for service in movie.streamingServices {
                let name = normalizedName(service.name)
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    normalized.append(name)
                }
            }
        }
        let hiddenSet = Set(hiddenServices.map { normalizedCaseKey($0) })
        availableServices = Array(Set(normalized))
            .filter { !hiddenSet.contains(normalizedCaseKey($0)) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Preferred Services"
        case 1: return "Hidden Services"
        default: return "All Services"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return preferredServices.count
        case 1: return hiddenServices.count
        default: return availableServices.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .black
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = preferredServices[indexPath.row]
        case 1:
            cell.textLabel?.text = hiddenServices[indexPath.row]
        default:
            cell.textLabel?.text = availableServices[indexPath.row]
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let service = preferredServices[indexPath.row]
            if let idx = preferredServices.firstIndex(of: service) {
                preferredServices.remove(at: idx)
            }
        case 1:
            let service = hiddenServices[indexPath.row]
            if let idx = hiddenServices.firstIndex(of: service) {
                hiddenServices.remove(at: idx)
            }
        default:
            let service = availableServices[indexPath.row]
            togglePreferred(service)
        }
        persist()
        rebuildAvailableServices()
        tableView.reloadData()
    }

    private func togglePreferred(_ service: String) {
        if let index = preferredServices.firstIndex(of: service) {
            preferredServices.remove(at: index)
        } else {
            preferredServices.append(service)
        }
    }

    private func persist() {
        StreamingPreferences.setPreferredServicesData(StreamingPreferences.encode(preferredServices))
        StreamingPreferences.setHiddenServicesData(StreamingPreferences.encode(hiddenServices))
        StreamingPreferences.updateLastUpdated()
        Task { @MainActor in
            await LocalDatabaseManager.shared.pushLocalStreamingPreferencesToCloudKitIfNeeded()
        }
    }

    private func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        switch lower {
        case "amazon video", "amazon prime video", "amazon prime video with ads", "prime video":
            return "Prime Video"
        case "hbo max", "max", "hbo max amazon channel", "max amazon channel", "hbo max roku premium channel", "max roku premium channel":
            return "HBO Max"
        default:
            return trimmed
        }
    }

    private func canonicalizeServices(_ services: [String]) -> [String] {
        var orderedKeys: [String] = []
        var entries: [String: String] = [:]
        var hasMixedCaps: [String: Bool] = [:]

        for service in services {
            let trimmedName = service.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = normalizedCaseKey(trimmedName)

            if entries[key] == nil {
                orderedKeys.append(key)
                entries[key] = trimmedName
                hasMixedCaps[key] = isMixedCaps(trimmedName)
                continue
            }

            let currentMixed = hasMixedCaps[key] ?? false
            let candidateMixed = isMixedCaps(trimmedName)
            if !currentMixed && candidateMixed {
                entries[key] = trimmedName
                hasMixedCaps[key] = true
            }
        }

        return orderedKeys.compactMap { entries[$0] }
    }

    private func normalizedCaseKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isMixedCaps(_ value: String) -> Bool {
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let hasUpper = letters.contains { CharacterSet.uppercaseLetters.contains($0) }
        let hasLower = letters.contains { CharacterSet.lowercaseLetters.contains($0) }
        return hasUpper && hasLower
    }
}
