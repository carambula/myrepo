import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { closePool, query } from "./db.js";
import { defaultMigrationsDir, runMigrations } from "./migrate.js";
import { movieIdFromTmdb, podcastIdFromItunes } from "./lib/passwords.js";

const here = path.dirname(fileURLToPath(import.meta.url));

const seedMovies = async () => {
  const raw = await fs.readFile(path.resolve(here, "../fixtures/sample-movies.json"), "utf8");
  const payload = JSON.parse(raw) as {
    dataSources: Array<{
      identifier: string;
      name: string;
      type: string;
      url?: string | null;
      isRankedList?: boolean;
      movieCount?: number;
    }>;
    movies: Array<{
      id?: string;
      title: string;
      tmdbId?: number;
      year?: number;
      posterPath?: string | null;
      backdropPath?: string | null;
      overview?: string | null;
      mpaaRating?: string | null;
      genres?: string[];
      streamingServices?: unknown[];
      sourceIdentifier?: string;
      rank?: number | null;
      sourceTitle?: string | null;
    }>;
  };
  for (const source of payload.dataSources) {
    await query(
      `
      INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, movie_count, updated_at)
      VALUES ($1,$2,$3,$4,$5,TRUE,$6,NOW())
      ON CONFLICT (identifier) DO UPDATE SET name = EXCLUDED.name, url = EXCLUDED.url, updated_at = NOW()
      `,
      [
        source.identifier,
        source.name,
        source.type,
        source.url ?? null,
        Boolean(source.isRankedList),
        source.movieCount ?? 0
      ]
    );
  }
  for (const movie of payload.movies) {
    const tmdbId = movie.tmdbId ? Number(movie.tmdbId) : null;
    const id = String(movie.id || (tmdbId ? movieIdFromTmdb(tmdbId) : movie.title));
    await query(
      `
      INSERT INTO mov_movies (id, tmdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating, genres, last_updated)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,NOW())
      ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, last_updated = NOW()
      `,
      [
        id,
        tmdbId,
        movie.title,
        movie.year ?? null,
        movie.posterPath ?? null,
        movie.backdropPath ?? null,
        movie.overview ?? null,
        movie.mpaaRating ?? null,
        JSON.stringify(movie.genres ?? [])
      ]
    );
    if (Array.isArray(movie.streamingServices) && movie.streamingServices.length) {
      await query(
        `
        INSERT INTO mov_streaming (movie_id, region, providers, refreshed_at)
        VALUES ($1, 'US', $2::jsonb, NOW())
        ON CONFLICT (movie_id, region) DO UPDATE SET providers = EXCLUDED.providers
        `,
        [id, JSON.stringify(movie.streamingServices)]
      );
    }
    if (movie.sourceIdentifier) {
      await query(
        `
        INSERT INTO mov_movie_sources (movie_id, source_id, rank, source_title)
        VALUES ($1,$2,$3,$4)
        ON CONFLICT (movie_id, source_id) DO NOTHING
        `,
        [id, movie.sourceIdentifier, movie.rank ?? null, movie.sourceTitle ?? null]
      );
    }
  }
};

const seedPodcasts = async () => {
  const raw = await fs.readFile(path.resolve(here, "../fixtures/sample-podcasts.json"), "utf8");
  const payload = JSON.parse(raw) as {
    categories: Array<{ name: string; podcasts: Array<{ itunesID: string; name: string }> }>;
  };
  for (const [index, category] of payload.categories.entries()) {
    await query(
      `INSERT INTO pod_categories (name, sort_order) VALUES ($1, $2) ON CONFLICT (name) DO NOTHING`,
      [category.name, index]
    );
    for (const podcast of category.podcasts) {
      const id = podcastIdFromItunes(podcast.itunesID);
      await query(
        `
        INSERT INTO pod_podcasts (id, itunes_id, title, author, feed_url, categories, updated_at)
        VALUES ($1,$2,$3,'', $4, $5::jsonb, NOW())
        ON CONFLICT (id) DO UPDATE SET categories = EXCLUDED.categories
        `,
        [id, podcast.itunesID, podcast.name, `itunes://${podcast.itunesID}`, JSON.stringify([category.name])]
      );
    }
  }
};

const run = async () => {
  await runMigrations(defaultMigrationsDir());
  await seedMovies();
  await seedPodcasts();
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW()`);
  console.log("Seeded Min Cloud sample catalog.");
};

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
