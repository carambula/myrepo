//
//  TVMovieListViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import TVUIKit
import Combine
import WatchedItCore

enum InspirationSection: Int, CaseIterable, Hashable {
    case recentlySaved
    case latestPodcasts
    case toComplete
    case longestSaved

    var title: String {
        switch self {
        case .recentlySaved:
            return "Recently saved"
        case .latestPodcasts:
            return "Latest podcasts"
        case .toComplete:
            return "To complete"
        case .longestSaved:
            return "Longest saved"
        }
    }
}

enum TVMovieListSectionKind: Hashable {
    case inspiration(InspirationSection)
    case allMovies

    var title: String {
        switch self {
        case .inspiration(let inspiration):
            return inspiration.title
        case .allMovies:
            return "All movies"
        }
    }
}

final class TVMovieListViewController: UIViewController {
    private var inspirationCollectionView: UICollectionView!
    private var cancellables: Set<AnyCancellable> = []

    private enum FilterOption: String, CaseIterable {
        case all = "All"
        case rewatched = "Rewatched"
        case listened = "Listened"
        case saved = "Saved"
    }

    private var allMovies: [Movie] = []
    private var filteredMovies: [Movie] = []
    private var inspirationMovies: [InspirationSection: [Movie]] = [:]
    private var sectionOrder: [TVMovieListSectionKind] = []
    private var allMoviesSorted: [Movie] = []
    private var currentFilter: FilterOption = .all
    private var currentSearchText: String = ""
    private var searchResultsController: TVSearchResultsViewController?
    private let inspirationLimit = 25
    private let latestPodcastLimit = 20
    private var hasAttemptedBootstrapRefresh = false
    private var isCommittingPendingPodcastEpisodes = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "WatchedIt"

        configureSearch()
        configureFilters()
        configureInspirationCollectionView()
        bindMovies()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureSearch() {
        updateLeftBarButtons()
    }

    private func configureFilters() {
        let filterButton = UIBarButtonItem(
            title: "Filter",
            style: .plain,
            target: self,
            action: #selector(showFilterOptions)
        )
        let accountButton = UIBarButtonItem(
            title: "Account",
            style: .plain,
            target: self,
            action: #selector(openAccount)
        )
        navigationItem.rightBarButtonItems = [accountButton, filterButton]
    }

    private func configureInspirationCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self else { return nil }
            let section = self.sectionOrder[safe: sectionIndex] ?? .allMovies
            switch section {
            case .inspiration:
                return self.makeInspirationSectionLayout()
            case .allMovies:
                return self.makeAllMoviesSectionLayout(environment: environment)
            }
        }

        inspirationCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        inspirationCollectionView.backgroundColor = .black
        inspirationCollectionView.translatesAutoresizingMaskIntoConstraints = false
        inspirationCollectionView.dataSource = self
        inspirationCollectionView.delegate = self

        inspirationCollectionView.register(
            TVMovieCollectionViewCell.self,
            forCellWithReuseIdentifier: TVMovieCollectionViewCell.reuseIdentifier
        )
        inspirationCollectionView.register(
            TVSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: TVSectionHeaderView.reuseIdentifier
        )

        view.addSubview(inspirationCollectionView)
        NSLayoutConstraint.activate([
            inspirationCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            inspirationCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inspirationCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inspirationCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindMovies() {
        let localDB = LocalDatabaseManager.shared
        localDB.$movies
            .receive(on: RunLoop.main)
            .sink { [weak self] movies in
                self?.allMovies = movies
                self?.refreshCatalogIfNeeded(for: movies)
                self?.applyFiltersAndReload()
            }
            .store(in: &cancellables)

        localDB.$pendingPodcastEpisodeCount
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLeftBarButtons()
            }
            .store(in: &cancellables)
    }

    private func notificationsButtonTitle() -> String {
        let count = LocalDatabaseManager.shared.pendingPodcastEpisodeCount
        return count > 0 ? "Updates \(count)" : "Updates"
    }

    private func makeNotificationsButton() -> UIBarButtonItem {
        UIBarButtonItem(
            title: notificationsButtonTitle(),
            style: .plain,
            target: self,
            action: #selector(showPendingPodcastEpisodesMenu)
        )
    }

    private func updateLeftBarButtons() {
        let searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(presentSearch))
        if LocalDatabaseManager.shared.pendingPodcastEpisodeCount > 0 {
            navigationItem.leftBarButtonItems = [makeNotificationsButton(), searchButton]
        } else {
            navigationItem.leftBarButtonItems = [searchButton]
        }
    }

    private func refreshCatalogIfNeeded(for movies: [Movie]) {
        guard movies.isEmpty, !hasAttemptedBootstrapRefresh else { return }
        hasAttemptedBootstrapRefresh = true
        Task { @MainActor in
            do {
                try await LocalDatabaseManager.shared.refreshCatalogFromBundle()
                LocalDatabaseManager.shared.loadMovies()
            } catch {
                print("⚠️ [BOOTSTRAP] Manual refresh failed: \(error)")
            }
        }
    }

    private func rebuildSectionOrder() {
        let inspirationSections = InspirationSection.allCases.filter { !(inspirationMovies[$0] ?? []).isEmpty }
        sectionOrder = inspirationSections.map { TVMovieListSectionKind.inspiration($0) }
        allMoviesSorted = filteredMovies.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        if !allMoviesSorted.isEmpty {
            sectionOrder.append(.allMovies)
        }
        inspirationCollectionView.reloadData()
    }

    private func applyFiltersAndReload() {
        filteredMovies = allMovies.filter { movie in
            let matchesFilter: Bool
            switch currentFilter {
            case .all:
                matchesFilter = true
            case .rewatched:
                matchesFilter = movie.isRewatched
            case .listened:
                matchesFilter = movie.isListened
            case .saved:
                matchesFilter = movie.isSaved
            }

            if !matchesFilter {
                return false
            }

            let trimmed = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }

            if movie.title.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            if let year = movie.year, String(year).contains(trimmed) {
                return true
            }
            if let overview = movie.overview, overview.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            return false
        }

        inspirationMovies = buildInspirationSections(from: filteredMovies)
        rebuildSectionOrder()
    }

    private func buildInspirationSections(from movies: [Movie]) -> [InspirationSection: [Movie]] {
        var sections: [InspirationSection: [Movie]] = [:]

        let recentlySaved = movies
            .filter { $0.isSaved }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        sections[.recentlySaved] = Array(recentlySaved.prefix(inspirationLimit))

        let latestPodcasts = movies
            .compactMap { movie -> (Movie, Date)? in
                guard let date = movie.podcastEpisode?.publishDate else { return nil }
                return (movie, date)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
        sections[.latestPodcasts] = Array(latestPodcasts.prefix(latestPodcastLimit))

        let toComplete = movies.filter { movie in
            movie.podcastEpisode != nil
                && (movie.isListened || movie.isRewatched)
                && movie.isListened != movie.isRewatched
        }
        sections[.toComplete] = Array(toComplete.prefix(inspirationLimit))

        let longestSaved = movies
            .filter { $0.isSaved }
            .sorted { $0.lastUpdated < $1.lastUpdated }
            .filter { !($0.isRewatched && $0.isListened) }
        sections[.longestSaved] = Array(longestSaved.prefix(inspirationLimit))

        return sections
    }

    private func searchResults(for query: String) -> [Movie] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return allMovies.filter { movie in
            if movie.title.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            if let year = movie.year, String(year).contains(trimmed) {
                return true
            }
            if let overview = movie.overview, overview.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            return false
        }
    }

    @objc private func showFilterOptions() {
        let alert = UIAlertController(title: "Filter", message: nil, preferredStyle: .alert)
        for option in FilterOption.allCases {
            let action = UIAlertAction(title: option.rawValue, style: .default) { [weak self] _ in
                self?.currentFilter = option
                self?.applyFiltersAndReload()
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func presentSearch() {
        let resultsController = TVSearchResultsViewController()
        resultsController.onSelectMovie = { [weak self] movie in
            let detail = TVMovieDetailViewController(movie: movie)
            self?.navigationController?.pushViewController(detail, animated: true)
            self?.dismiss(animated: true)
        }

        let searchController = UISearchController(searchResultsController: resultsController)
        searchController.obscuresBackgroundDuringPresentation = true
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search movies"
        searchController.searchBar.searchBarStyle = .minimal

        let container = UISearchContainerViewController(searchController: searchController)
        present(container, animated: true)
        searchResultsController = resultsController
    }

    @objc private func openAccount() {
        let account = TVAccountViewController()
        navigationController?.pushViewController(account, animated: true)
    }

    @objc private func showPendingPodcastEpisodesMenu() {
        let pendingCount = LocalDatabaseManager.shared.pendingPodcastEpisodeCount
        let alert = UIAlertController(title: "Notifications", message: nil, preferredStyle: .alert)
        if pendingCount > 0 {
            let title = isCommittingPendingPodcastEpisodes
                ? "Adding new episodes…"
                : "New episodes available, tap to add"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self, !self.isCommittingPendingPodcastEpisodes else { return }
                self.isCommittingPendingPodcastEpisodes = true
                Task { @MainActor [weak self] in
                    _ = await LocalDatabaseManager.shared.commitPendingPodcastEpisodes()
                    self?.applyFiltersAndReload()
                    self?.isCommittingPendingPodcastEpisodes = false
                }
            })
        } else {
            alert.addAction(UIAlertAction(title: "No new episodes available", style: .default))
        }
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
}

extension TVMovieListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if collectionView == inspirationCollectionView {
            return sectionOrder.count
        }
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == inspirationCollectionView {
            guard let sectionKind = sectionOrder[safe: section] else { return 0 }
            switch sectionKind {
            case .inspiration(let inspiration):
                return inspirationMovies[inspiration]?.count ?? 0
            case .allMovies:
                return allMoviesSorted.count
            }
        }
        return 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard collectionView == inspirationCollectionView,
              let sectionKind = sectionOrder[safe: indexPath.section] else {
            return UICollectionViewCell()
        }
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TVMovieCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! TVMovieCollectionViewCell
        let movie: Movie
        switch sectionKind {
        case .inspiration(let inspiration):
            guard let selected = inspirationMovies[inspiration]?[indexPath.item] else {
                return UICollectionViewCell()
            }
            movie = selected
        case .allMovies:
            guard allMoviesSorted.indices.contains(indexPath.item) else {
                return UICollectionViewCell()
            }
            movie = allMoviesSorted[indexPath.item]
        }
        cell.configure(with: movie)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView == inspirationCollectionView,
              let sectionKind = sectionOrder[safe: indexPath.section] else { return }
        let movie: Movie
        switch sectionKind {
        case .inspiration(let inspiration):
            guard let selected = inspirationMovies[inspiration]?[indexPath.item] else { return }
            movie = selected
        case .allMovies:
            movie = allMoviesSorted[indexPath.item]
        }
        let detail = TVMovieDetailViewController(movie: movie)
        navigationController?.pushViewController(detail, animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard collectionView == inspirationCollectionView,
              kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: TVSectionHeaderView.reuseIdentifier,
            for: indexPath
        ) as! TVSectionHeaderView
        if let sectionKind = sectionOrder[safe: indexPath.section] {
            header.configure(title: sectionKind.title)
        }
        return header
    }
}

private extension TVMovieListViewController {
    func makeInspirationSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(240),
            heightDimension: .absolute(360)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 24)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(240),
            heightDimension: .absolute(360)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 32, trailing: 24)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        sectionLayout.boundarySupplementaryItems = [header]
        return sectionLayout
    }

    func makeAllMoviesSectionLayout(
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let itemWidth: CGFloat = 240
        let itemHeight: CGFloat = 400
        let spacing: CGFloat = 24
        let availableWidth = environment.container.effectiveContentSize.width - (spacing * 2)
        let columns = max(3, Int((availableWidth + spacing) / (itemWidth + spacing)))
        let fractionalWidth = 1.0 / CGFloat(columns)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(fractionalWidth),
            heightDimension: .absolute(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: spacing)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(itemHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: columns
        )

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: spacing, bottom: 48, trailing: spacing)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(52)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        sectionLayout.boundarySupplementaryItems = [header]
        return sectionLayout
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

final class TVSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "TVSectionHeaderView"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViews()
    }

    func configure(title: String) {
        titleLabel.text = title
    }

    private func configureViews() {
        backgroundColor = .clear
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}

extension TVMovieListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        currentSearchText = searchController.searchBar.text ?? ""
        let results = searchResults(for: currentSearchText)
        searchResultsController?.updateResults(results)
    }
}
