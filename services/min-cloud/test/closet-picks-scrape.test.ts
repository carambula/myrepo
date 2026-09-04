import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";
import {
  collapseClosetPicks,
  formatClosetPicksDescription,
  guestNameFromEpisodeTitle,
  isClosetPicksIndexUrl,
  isClosetPicksUrl,
  parseClosetPicksEpisode,
  parseClosetPicksIndex,
  parseClosetPicksCreditLine,
  parseCriterionFilmPage,
  shouldSkipClosetPicksFilmTitle,
  toClosetPicksCatalogItem
} from "../src/lib/closet-picks-scrape.ts";

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures");
const indexHtml = readFileSync(path.join(fixtures, "closet-picks-index.html"), "utf8");
const episodeHtml = readFileSync(path.join(fixtures, "closet-picks-episode.html"), "utf8");

describe("closet-picks scrape", () => {
  it("recognizes index and episode URLs", () => {
    assert.equal(isClosetPicksIndexUrl("https://www.criterion.com/closet-picks"), true);
    assert.equal(isClosetPicksIndexUrl("https://www.criterion.com/closet-picks/matthew-mcconaughey"), false);
    assert.equal(isClosetPicksUrl("https://www.criterion.com/closet-picks"), true);
    assert.equal(
      isClosetPicksUrl("https://www.criterion.com/shop/collection/763-francis-ford-coppola-s-closet-picks"),
      true
    );
    assert.equal(isClosetPicksUrl("https://www.imdb.com/list/ls042702401/"), false);
  });

  it("parses guest names from episode titles", () => {
    assert.equal(guestNameFromEpisodeTitle("Matthew McConaughey’s Closet Picks"), "Matthew McConaughey");
    assert.equal(guestNameFromEpisodeTitle("Andrew Stanton's Closet Picks"), "Andrew Stanton");
  });

  it("formats guests as a source-link description", () => {
    assert.equal(formatClosetPicksDescription(["Matthew McConaughey"]), "Matthew McConaughey");
    assert.equal(
      formatClosetPicksDescription(["Matthew McConaughey", "Christopher Nolan", "Adam Scott"]),
      "Matthew McConaughey   also Christopher Nolan, Adam Scott"
    );
  });

  it("skips collector sets and shop chrome", () => {
    assert.equal(shouldSkipClosetPicksFilmTitle("Watch & shop"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("The Wes Anderson Archive Collector’s Set"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("The Complete Jacques Tati"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("Rumble Fish"), false);
    assert.equal(shouldSkipClosetPicksFilmTitle("Released Dec 10, 2024"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("Available Feb 4, 2025"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("Available now"), true);
    assert.equal(shouldSkipClosetPicksFilmTitle("Available Mar 4, 2025"), true);
  });

  it("reads director and year from a credit line", () => {
    assert.deepEqual(parseClosetPicksCreditLine("Francis Ford Coppola"), {
      director: "Francis Ford Coppola",
      year: null
    });
    assert.deepEqual(parseClosetPicksCreditLine("Charles Chaplin, 1921"), {
      director: "Charles Chaplin",
      year: 1921
    });
  });

  it("parses episode cards from the index", () => {
    const episodes = parseClosetPicksIndex(indexHtml);
    assert.equal(episodes.length, 3);
    assert.equal(episodes[0].guestName, "Francis Ford Coppola");
    assert.equal(episodes[0].episodeTitle, "Francis Ford Coppola’s Closet Picks");
    assert.equal(
      episodes[0].episodeUrl,
      "https://www.criterion.com/shop/collection/763-francis-ford-coppola-s-closet-picks"
    );
    assert.equal(episodes[2].episodeUrl, "https://www.criterion.com/closet-picks/matthew-mcconaughey");
  });

  it("extracts films and skips box sets", () => {
    const films = parseClosetPicksEpisode(episodeHtml);
    assert.deepEqual(
      films.map((film) => film.title),
      ["Rumble Fish", "Dance, Girl, Dance"]
    );
    assert.equal(films[0].director, "Francis Ford Coppola");
    assert.equal(films[0].filmUrl, "https://www.criterion.com/films/28993-rumble-fish");
    assert.equal(films[1].director, "Dorothy Arzner");
  });

  it("reads year and director from a Criterion film page", () => {
    const filmHtml = readFileSync(path.join(fixtures, "criterion-film-page.html"), "utf8");
    const parsed = parseCriterionFilmPage(filmHtml);
    assert.equal(parsed.title, "Rumble Fish");
    assert.equal(parsed.year, 1983);
    assert.equal(parsed.director, "Francis Ford Coppola");
  });

  it("collapses repeats to unique films ranked by pick count", () => {
    const collapsed = collapseClosetPicks([
      {
        episode: {
          guestName: "Matthew McConaughey",
          episodeTitle: "Matthew McConaughey’s Closet Picks",
          episodeUrl: "https://www.criterion.com/closet-picks/matthew-mcconaughey",
          date: "2026-02-01"
        },
        films: [
          { title: "8½", filmUrl: "https://www.criterion.com/films/8-12", director: "Federico Fellini", year: 1963 },
          { title: "Rumble Fish", filmUrl: "https://www.criterion.com/films/28993-rumble-fish", director: "Francis Ford Coppola", year: 1983 }
        ]
      },
      {
        episode: {
          guestName: "Francis Ford Coppola",
          episodeTitle: "Francis Ford Coppola’s Closet Picks",
          episodeUrl: "https://www.criterion.com/shop/collection/763-francis-ford-coppola-s-closet-picks",
          date: "2025-01-01"
        },
        films: [
          { title: "Rumble Fish", filmUrl: null, director: "Francis Ford Coppola", year: 1983 },
          { title: "Dance, Girl, Dance", filmUrl: "https://www.criterion.com/films/29633-dance-girl-dance", director: "Dorothy Arzner", year: 1940 }
        ]
      }
    ]);

    assert.equal(collapsed[0].title, "Rumble Fish");
    assert.equal(collapsed[0].rank, 1);
    assert.equal(collapsed[0].pickCount, 2);
    assert.equal(collapsed[0].sourceTitle, "Matthew McConaughey’s Closet Picks");
    assert.equal(collapsed[0].description, "Matthew McConaughey   also Francis Ford Coppola");
    assert.equal(collapsed[1].pickCount, 1);
    assert.equal(collapsed[2].pickCount, 1);

    const item = toClosetPicksCatalogItem(collapsed[0]);
    assert.equal(item.sourceIdentifier, "criterion-closet-picks");
    assert.equal(item.podcastEpisodeDescription, collapsed[0].description);
    assert.equal(item.sourceTitle, collapsed[0].sourceTitle);
    assert.equal(item.director, "Francis Ford Coppola");
    assert.equal(item.year, 1983);
    assert.equal(item.filmUrl, "https://www.criterion.com/films/28993-rumble-fish");
  });
});
