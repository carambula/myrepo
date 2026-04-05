//
//  TVThemesViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import WatchedItCore

final class TVThemesViewController: UITableViewController {
    private let themeManager = ThemeManager.shared
    private var themes: [Theme] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Themes"
        themes = themeManager.getAllThemes()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .black
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        themes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let theme = themes[indexPath.row]
        cell.textLabel?.text = theme.name
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .black
        cell.accessoryType = theme.name == themeManager.currentTheme.name ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let theme = themes[indexPath.row]
        themeManager.setTheme(theme)
        tableView.reloadData()
    }
}
