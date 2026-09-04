//
//  TVMovieDetailViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import TVUIKit
import WatchedItCore

final class TVMovieDetailViewController: UIViewController {
    private let movie: Movie
    private let localDB = LocalDatabaseManager.shared

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var heroHeightConstraint: NSLayoutConstraint?
    private var actionButtons: [UIButton] = []
    private var lastFocusWasActionButton = false

    init(movie: Movie) {
        self.movie = movie
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = ""
        navigationItem.title = ""

        configureLayout()
        configureContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroHeightConstraint {
            let height = max(view.bounds.height + view.safeAreaInsets.top, 420)
            if heroHeightConstraint.constant != height {
                heroHeightConstraint.constant = height
            }
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let nextIsAction = (context.nextFocusedView as? UIButton).map { button in
            actionButtons.contains { $0 === button }
        } ?? false

        if nextIsAction && !lastFocusWasActionButton {
            coordinator.addCoordinatedAnimations { [weak self] in
                self?.scrollView.setContentOffset(.zero, animated: true)
            }
        }

        lastFocusWasActionButton = nextIsAction
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 32
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -40),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -80)
        ])
    }

    private func configureContent() {
        let heroView = makeHeroHeaderView()
        contentStack.addArrangedSubview(heroView)
        contentStack.setCustomSpacing(32, after: heroView)

        if let overview = movie.overview, !overview.isEmpty {
            let descriptionLabel = makeFocusableBodyLabel(overview)
            contentStack.addArrangedSubview(descriptionLabel)
            contentStack.setCustomSpacing(32, after: descriptionLabel)
        }

        if let genresSection = makeGenresSection() {
            contentStack.addArrangedSubview(genresSection)
        }

        if let creditsSection = makeCreditsSection() {
            contentStack.addArrangedSubview(creditsSection)
        }

        if let physicalMediaSection = makePhysicalMediaSection() {
            contentStack.addArrangedSubview(physicalMediaSection)
        }

        if let theatersSection = makeTheatersSection() {
            contentStack.addArrangedSubview(theatersSection)
        }

        if let streamingSection = makeStreamingSection() {
            contentStack.addArrangedSubview(streamingSection)
        }

        if let podcastSection = makePodcastSection() {
            contentStack.addArrangedSubview(podcastSection)
        }

        if let trailerSection = makeTrailerSection() {
            contentStack.addArrangedSubview(trailerSection)
        }

        if let rewatchablesSection = makeRewatchablesSection() {
            contentStack.addArrangedSubview(rewatchablesSection)
        }
    }

    private func makeHeroHeaderView() -> UIView {
        let container = TVNonFocusableView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = container.heightAnchor.constraint(equalToConstant: 420)
        heightConstraint.isActive = true
        heroHeightConstraint = heightConstraint

        let posterView = TVNonFocusablePosterView()
        posterView.translatesAutoresizingMaskIntoConstraints = false
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.title = nil
        posterView.subtitle = nil
        posterView.isUserInteractionEnabled = false
        container.addSubview(posterView)

        let gradientView = TVHeroGradientView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(gradientView)

        let overlayStack = UIStackView()
        overlayStack.axis = .vertical
        overlayStack.spacing = 16
        overlayStack.alignment = .leading
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlayStack)

        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.text = movie.title

        let metadataRow = makeMetadataRow()

        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 24
        buttonStack.distribution = .fillEqually

        let playButton = makePlayMenuButton()

        let rewatchedButton = makeStatusButton(
            title: "Rewatched",
            isActive: movie.isRewatched
        ) { [weak self] in
            guard let self else { return }
            try? self.localDB.updateRewatchedStatus(self.movie, isRewatched: !self.movie.isRewatched)
        }

        let listenedButton = makeStatusButton(
            title: "Listened",
            isActive: movie.isListened
        ) { [weak self] in
            guard let self else { return }
            try? self.localDB.updateListenedStatus(self.movie, isListened: !self.movie.isListened)
        }

        let savedButton = makeStatusButton(
            title: "Saved",
            isActive: movie.isSaved
        ) { [weak self] in
            guard let self else { return }
            try? self.localDB.updateSavedStatus(self.movie, isSaved: !self.movie.isSaved)
        }

        buttonStack.addArrangedSubview(playButton)
        buttonStack.addArrangedSubview(rewatchedButton)
        buttonStack.addArrangedSubview(listenedButton)
        buttonStack.addArrangedSubview(savedButton)
        actionButtons = [playButton, rewatchedButton, listenedButton, savedButton]

        overlayStack.addArrangedSubview(titleLabel)
        if let metadataRow {
            overlayStack.addArrangedSubview(metadataRow)
        }
        overlayStack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            posterView.topAnchor.constraint(equalTo: container.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            gradientView.topAnchor.constraint(equalTo: container.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            overlayStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            overlayStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40),
            overlayStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -32)
        ])

        configureHeroImage(posterView)
        return container
    }

    private func configureHeroImage(_ posterView: TVPosterView) {
        let path = movie.backdropPath ?? movie.posterPath
        guard let posterPath = path, !posterPath.isEmpty else { return }

        let urlString: String?
        if posterPath == movie.backdropPath {
            urlString = MovieDataService.shared.getBackdropURL(path: posterPath)
        } else {
            urlString = MovieDataService.shared.getLargePosterURL(path: posterPath)
        }

        guard let urlString, let url = URL(string: urlString) else { return }

        if let cached = ImageCache.shared.getImage(for: url) {
            posterView.image = cached
        } else {
            Task.detached {
                await ImageCache.shared.prefetchImage(from: url)
                let cached = ImageCache.shared.getImage(for: url)
                await MainActor.run {
                    posterView.image = cached
                }
            }
        }
    }

    private func makeStatusButton(title: String, isActive: Bool, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = isActive ? UIColor.systemBlue : UIColor.darkGray
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        button.configuration = configuration
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    private func makePlayMenuButton() -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Play"
        configuration.baseBackgroundColor = UIColor.darkGray
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        button.configuration = configuration
        button.showsMenuAsPrimaryAction = true
        button.menu = buildPlayMenu()
        return button
    }

    private func buildPlayMenu() -> UIMenu {
        var actions: [UIMenuElement] = []

        if let trailer = movie.trailer, trailer.youtubeURL != nil {
            actions.append(UIAction(title: "YouTube Trailer") { [weak self] _ in
                self?.openTrailer()
            })
        } else {
            actions.append(UIAction(title: "YouTube Trailer", attributes: [.disabled]) { _ in })
        }

        let streamers = streamingServicesForMenu()
        if !streamers.isEmpty {
            actions.append(contentsOf: streamers.map { service in
                UIAction(title: normalizedName(service.name)) { [weak self] _ in
                    self?.openStreamingService(service)
                }
            })
        }

        let buyOffers = PhysicalPurchaseLinkBuilder.compactOffers(
            for: movie.physicalMedia,
            title: movie.title,
            year: movie.year
        )
        if !buyOffers.isEmpty {
            let buyActions = buyOffers.map { offer in
                UIAction(title: offer.title) { [weak self] _ in
                    self?.openURLPreferApp(
                        appURL: nil,
                        fallbackAppURL: nil,
                        webURL: offer.url,
                        preferUniversalLink: true
                    )
                }
            }
            actions.append(UIMenu(title: "Buy disc", children: buyActions))
        }

        let ticketOffers = TheatricalTicketLinkBuilder.compactOffers(
            for: movie.theatricalRun,
            title: movie.title,
            year: movie.year
        )
        if !ticketOffers.isEmpty {
            let ticketActions = ticketOffers.map { offer in
                UIAction(title: offer.title) { [weak self] _ in
                    self?.openURLPreferApp(
                        appURL: nil,
                        fallbackAppURL: nil,
                        webURL: offer.url,
                        preferUniversalLink: true
                    )
                }
            }
            actions.append(UIMenu(title: "Get tickets", children: ticketActions))
        }

        return UIMenu(title: "", children: actions)
    }

    private func streamingServicesForMenu() -> [StreamingService] {
        let preferred = preferredStreamingServicesForMenu()
        if !preferred.isEmpty {
            return preferred
        }
        var seen = Set<String>()
        return movie.streamingServices.filter { service in
            let key = normalizedCaseKey(service.name)
            guard !key.isEmpty, seen.insert(key).inserted else { return false }
            return true
        }
    }

    private func preferredStreamingServicesForMenu() -> [StreamingService] {
        let preferredNames = StreamingPreferences.decode(from: StreamingPreferences.preferredServicesData())
        guard !preferredNames.isEmpty else { return [] }

        var bestByKey: [String: StreamingService] = [:]
        for service in movie.streamingServices {
            let key = normalizedCaseKey(service.name)
            if bestByKey[key] == nil {
                bestByKey[key] = service
            }
        }

        var ordered: [StreamingService] = []
        for preferred in preferredNames {
            let key = normalizedCaseKey(preferred)
            if let match = bestByKey[key] {
                ordered.append(match)
            }
        }
        return ordered
    }

    private func openTrailer() {
        guard let trailer = movie.trailer else { return }
        let appURL = URL(string: "youtube://watch?v=\(trailer.youtubeKey)")
        let fallbackAppURL = trailer.youtubeAppURL
        let webURL = trailer.youtubeURL
        openURLPreferApp(appURL: appURL, fallbackAppURL: fallbackAppURL, webURL: webURL, preferUniversalLink: true)
    }

    private func openStreamingService(_ service: StreamingService) {
        let link = StreamingServiceLinkBuilder.link(
            for: service,
            movieTitle: movie.title,
            tmdbId: movie.tmdbId
        )

        openURLPreferApp(appURL: link.appURL, fallbackAppURL: link.fallbackAppURL, webURL: link.webURL, preferUniversalLink: true)
    }

    private func openURLPreferApp(
        appURL: URL?,
        fallbackAppURL: URL?,
        webURL: URL?,
        preferUniversalLink: Bool
    ) {
        if preferUniversalLink, let webURL {
            UIApplication.shared.open(webURL, options: [:]) { [weak self] success in
                guard let self, !success else { return }
                self.openURLPreferApp(appURL: appURL, fallbackAppURL: fallbackAppURL, webURL: nil, preferUniversalLink: false)
            }
            return
        }

        if let appURL {
            UIApplication.shared.open(appURL, options: [:]) { [weak self] success in
                guard let self, !success else { return }
                self.openURLPreferApp(appURL: fallbackAppURL, fallbackAppURL: nil, webURL: webURL, preferUniversalLink: false)
            }
            return
        }

        if let fallbackAppURL {
            UIApplication.shared.open(fallbackAppURL, options: [:]) { [weak self] success in
                guard let self, !success else { return }
                self.openURLPreferApp(appURL: nil, fallbackAppURL: nil, webURL: webURL, preferUniversalLink: false)
            }
            return
        }

        if let webURL {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
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

    private func normalizedCaseKey(_ value: String) -> String {
        normalizedName(value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func makeMetadataRow() -> UIStackView? {
        var items: [UIView] = []

        if let year = movie.year {
            let yearLabel = makeSecondaryLabel(String(year))
            items.append(yearLabel)
        }

        if let mpaa = movie.mpaaRating, !mpaa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ratingLabel = makeTagLabel(mpaa)
            items.append(ratingLabel)
        }

        if let tmdbId = movie.tmdbId {
            let tmdbLabel = makeSecondaryLabel("TMDB \(tmdbId)")
            items.append(tmdbLabel)
        }

        if let media = movie.physicalMedia, media.hasDisplayableAvailability {
            for badge in media.badgeLabels {
                items.append(makeTagLabel(badge))
            }
        }

        if let run = movie.theatricalRun, run.hasDisplayableAvailability {
            for badge in run.badgeLabels {
                items.append(makeTagLabel(badge))
            }
        }

        guard !items.isEmpty else { return nil }

        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }

    private func makeGenresSection() -> UIStackView? {
        let genres = movie.genres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !genres.isEmpty else { return nil }

        let label = makeFocusableBodyLabel(genres.joined(separator: " • "))
        return makeSection(title: "Genres", rows: [label])
    }

    private func makeCreditsSection() -> UIStackView? {
        guard let credits = movie.credits else { return nil }
        var rows: [UIView] = []

        if let director = credits.director, !director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Director", value: director))
        }

        let cast = credits.cast
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !cast.isEmpty {
            rows.append(makeCastMonogramRow(cast: cast))
        }

        guard !rows.isEmpty else { return nil }
        return makeSection(title: "Credits", rows: rows)
    }

    private func makePhysicalMediaSection() -> UIStackView? {
        guard let media = movie.physicalMedia, media.hasDisplayableAvailability else { return nil }
        var rows: [UIView] = []
        if media.editions.isEmpty {
            rows.append(makeFocusableBodyLabel(media.badgeLabels.joined(separator: "   ")))
        } else {
            for edition in media.editions {
                rows.append(makeFocusableBodyLabel(edition.displayLine))
            }
        }
        return makeSection(title: "Physical Media", rows: rows)
    }

    private func makeTheatersSection() -> UIStackView? {
        guard let run = movie.theatricalRun, run.hasDisplayableAvailability else { return nil }
        return makeSection(title: "In Theaters", rows: [makeFocusableBodyLabel(run.badgeLabels.joined(separator: "   "))])
    }

    private func makeStreamingSection() -> UIStackView? {
        let serviceNames = movie.streamingServices
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !serviceNames.isEmpty else { return nil }
        let label = makeFocusableBodyLabel(serviceNames.joined(separator: " • "))
        return makeSection(title: "Where to Watch", rows: [label])
    }

    private func makePodcastSection() -> UIStackView? {
        guard let episode = movie.podcastEpisode else { return nil }
        var rows: [UIView] = []

        rows.append(makeFocusableKeyValueRow(title: "Episode", value: episode.title))

        if let publishDate = episode.publishDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            rows.append(makeFocusableKeyValueRow(title: "Published", value: formatter.string(from: publishDate)))
        }

        if let description = episode.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let label = makeFocusableBodyLabel(description)
            rows.append(label)
        }

        return makeSection(title: "Podcast", rows: rows)
    }

    private func makeTrailerSection() -> UIStackView? {
        guard let trailer = movie.trailer else { return nil }
        let title = trailer.isOfficial ? "\(trailer.name) (Official)" : trailer.name
        let label = makeFocusableBodyLabel(title)
        return makeSection(title: "Trailer", rows: [label])
    }

    private func makeRewatchablesSection() -> UIStackView? {
        guard let discussion = movie.rewatchablesDiscussion else { return nil }
        var rows: [UIView] = []

        if let score = discussion.rewatchabilityScore {
            rows.append(makeFocusableKeyValueRow(title: "Rewatchability", value: "\(score)"))
        }

        if let apex = discussion.apexMountain, !apex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Apex Mountain", value: apex))
        }

        if let dion = discussion.dionWaiters, !dion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Dion Waiters", value: dion))
        }

        if let agedBest = discussion.agedBest, !agedBest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Aged Best", value: agedBest))
        }

        if let agedWorst = discussion.agedWorst, !agedWorst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Aged Worst", value: agedWorst))
        }

        if let joey = discussion.joeyPants, !joey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Joey Pants", value: joey))
        }

        if let thatGuy = discussion.thatGuy, !thatGuy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "That Guy", value: thatGuy))
        }

        if let casting = discussion.castingWhatIf, !casting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Casting What-If", value: casting))
        }

        let questions = discussion.unanswerableQuestions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !questions.isEmpty {
            rows.append(makeFocusableKeyValueRow(title: "Unanswerables", value: questions.joined(separator: " • ")))
        }

        guard !rows.isEmpty else { return nil }
        return makeSection(title: "Rewatchables", rows: rows)
    }

    private func makeSection(title: String, rows: [UIView]) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)

        let header = makeSectionHeader(title)
        stack.addArrangedSubview(header)

        for row in rows {
            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func makeSectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .white
        label.text = text
        return label
    }

    private func makeBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .lightGray
        label.text = text
        label.numberOfLines = 0
        return label
    }

    private func makeSecondaryLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .lightGray
        label.text = text
        return label
    }

    private func makeTagLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .white
        label.backgroundColor = UIColor.darkGray
        label.textAlignment = .center
        label.text = " \(text) "
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }

    private func makeKeyValueRow(title: String, value: String) -> UIStackView {
        let titleLabel = makeSecondaryLabel("\(title):")
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = makeBodyLabel(value)

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        return stack
    }

    private func makeCastMonogramRow(cast: [CastMember]) -> UIStackView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8
        container.alignment = .fill

        let titleLabel = makeSecondaryLabel("Main Cast")
        container.addArrangedSubview(titleLabel)

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.contentInset = UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let monogramStack = UIStackView()
        monogramStack.axis = .horizontal
        monogramStack.spacing = 40
        monogramStack.alignment = .center
        monogramStack.distribution = .fillProportionally
        monogramStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(monogramStack)

        NSLayoutConstraint.activate([
            monogramStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            monogramStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            monogramStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            monogramStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            monogramStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        for member in cast.prefix(8) {
            let monogram = makeCastItemView(for: member)
            monogramStack.addArrangedSubview(monogram)
        }

        container.addArrangedSubview(scrollView)
        return container
    }

    private func makeCastItemView(for member: CastMember) -> TVMonogramContentView {
        let character = member.character?.trimmingCharacters(in: .whitespacesAndNewlines)
        var configuration = TVMonogramContentConfiguration.cell()
        configuration.text = member.name
        if let character, !character.isEmpty {
            configuration.secondaryText = character
        }

        let monogram = TVMonogramContentView(configuration: configuration)
        monogram.translatesAutoresizingMaskIntoConstraints = false
        monogram.widthAnchor.constraint(equalToConstant: 180).isActive = true
        monogram.heightAnchor.constraint(equalToConstant: 180).isActive = true

        if let profilePath = member.profilePath {
            let urlString = profilePath.hasPrefix("http")
                ? profilePath
                : (MovieDataService.shared.getPosterURL(path: profilePath, size: .small) ?? profilePath)
            if let url = URL(string: urlString) {
                if let cached = ImageCache.shared.getImage(for: url) {
                    var updated = configuration
                    updated.image = cached
                    monogram.configuration = updated
                } else {
                    Task.detached { [weak monogram] in
                        await ImageCache.shared.prefetchImage(from: url)
                        guard let cached = ImageCache.shared.getImage(for: url) else { return }
                        await MainActor.run {
                            guard let monogram else { return }
                            var updated = configuration
                            updated.image = cached
                            monogram.configuration = updated
                        }
                    }
                }
            }
        }

        return monogram
    }

    private func makeFocusableBodyLabel(_ text: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = text
        configuration.baseForegroundColor = .lightGray
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        configuration.titleLineBreakMode = .byWordWrapping
        button.configuration = configuration
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.contentHorizontalAlignment = .leading
        button.isUserInteractionEnabled = true
        return button
    }

    private func makeFocusableKeyValueRow(title: String, value: String) -> UIStackView {
        let titleLabel = makeSecondaryLabel("\(title):")
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueButton = makeFocusableBodyLabel(value)
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        return stack
    }
}

private final class TVHeroGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradientLayer.locations = [0.3, 1.0]
        layer.addSublayer(gradientLayer)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private final class TVNonFocusableView: UIView {
    override var canBecomeFocused: Bool { false }
}

private final class TVNonFocusablePosterView: TVPosterView {
    override var canBecomeFocused: Bool { false }
}

private struct StreamingServiceLink {
    let appURL: URL?
    let fallbackAppURL: URL?
    let webURL: URL?
}

private enum StreamingServiceLinkBuilder {
    static func link(for service: StreamingService, movieTitle: String, tmdbId: Int?) -> StreamingServiceLink {
        let trimmedName = service.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let query = movieTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? movieTitle

        var appURL: URL?
        var fallbackAppURL: URL?
        var webURL: URL? = service.url.flatMap { URL(string: $0) }

        switch trimmedName {
        case "netflix":
            appURL = URL(string: "nflx://www.netflix.com/search?q=\(query)")
            webURL = webURL ?? URL(string: "https://www.netflix.com/search?q=\(query)")
        case "netflix standard with ads":
            appURL = URL(string: "nflx://www.netflix.com/search?q=\(query)")
            webURL = webURL ?? URL(string: "https://www.netflix.com/search?q=\(query)")
        case "amazon prime video", "amazon prime video with ads", "amazon video", "prime video":
            appURL = URL(string: "primevideo://search?keyword=\(query)")
            webURL = webURL ?? URL(string: "https://www.amazon.com/s?k=\(query)&i=instant-video")
        case "apple tv", "apple tv+", "apple tv plus":
            appURL = URL(string: "tv://search?term=\(query)")
            webURL = webURL ?? URL(string: "https://tv.apple.com/search?term=\(query)")
        case "disney plus", "disney+":
            appURL = URL(string: "disneyplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.disneyplus.com/search?q=\(query)")
        case "hbo max", "max":
            appURL = URL(string: "max://search?query=\(query)")
            fallbackAppURL = URL(string: "hbomax://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://play.max.com/search?q=\(query)")
        case "hulu":
            appURL = URL(string: "hulu://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.hulu.com/search?q=\(query)")
        case "paramount plus", "paramount+":
            appURL = URL(string: "paramountplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.paramountplus.com/search/titles/?query=\(query)")
        case "peacock premium", "peacock premium plus", "peacock":
            appURL = URL(string: "peacock://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.peacocktv.com/search?query=\(query)")
        case "youtube":
            appURL = URL(string: "youtube://results?search_query=\(query)")
            webURL = webURL ?? URL(string: "https://www.youtube.com/results?search_query=\(query)")
        case "google play movies":
            appURL = URL(string: "playmovies://search?q=\(query)")
            webURL = webURL ?? URL(string: "https://play.google.com/store/search?q=\(query)&c=movies")
        case "fandango at home", "vudu":
            appURL = URL(string: "vudu://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.vudu.com/content/movies/search?minVisible=0&offset=0&searchString=\(query)")
        case "plex":
            appURL = URL(string: "plex://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://watch.plex.tv/search?query=\(query)")
        case "mgm plus":
            appURL = URL(string: "mgmplus://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.mgmplus.com/search?query=\(query)")
        case "starz":
            appURL = URL(string: "starz://search?query=\(query)")
            webURL = webURL ?? URL(string: "https://www.starz.com/us/en/search?searchTerm=\(query)")
        default:
            break
        }

        if webURL == nil, let tmdbId = tmdbId {
            webURL = URL(string: "https://www.themoviedb.org/movie/\(tmdbId)/watch")
        }

        return StreamingServiceLink(appURL: appURL, fallbackAppURL: fallbackAppURL, webURL: webURL)
    }
}
