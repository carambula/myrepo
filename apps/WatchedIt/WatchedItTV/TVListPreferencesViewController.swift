//
//  TVListPreferencesViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import SwiftData
import WatchedItCore

final class TVListPreferencesViewController: UITableViewController {
    private var preferredListIds: [String] = []
    private var allDataSources: [DataSource] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lists"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .black
        loadData()
    }

    private func loadData() {
        preferredListIds = ListPreferences.decode(from: UserDefaults.standard.data(forKey: ListPreferences.storageKey) ?? Data())
        if !ListPreferences.hasInitialized() {
            preferredListIds = allDataSources.map { $0.identifier }
            ListPreferences.setHasInitialized(true)
            UserDefaults.standard.set(ListPreferences.encode(preferredListIds), forKey: ListPreferences.storageKey)
        }

        if let context = LocalDatabaseManager.shared.modelContext {
            let descriptor = FetchDescriptor<DataSource>(sortBy: [SortDescriptor(\.name)])
            allDataSources = (try? context.fetch(descriptor)) ?? []
        }
        tableView.reloadData()
    }

    private var preferredLists: [DataSource] {
        let lookup = Dictionary(uniqueKeysWithValues: allDataSources.map { ($0.identifier, $0) })
        return preferredListIds.compactMap { lookup[$0] }
    }

    private var availableLists: [DataSource] {
        let preferredSet = Set(preferredListIds)
        return allDataSources.filter { !preferredSet.contains($0.identifier) }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? preferredLists.count : availableLists.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Preferred Lists" : "All Lists"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .black
        let list = indexPath.section == 0 ? preferredLists[indexPath.row] : availableLists[indexPath.row]
        cell.textLabel?.text = list.name
        cell.accessoryType = indexPath.section == 0 ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let list = preferredLists[indexPath.row]
            if let index = preferredListIds.firstIndex(of: list.identifier) {
                preferredListIds.remove(at: index)
            }
        } else {
            let list = availableLists[indexPath.row]
            preferredListIds.append(list.identifier)
        }
        UserDefaults.standard.set(ListPreferences.encode(preferredListIds), forKey: ListPreferences.storageKey)
        ListPreferences.updateLastUpdated()
        Task { @MainActor in
            await LocalDatabaseManager.shared.pushLocalListPreferencesToCloudKitIfNeeded()
        }
        tableView.reloadData()
    }
}
