//
//  TVAccountViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import WatchedItCore

final class TVAccountViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case icloud
        case preferences
        case catalog
        case appearance
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Account"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .black
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .icloud:
            return 2
        case .preferences:
            return 2
        case .catalog:
            return 1
        case .appearance:
            return 1
        case .none:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .icloud:
            return "iCloud"
        case .preferences:
            return "Preferences"
        case .catalog:
            return "Catalog"
        case .appearance:
            return "Appearance"
        case .none:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .black
        cell.accessoryType = .disclosureIndicator

        switch Section(rawValue: indexPath.section) {
        case .icloud:
            if indexPath.row == 0 {
                cell.textLabel?.text = MinCloudSettings.iCloudBackupEnabled ? "iCloud backup is on" : "iCloud backup is off"
                cell.accessoryType = .none
            } else {
                cell.textLabel?.text = "Sync from iCloud"
                cell.accessoryType = .none
            }
        case .preferences:
            cell.textLabel?.text = indexPath.row == 0 ? "Streaming Services" : "Lists"
        case .catalog:
            cell.textLabel?.text = "Refresh Catalog from Bundle"
        case .appearance:
            cell.textLabel?.text = "Themes"
        case .none:
            cell.textLabel?.text = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .icloud:
            guard indexPath.row == 1 else { return }
            Task { @MainActor in
                await LocalDatabaseManager.shared.restoreUserDataFromCloudKitIfNeeded()
                await LocalDatabaseManager.shared.syncUserDataFromCloudKit(mergeOnlyWhenLocalEmpty: false)
                await LocalDatabaseManager.shared.syncStreamingPreferencesFromCloudKitIfNewer()
                await LocalDatabaseManager.shared.syncListPreferencesFromCloudKitIfNewer()
            }
        case .preferences:
            if indexPath.row == 0 {
                navigationController?.pushViewController(TVStreamingServicesViewController(), animated: true)
            } else {
                navigationController?.pushViewController(TVListPreferencesViewController(), animated: true)
            }
        case .catalog:
            Task { @MainActor in
                do {
                    try await LocalDatabaseManager.shared.refreshCatalogFromBundle()
                } catch {
                    print("⚠️ Catalog refresh failed: \(error)")
                }
            }
        case .appearance:
            navigationController?.pushViewController(TVThemesViewController(), animated: true)
        case .icloud, .none:
            break
        }
    }
}
