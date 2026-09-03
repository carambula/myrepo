//
//  TVSearchResultsViewController.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import WatchedItCore

final class TVSearchResultsViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Movie>!
    private var movies: [Movie] = []

    var onSelectMovie: ((Movie) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCollectionView()
        configureDataSource()
    }

    func updateResults(_ movies: [Movie]) {
        self.movies = movies
        applySnapshot()
    }

    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 24
        layout.minimumLineSpacing = 32
        layout.sectionInset = UIEdgeInsets(top: 24, left: 24, bottom: 48, right: 24)
        let itemWidth: CGFloat = 240
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth * 1.5 + 40)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self

        collectionView.register(
            TVMovieCollectionViewCell.self,
            forCellWithReuseIdentifier: TVMovieCollectionViewCell.reuseIdentifier
        )

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, Movie>(
            collectionView: collectionView
        ) { collectionView, indexPath, movie in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TVMovieCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? TVMovieCollectionViewCell
            cell?.configure(with: movie)
            return cell
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Movie>()
        snapshot.appendSections([0])
        snapshot.appendItems(movies, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension TVSearchResultsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let movie = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelectMovie?(movie)
    }
}
