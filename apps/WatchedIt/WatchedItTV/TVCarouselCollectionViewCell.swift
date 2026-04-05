//
//  TVCarouselCollectionViewCell.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import WatchedItCore

final class TVCarouselCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "TVCarouselCollectionViewCell"

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

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
        imageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }

    func configure(with movie: Movie) {
        titleLabel.text = movie.title
        if let year = movie.year {
            subtitleLabel.text = String(year)
        }

        if let imagePath = movie.backdropPath ?? movie.posterPath,
           let urlString = MovieDataService.shared.getBackdropURL(path: imagePath),
           let url = URL(string: urlString) {
            if let cached = ImageCache.shared.getImage(for: url) {
                imageView.image = cached
            } else {
                Task.detached {
                    await ImageCache.shared.prefetchImage(from: url)
                    let cached = ImageCache.shared.getImage(for: url)
                    await MainActor.run {
                        self.imageView.image = cached
                    }
                }
            }
        }
    }

    private func configureViews() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .lightGray

        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.layer.cornerRadius = 10
        overlay.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 8),
            textStack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -8)
        ])

        imageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageView)
        contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            overlay.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
        ])
    }
}
