//
//  TVMovieCollectionViewCell.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import TVUIKit
import WatchedItCore

final class TVMovieCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "TVMovieCollectionViewCell"

    private let posterView = TVPosterView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        posterView.image = nil
        posterView.title = nil
    }

    func configure(with movie: Movie) {
        posterView.title = movie.title
        if let posterPath = movie.posterPath,
           let posterURLString = MovieDataService.shared.getPosterURL(path: posterPath, size: .small),
           let url = URL(string: posterURLString) {
            if let cached = ImageCache.shared.getImage(for: url) {
                posterView.image = cached
            } else {
                posterView.image = nil
                Task.detached {
                    await ImageCache.shared.prefetchImage(from: url)
                    let cached = ImageCache.shared.getImage(for: url)
                    await MainActor.run {
                        self.posterView.image = cached
                    }
                }
            }
        }
    }

    private func configureViews() {
        posterView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(posterView)
        NSLayoutConstraint.activate([
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            posterView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
