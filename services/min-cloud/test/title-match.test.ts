import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { scrapeListItems } from "../src/lib/list-scrape.ts";
import {
  buildTmdbSearchInput,
  cleanPodcastTitle,
  cleanTitle,
  determineItemStatus,
  extractLanguageHint,
  extractPersonNames,
  extractYearFromDescription,
  matchNeedsCreditCheck,
  pickBestTmdbMatch,
  prepareMovieQuery,
  scoreTmdbMatch,
  shouldSkipPodcastNoise,
  decidePodcastEpisodeIngest,
  episodeTitleNamesMovie,
  extractQuotedMovieTitles,
  isBrunchPodcastNoiseTitle,
  isAvailabilityBlurbTitle,
  isCatalogReadyToShip,
  pickConfidentTmdbMatch
} from "../src/lib/title-match.ts";

describe("title cleaning and matching", () => {
  it("strips guest lists and quotes from Rewatchables titles", () => {
    assert.equal(
      cleanPodcastTitle("‘Toy Story 5’ With Bill Simmons, Chris Ryan, and Van Lathan"),
      "Toy Story 5"
    );
    assert.equal(cleanPodcastTitle("'Taxi Driver' With Bill Simmons and Chris Ryan"), "Taxi Driver");
    assert.equal(cleanPodcastTitle("Heat (1995)"), "Heat");
    assert.equal(
      cleanPodcastTitle("Gone with the Wind With Bill Simmons and Chris Ryan"),
      "Gone with the Wind"
    );
    assert.equal(cleanPodcastTitle("The Man with the Golden Gun"), "The Man with the Golden Gun");
    assert.equal(cleanPodcastTitle("Mission: Impossible - Fallout"), "Mission: Impossible - Fallout");
    assert.equal(cleanPodcastTitle("The Rewatchables: Heat — with Bill Simmons"), "Heat");
  });

  it("does not treat franchise numbers as list numbering", () => {
    assert.equal(cleanTitle("10 Things I Hate About You"), "10 Things I Hate About You");
    assert.equal(cleanTitle("7. How to Lose a Guy in 10 Days"), "How to Lose a Guy in 10 Days");
  });

  it("builds a TMDB query and year from a cleaned title", () => {
    const prepared = prepareMovieQuery(
      "‘Toy Story 5’ With Bill Simmons, Chris Ryan, and Van Lathan",
      "The 2026 film from Pixar."
    );
    assert.equal(prepared.title, "Toy Story 5");
    assert.equal(prepared.query, "Toy Story 5");
    assert.equal(prepared.year, 2026);
    assert.equal(prepared.sourceTitle.includes("With Bill Simmons"), true);
  });

  it("extracts a trailing year for search without leaving it in the query", () => {
    const input = buildTmdbSearchInput("The Thing (1982)");
    assert.equal(input.query, "The Thing");
    assert.equal(input.year, 1982);
  });

  it("picks the exact title over a franchise sibling", () => {
    const match = pickBestTmdbMatch("Toy Story 5", [
      { id: 862, title: "Toy Story", release_date: "1995-11-22", poster_path: "/a.jpg" },
      { id: 106448, title: "Toy Story 5", release_date: "2026-06-19", poster_path: "/b.jpg" }
    ]);
    assert.equal(match?.id, 106448);
  });

  it("reads year and language from editorial copy instead of the first calendar year", () => {
    assert.equal(
      extractYearFromDescription("They compare it to something from 1973, but this is the 2003 Korean film starring Choi Min-sik."),
      2003
    );
    assert.equal(extractLanguageHint("the 2003 Korean film starring Choi Min-sik"), "ko");
    assert.deepEqual(
      extractPersonNames("starring Choi Min-sik and directed by Park Chan-wook").sort(),
      ["Choi Min-sik", "Park Chan-wook"]
    );
  });

  it("prefers the year hint when titles collide", () => {
    const match = pickBestTmdbMatch("Dune", [
      { id: 841, title: "Dune", release_date: "1984-12-14", poster_path: "/a.jpg" },
      { id: 438631, title: "Dune", release_date: "2021-10-22", poster_path: "/b.jpg" }
    ], 2021);
    assert.equal(match?.id, 438631);
  });

  it("uses language and cast to separate same-name Asian titles and remakes", () => {
    const oldboy2003 = {
      id: 670,
      title: "Oldboy",
      original_title: "올드보이",
      original_language: "ko",
      release_date: "2003-11-21",
      poster_path: "/a.jpg",
      overview: "Oh Dae-su is imprisoned."
    };
    const oldboy2013 = {
      id: 87516,
      title: "Oldboy",
      original_title: "Oldboy",
      original_language: "en",
      release_date: "2013-11-27",
      poster_path: "/b.jpg",
      overview: "An American remake."
    };
    const korean = pickBestTmdbMatch("Oldboy", [oldboy2013, oldboy2003], {
      year: 2003,
      language: "ko",
      people: ["Choi Min-sik"],
      creditsById: {
        670: { names: ["Choi Min-sik", "Park Chan-wook"] },
        87516: { names: ["Josh Brolin", "Spike Lee"] }
      }
    });
    assert.equal(korean?.id, 670);
    const remake = pickBestTmdbMatch("Oldboy", [oldboy2003, oldboy2013], {
      year: 2013,
      era: "remake",
      people: ["Josh Brolin"],
      creditsById: {
        670: { names: ["Choi Min-sik"] },
        87516: { names: ["Josh Brolin", "Spike Lee"] }
      }
    });
    assert.equal(remake?.id, 87516);
  });

  it("asks for credit checks when same-title years collide", () => {
    assert.equal(
      matchNeedsCreditCheck(
        "The Host",
        [
          { id: 1, title: "The Host", release_date: "2006-07-27" },
          { id: 2, title: "The Host", release_date: "2013-03-29" }
        ],
        { people: ["Song Kang-ho"] }
      ),
      true
    );
  });

  it("does not let a historic aside beat the film being discussed", () => {
    assert.equal(
      extractYearFromDescription(
        "They mention something from 1942, then get into the 1973 film starring Steve McQueen."
      ),
      1973
    );
    assert.equal(
      extractYearFromDescription("This week's movie is the 2003 Korean film. They compare it to the 2013 remake."),
      2003
    );
  });

  it("marks core metadata as enriched and skips Big Picture noise", () => {
    assert.equal(
      determineItemStatus({
        tmdbId: 275,
        year: 1976,
        posterPath: "/x.jpg",
        overview: "A night in New York.",
        genres: ["Crime"]
      }),
      "enriched"
    );
    assert.equal(determineItemStatus({ tmdbId: 275, year: null, posterPath: null, overview: null, genres: [] }), "light");
    assert.equal(shouldSkipPodcastNoise("big-picture", "Oscars Mailbag 2026", "Oscars Mailbag 2026"), true);
    assert.equal(shouldSkipPodcastNoise("big-picture", "Heat", "Heat"), true);
    assert.equal(
      shouldSkipPodcastNoise("big-picture", "‘Sinners’ Is for the Sickos, the Cinephiles and You, with Ryan Coogler!", "Sinners"),
      false
    );
    assert.equal(shouldSkipPodcastNoise("big-picture", "The Flops Movie Draft", "The Flops Movie Draft"), true);
    assert.equal(shouldSkipPodcastNoise("big-picture", "Eli Roth!", "Eli Roth!"), true);
    assert.equal(
      shouldSkipPodcastNoise("big-picture", "Movie Swap: 'Aliens' vs. 'Four Weddings and a Funeral'", "Aliens"),
      true
    );
  });

  it("skips Confused Breakfast BRUNCH bonuses and keeps Thursday reviews", () => {
    assert.equal(
      shouldSkipPodcastNoise(
        "confused-breakfast",
        "BRUNCH: Talking Movies With Our DADS!",
        "BRUNCH: Talking Movies With Our DADS!"
      ),
      true
    );
    assert.equal(
      shouldSkipPodcastNoise(
        "confused-breakfast",
        "BRUNCH- We Got These Movie Ratings WRONG...",
        "BRUNCH- We Got These Movie Ratings WRONG..."
      ),
      true
    );
    assert.equal(
      shouldSkipPodcastNoise(
        "confused-breakfast",
        "The Shawshank Redemption (1994)",
        "The Shawshank Redemption"
      ),
      false
    );
    assert.equal(isBrunchPodcastNoiseTitle("The Confused Breakfast: BRUNCH: Talking Movies"), true);
    assert.equal(isBrunchPodcastNoiseTitle("The Shawshank Redemption"), false);
    assert.equal(
      shouldSkipPodcastNoise("confused-breakfast", "Mailbag: Listener Letters", "Mailbag: Listener Letters"),
      true
    );
  });

  it("skips availability blurbs from any source and keeps real movie titles", () => {
    assert.equal(
      shouldSkipPodcastNoise("criterion-closet-picks", "Available January 15, 2025", "Available January 15, 2025"),
      true
    );
    assert.equal(shouldSkipPodcastNoise("rewatchables", "Available now", "Available now"), true);
    assert.equal(shouldSkipPodcastNoise("criterion-closet-picks", "Available March 4", "Available March 4"), true);
    assert.equal(shouldSkipPodcastNoise("criterion-closet-picks", "Available 4/15/26", "Available 4/15/26"), true);
    assert.equal(shouldSkipPodcastNoise("criterion-closet-picks", "Available Feb 4, 2025", "Available Feb 4, 2025"), true);
    assert.equal(
      shouldSkipPodcastNoise("criterion-closet-picks", "Released Dec 10, 2024", "Released Dec 10, 2024"),
      true
    );
    assert.equal(shouldSkipPodcastNoise("rewatchables", "The Shawshank Redemption", "The Shawshank Redemption"), false);
    assert.equal(shouldSkipPodcastNoise("rewatchables", "Heat", "Heat"), false);
    assert.equal(isAvailabilityBlurbTitle("Available January 15, 2025"), true);
    assert.equal(isAvailabilityBlurbTitle("Available now"), true);
    assert.equal(isAvailabilityBlurbTitle("The Shawshank Redemption"), false);
    assert.equal(isAvailabilityBlurbTitle("Heat"), false);
    assert.equal(isAvailabilityBlurbTitle("Everything Available"), false);
  });

  it("does not insert unmatched RSS leftovers as catalog stubs", () => {
    const existing = new Set<string>();
    assert.deepEqual(
      decidePodcastEpisodeIngest({
        sourceTitle: "BRUNCH: Talking Movies With Our DADS!",
        sourceIdentifier: "confused-breakfast",
        existingTitles: existing,
        preparedTitle: "BRUNCH: Talking Movies With Our DADS!"
      }),
      { action: "skip", reason: "noise" }
    );
    assert.deepEqual(
      decidePodcastEpisodeIngest({
        sourceTitle: "An Obscure Topic Episode",
        sourceIdentifier: "confused-breakfast",
        existingTitles: existing,
        preparedTitle: "An Obscure Topic Episode",
        match: null
      }),
      { action: "skip", reason: "unmatched" }
    );
    assert.deepEqual(
      decidePodcastEpisodeIngest({
        sourceTitle: "The Shawshank Redemption (1994)",
        sourceIdentifier: "confused-breakfast",
        existingTitles: existing,
        preparedTitle: "The Shawshank Redemption",
        match: { id: 278 },
        posterPath: "/shawshank.jpg"
      }),
      { action: "upsert" }
    );
    assert.deepEqual(
      decidePodcastEpisodeIngest({
        sourceTitle: "Available Feb 4, 2025",
        sourceIdentifier: "criterion-closet-picks",
        existingTitles: existing,
        preparedTitle: "Available Feb 4, 2025",
        match: { id: 1 }
      }),
      { action: "skip", reason: "noise" }
    );
    assert.deepEqual(
      decidePodcastEpisodeIngest({
        sourceTitle: "‘Sinners’ Is for the Sickos",
        sourceIdentifier: "big-picture",
        existingTitles: existing,
        preparedTitle: "Sinners",
        match: { id: 1233413 },
        posterPath: null
      }),
      { action: "skip", reason: "data-poor" }
    );
  });

  it("requires a TMDB id and poster before a movie can ship", () => {
    assert.equal(isCatalogReadyToShip({ tmdbId: 679, posterPath: "/aliens.jpg" }), true);
    assert.equal(isCatalogReadyToShip({ tmdbId: null, posterPath: "/aliens.jpg" }), false);
    assert.equal(isCatalogReadyToShip({ tmdbId: 679, posterPath: "" }), false);
    assert.equal(isCatalogReadyToShip({ tmdbId: 679, posterPath: null }), false);
  });

  it("only attaches a podcast when the episode names that movie", () => {
    assert.equal(
      episodeTitleNamesMovie("‘Sinners’ Is for the Sickos, the Cinephiles and You, with Ryan Coogler!", "Sinners"),
      true
    );
    assert.equal(episodeTitleNamesMovie("‘Aliens’ With Bill Simmons and Chris Ryan", "Aliens"), true);
    assert.equal(episodeTitleNamesMovie("", "Aliens"), false);
    assert.equal(extractQuotedMovieTitles("Interview With ‘20th Century Women’ Director Mike Mills").includes("20th Century Women"), true);
    assert.equal(
      pickConfidentTmdbMatch("The Flops Movie Draft", [
        { id: 11, title: "Star Wars", release_date: "1977-05-25", poster_path: "/x.jpg", popularity: 80 }
      ]),
      null
    );
    assert.equal(
      pickConfidentTmdbMatch("Sinners", [
        { id: 1233413, title: "Sinners", release_date: "2025-04-18", poster_path: "/s.jpg" }
      ])?.id,
      1233413
    );
  });

  it("scrapes IMDb title links and skips chrome", () => {
    const items = scrapeListItems(
      "https://www.imdb.com/list/ls042702401/",
      `<a href="/title/tt0075314/">Taxi Driver</a><a href="/chart">IMDb</a><a href="/title/tt0114709/">Toy Story</a><a href="/title/tt0000001/">Available Feb 4, 2025</a>`
    );
    assert.deepEqual(items.map((item) => item.title), ["Taxi Driver", "Toy Story"]);
  });
});
