import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  attachResolvedTicketLinks,
  catalogFromUrls,
  extractSitemapLocs,
  loadTicketSiteCatalogs,
  matchTicketUrl,
  mergeTicketLinks,
  parseSlugYear,
  resetTicketLinkCatalogCacheForTests,
  titleToSlug
} from "../src/lib/ticket-link-resolve.ts";
import { yearFromReleaseDate } from "../src/lib/now-playing.ts";

const catalogs = {
  amc: catalogFromUrls("amc", [
    "https://www.amctheatres.com/movies/how-to-train-your-dragon-83807",
    "https://www.amctheatres.com/movies/sinners-82556",
    "https://www.amctheatres.com/movies/sinners-82542",
    "https://www.amctheatres.com/movies/sinners-imax-reissue-81858",
    "https://www.amctheatres.com/movies/superman-2025-ohio-goes-to-the-movies-84234",
    "https://www.amctheatres.com/movies/f1-the-movie-82699"
  ]),
  fandango: catalogFromUrls("fandango", [
    "https://www.fandango.com/superman-2025-230934/movie-overview",
    "https://www.fandango.com/weapons-2025-240417/movie-overview",
    "https://www.fandango.com/the-naked-gun-1988-3172/movie-overview",
    "https://www.fandango.com/the-naked-gun-2025-240147/movie-overview",
    "https://www.fandango.com/together-2021-225389/movie-overview",
    "https://www.fandango.com/together-2025-240616/movie-overview",
    "https://www.fandango.com/f1-the-movie-2025-236966/movie-overview",
    "https://www.fandango.com/double-feature-together-2025--weapons-2025-241893/movie-overview",
    "https://www.fandango.com/sinners-2025-237956/movie-overview",
    "https://www.fandango.com/sinners-early-access-imax-70mm-screenings-2025-240020/movie-overview"
  ]),
  atom: catalogFromUrls("atom", [
    "https://www.atomtickets.com/movies/superman/343208",
    "https://www.atomtickets.com/movies/sinners/358801",
    "https://www.atomtickets.com/movies/batman-v-superman-dawn-of-justice/178752"
  ])
};

describe("ticket link sitemap matching", () => {
  it("slugifies titles and strips trailing ids or years", () => {
    assert.equal(titleToSlug("The Fantastic Four: First Steps"), "the-fantastic-four-first-steps");
    assert.equal(titleToSlug("F1"), "f1");
    assert.deepEqual(parseSlugYear("superman-2025-230934"), { slug: "superman", year: 2025 });
    assert.deepEqual(parseSlugYear("how-to-train-your-dragon-83807"), { slug: "how-to-train-your-dragon" });
    assert.deepEqual(parseSlugYear("how-to-train-your-dragon-2", { stripNumericId: false }), {
      slug: "how-to-train-your-dragon-2"
    });
    assert.equal(yearFromReleaseDate("2025-07-11"), 2025);
    assert.equal(yearFromReleaseDate("nope"), undefined);
  });

  it("reads loc entries from a sitemap or sitemap index", () => {
    assert.deepEqual(
      extractSitemapLocs(
        `<sitemapindex><sitemap><loc>https://www.fandango.com/sitemap-movies-01.xml</loc></sitemap></sitemapindex>`
      ),
      { sitemaps: ["https://www.fandango.com/sitemap-movies-01.xml"], urls: [] }
    );
    assert.deepEqual(
      extractSitemapLocs(`<urlset><url><loc>https://www.amctheatres.com/movies/sinners-82556</loc></url></urlset>`),
      { sitemaps: [], urls: ["https://www.amctheatres.com/movies/sinners-82556"] }
    );
  });

  it("picks a unique current title and uses year when the name is reused", () => {
    assert.equal(
      matchTicketUrl("Superman", 2025, catalogs.fandango),
      "https://www.fandango.com/superman-2025-230934/movie-overview"
    );
    assert.equal(
      matchTicketUrl("The Naked Gun", 2025, catalogs.fandango),
      "https://www.fandango.com/the-naked-gun-2025-240147/movie-overview"
    );
    assert.equal(matchTicketUrl("The Naked Gun", undefined, catalogs.fandango), undefined);
    assert.equal(matchTicketUrl("Together", 2025, catalogs.fandango), "https://www.fandango.com/together-2025-240616/movie-overview");
    assert.equal(
      matchTicketUrl("Sinners", 2025, catalogs.fandango),
      "https://www.fandango.com/sinners-2025-237956/movie-overview"
    );
  });

  it("skips ambiguous AMC rows and event pages", () => {
    assert.equal(matchTicketUrl("Sinners", 2025, catalogs.amc), undefined);
    assert.equal(matchTicketUrl("Superman", 2025, catalogs.amc), undefined);
    assert.equal(
      matchTicketUrl("How to Train Your Dragon", 2025, catalogs.amc),
      "https://www.amctheatres.com/movies/how-to-train-your-dragon-83807"
    );
    assert.equal(matchTicketUrl("Superman", 2025, catalogs.atom), "https://www.atomtickets.com/movies/superman/343208");
    assert.equal(
      matchTicketUrl("How to Train Your Dragon", 2025, [
        ...catalogs.atom,
        ...catalogFromUrls("atom", ["https://www.atomtickets.com/movies/how-to-train-your-dragon-2/389861"])
      ]),
      undefined
    );
  });

  it("matches an alternate title such as F1 The Movie", () => {
    assert.equal(matchTicketUrl("F1", 2025, catalogs.fandango), undefined);
    assert.equal(
      matchTicketUrl("F1", 2025, catalogs.fandango, ["F1 The Movie"]),
      "https://www.fandango.com/f1-the-movie-2025-236966/movie-overview"
    );
  });

  it("keeps stored links and fills the missing sites", async () => {
    const existingAmc = "https://www.amctheatres.com/movies/how-to-train-your-dragon-83807/showtimes";
    const { stays, withTicketLinks } = await attachResolvedTicketLinks(
      [
        {
          tmdbId: 1,
          title: "Superman",
          hasIMAX: true,
          inCatalog: true,
          manualOverride: false
        },
        {
          tmdbId: 2,
          title: "How to Train Your Dragon",
          hasIMAX: false,
          inCatalog: true,
          manualOverride: false,
          ticketLinks: { amc: existingAmc }
        }
      ],
      [
        { tmdbId: 1, title: "Superman", year: 2025 },
        { tmdbId: 2, title: "How to Train Your Dragon", year: 2025 }
      ],
      { catalogs }
    );
    assert.equal(withTicketLinks, 2);
    assert.equal(stays[0]?.ticketLinks?.fandango, "https://www.fandango.com/superman-2025-230934/movie-overview");
    assert.equal(stays[0]?.ticketLinks?.atom, "https://www.atomtickets.com/movies/superman/343208");
    assert.equal(stays[1]?.ticketLinks?.amc, existingAmc);
  });

  it("uses TMDB alternative titles when the listing name is longer", async () => {
    const { stays } = await attachResolvedTicketLinks(
      [{ tmdbId: 9, title: "F1", hasIMAX: false, inCatalog: true, manualOverride: false }],
      [{ tmdbId: 9, title: "F1", year: 2025 }],
      {
        catalogs,
        fetchAltTitles: async () => ["F1 The Movie"]
      }
    );
    assert.equal(stays[0]?.ticketLinks?.fandango, "https://www.fandango.com/f1-the-movie-2025-236966/movie-overview");
    assert.equal(stays[0]?.ticketLinks?.amc, "https://www.amctheatres.com/movies/f1-the-movie-82699/showtimes");
  });

  it("follows a sitemap index and keeps child movie URLs", async () => {
    resetTicketLinkCatalogCacheForTests();
    const files: Record<string, string> = {
      "https://www.amctheatres.com/sitemaps/sitemap-movies.xml":
        `<urlset><url><loc>https://www.amctheatres.com/movies/how-to-train-your-dragon-83807</loc></url></urlset>`,
      "https://www.atomtickets.com/sitemap-movie-detail-pages-in-theaters-now.xml":
        `<urlset><url><loc>https://www.atomtickets.com/movies/superman/343208</loc></url></urlset>`,
      "https://www.atomtickets.com/sitemap-movie-detail-pages-coming-soon.xml": `<urlset></urlset>`,
      "https://www.fandango.com/sitemapindex-movies.xml":
        `<sitemapindex><sitemap><loc>https://www.fandango.com/sitemap-movies-01.xml</loc></sitemap><sitemap><loc>https://www.fandango.com/sitemap-movies-04.xml</loc></sitemap></sitemapindex>`,
      "https://www.fandango.com/sitemap-movies-01.xml":
        `<urlset><url><loc>https://www.fandango.com/character-29030/movie-overview</loc></url></urlset>`,
      "https://www.fandango.com/sitemap-movies-04.xml":
        `<urlset><url><loc>https://www.fandango.com/superman-2025-230934/movie-overview</loc></url></urlset>`
    };
    const loaded = await loadTicketSiteCatalogs(async (url) => {
      if (!files[url]) {
        throw new Error(`unexpected ${url}`);
      }
      return files[url];
    });
    assert.equal(matchTicketUrl("Superman", 2025, loaded.fandango), "https://www.fandango.com/superman-2025-230934/movie-overview");
    assert.equal(loaded.fandango.length, 2);
    resetTicketLinkCatalogCacheForTests();
  });

  it("does not overwrite an existing ticket link with a resolved one", () => {
    assert.deepEqual(
      mergeTicketLinks(
        { fandango: "https://www.fandango.com/superman-2025-230934/movie-overview" },
        { fandango: "https://www.fandango.com/weapons-2025-240417/movie-overview", atom: "https://www.atomtickets.com/movies/superman/343208" }
      ),
      {
        fandango: "https://www.fandango.com/superman-2025-230934/movie-overview",
        atom: "https://www.atomtickets.com/movies/superman/343208"
      }
    );
  });
});
