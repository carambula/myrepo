/* ---- Color Scheme Toggle (system / light / dark) ---- */

function applyColorScheme(scheme) {
  const root = document.documentElement;
  if (scheme === "light") {
    root.setAttribute("data-theme", "light");
  } else if (scheme === "dark") {
    root.setAttribute("data-theme", "dark");
  } else {
    root.removeAttribute("data-theme");
  }
  const toggle = document.getElementById("themeSchemeToggle");
  if (toggle) {
    toggle.querySelectorAll(".theme-toggle-btn").forEach((btn) => {
      btn.classList.toggle("is-active", btn.dataset.scheme === scheme);
    });
  }
}

function initColorScheme() {
  const saved = localStorage.getItem("watchedit-admin-color-scheme") || "system";
  applyColorScheme(saved);
  const toggle = document.getElementById("themeSchemeToggle");
  if (!toggle) {
    return;
  }
  toggle.addEventListener("click", (event) => {
    const btn = event.target.closest("[data-scheme]");
    if (!btn) {
      return;
    }
    const scheme = btn.dataset.scheme;
    localStorage.setItem("watchedit-admin-color-scheme", scheme);
    applyColorScheme(scheme);
  });
}

initColorScheme();

const state = {
  bootstrap: null,
  movies: [],
  filteredMovies: [],
  selectedMovieIndex: null,
  selectedSourceIdentifier: null,
  activeAdminView: "catalog",
  dataSources: [],
  dataSourceMap: new Map(),
  podcastSourceIds: new Set(),
  themes: [],
  selectedThemeId: null,
  designSystemTokens: null,
};

const elements = {
  searchInput: document.getElementById("searchInput"),
  statusFilter: document.getElementById("statusFilter"),
  genreFilter: document.getElementById("genreFilter"),
  ratingFilter: document.getElementById("ratingFilter"),
  streamingFilter: document.getElementById("streamingFilter"),
  listFilter: document.getElementById("listFilter"),
  sortFilter: document.getElementById("sortFilter"),
  movieTableBody: document.getElementById("movieTableBody"),
  newMovieBtn: document.getElementById("newMovieBtn"),
  regenerateBtn: document.getElementById("regenerateBtn"),
  refreshDataBtn: document.getElementById("refreshDataBtn"),
  refreshStreamingAllBtn: document.getElementById("refreshStreamingAllBtn"),
  sourcesBtn: document.getElementById("sourcesBtn"),
  themesBtn: document.getElementById("themesBtn"),
  refreshFeedsBtn: document.getElementById("refreshFeedsBtn"),
  latestPodcastsBtn: document.getElementById("latestPodcastsBtn"),
  dataHealthBtn: document.getElementById("dataHealthBtn"),
  dedupeBtn: document.getElementById("dedupeBtn"),
  addFeedTopBtn: document.getElementById("addFeedTopBtn"),
  addListTopBtn: document.getElementById("addListTopBtn"),
  addFeedOpsBtn: document.getElementById("addFeedOpsBtn"),
  addListOpsBtn: document.getElementById("addListOpsBtn"),
  themesOpsBtn: document.getElementById("themesOpsBtn"),
  saveMovieBtn: document.getElementById("saveMovieBtn"),
  deleteMovieBtn: document.getElementById("deleteMovieBtn"),
  refreshStreamingBtn: document.getElementById("refreshStreamingBtn"),
  addFeedBtn: document.getElementById("addFeedBtn"),
  addListBtn: document.getElementById("addListBtn"),
  movieForm: document.getElementById("movieForm"),
  detailEmpty: document.getElementById("detailEmpty"),
  detailMedia: document.getElementById("detailMedia"),
  detailOscars: document.getElementById("detailOscars"),
  detailMeta: document.getElementById("detailMeta"),
  detailBackdrop: document.getElementById("detailBackdrop"),
  detailPoster: document.getElementById("detailPoster"),
  tmdbQuery: document.getElementById("tmdbQuery"),
  tmdbYear: document.getElementById("tmdbYear"),
  tmdbSearchBtn: document.getElementById("tmdbSearchBtn"),
  tmdbResults: document.getElementById("tmdbResults"),
  podcastSourceSelect: document.getElementById("podcastSourceSelect"),
  podcastRunBtn: document.getElementById("podcastRunBtn"),
  podcastStatus: document.getElementById("podcastStatus"),
  healthStatus: document.getElementById("healthStatus"),
  healthMetrics: document.getElementById("healthMetrics"),
  ingestModal: document.getElementById("ingestModal"),
  ingestTitle: document.getElementById("ingestTitle"),
  ingestCloseBtn: document.getElementById("ingestCloseBtn"),
  ingestIdentifier: document.getElementById("ingestIdentifier"),
  ingestName: document.getElementById("ingestName"),
  ingestUrl: document.getElementById("ingestUrl"),
  ingestRanked: document.getElementById("ingestRanked"),
  ingestPreviewBtn: document.getElementById("ingestPreviewBtn"),
  ingestBackBtn: document.getElementById("ingestBackBtn"),
  ingestEnrichBtn: document.getElementById("ingestEnrichBtn"),
  ingestReviewBtn: document.getElementById("ingestReviewBtn"),
  refreshFeedsStepConfig: document.getElementById("refreshFeedsStepConfig"),
  feedsList: document.getElementById("feedsList"),
  feedsSelectAllBtn: document.getElementById("feedsSelectAllBtn"),
  feedsSelectNoneBtn: document.getElementById("feedsSelectNoneBtn"),
  feedsPreviewBtn: document.getElementById("feedsPreviewBtn"),
  feedsLoader: document.getElementById("feedsLoader"),
  ingestSelectEnrichedBtn: document.getElementById("ingestSelectEnrichedBtn"),
  ingestSelectLightBtn: document.getElementById("ingestSelectLightBtn"),
  ingestSelectMissingBtn: document.getElementById("ingestSelectMissingBtn"),
  ingestDeselectDuplicatesBtn: document.getElementById("ingestDeselectDuplicatesBtn"),
  ingestPreviewBody: document.getElementById("ingestPreviewBody"),
  ingestPreviewSummary: document.getElementById("ingestPreviewSummary"),
  ingestLatestStats: document.getElementById("ingestLatestStats"),
  ingestStepConfig: document.getElementById("ingestStepConfig"),
  ingestStepPreview: document.getElementById("ingestStepPreview"),
  ingestStepReview: document.getElementById("ingestStepReview"),
  ingestReviewBackBtn: document.getElementById("ingestReviewBackBtn"),
  ingestCommitBtn: document.getElementById("ingestCommitBtn"),
  ingestSummary: document.getElementById("ingestSummary"),
  confirmModal: document.getElementById("confirmModal"),
  confirmCloseBtn: document.getElementById("confirmCloseBtn"),
  confirmMessage: document.getElementById("confirmMessage"),
  confirmCancelBtn: document.getElementById("confirmCancelBtn"),
  confirmConfirmBtn: document.getElementById("confirmConfirmBtn"),
  dedupeModal: document.getElementById("dedupeModal"),
  dedupeCloseBtn: document.getElementById("dedupeCloseBtn"),
  dedupeCancelBtn: document.getElementById("dedupeCancelBtn"),
  dedupeCommitBtn: document.getElementById("dedupeCommitBtn"),
  dedupeStatus: document.getElementById("dedupeStatus"),
  dedupeGroups: document.getElementById("dedupeGroups"),
  reportModal: document.getElementById("reportModal"),
  reportCloseBtn: document.getElementById("reportCloseBtn"),
  reportStatus: document.getElementById("reportStatus"),
  reportSummary: document.getElementById("reportSummary"),
  reportItems: document.getElementById("reportItems"),
  streamingModal: document.getElementById("streamingModal"),
  streamingCloseBtn: document.getElementById("streamingCloseBtn"),
  streamingStatus: document.getElementById("streamingStatus"),
  streamingSummary: document.getElementById("streamingSummary"),
  streamingItems: document.getElementById("streamingItems"),
  themesModal: document.getElementById("themesModal"),
  themesCloseBtn: document.getElementById("themesCloseBtn"),
  themesList: document.getElementById("themesList"),
  themeForm: document.getElementById("themeForm"),
  themesStatus: document.getElementById("themesStatus"),
  themeNewBtn: document.getElementById("themeNewBtn"),
  themeDeleteBtn: document.getElementById("themeDeleteBtn"),
  themeUndoBtn: document.getElementById("themeUndoBtn"),
  themeSaveBtn: document.getElementById("themeSaveBtn"),
  themeColorPickerPopover: document.getElementById("themeColorPickerPopover"),
  themeColorPickerLabel: document.getElementById("themeColorPickerLabel"),
  themeColorPickerCloseBtn: document.getElementById("themeColorPickerCloseBtn"),
  themeSvSquare: document.getElementById("themeSvSquare"),
  themeSvCursor: document.getElementById("themeSvCursor"),
  themeHueStrip: document.getElementById("themeHueStrip"),
  themeHueCursor: document.getElementById("themeHueCursor"),
  themeColorPickerHex: document.getElementById("themeColorPickerHex"),
  themeColorPickerPreview: document.getElementById("themeColorPickerPreview"),
  themePreviewMode: document.getElementById("themePreviewMode"),
  themePreviewRoot: document.getElementById("themePreviewRoot"),
  sourcesModal: document.getElementById("sourcesModal"),
  sourcesCloseBtn: document.getElementById("sourcesCloseBtn"),
  sourcesList: document.getElementById("sourcesList"),
  sourceForm: document.getElementById("sourceForm"),
  sourcesStatus: document.getElementById("sourcesStatus"),
  sourceNewBtn: document.getElementById("sourceNewBtn"),
  sourceSaveBtn: document.getElementById("sourceSaveBtn"),
  toast: document.getElementById("toast"),
  designContent: document.getElementById("designContent"),
  oscarAwardsBtn: document.getElementById("oscarAwardsBtn"),
  physicalMediaBtn: document.getElementById("physicalMediaBtn"),
  physicalMediaModal: document.getElementById("physicalMediaModal"),
  physicalMediaCloseBtn: document.getElementById("physicalMediaCloseBtn"),
  physicalMediaStats: document.getElementById("physicalMediaStats"),
  physicalMediaRefreshStatsBtn: document.getElementById("physicalMediaRefreshStatsBtn"),
  physicalMediaEnrichBtn: document.getElementById("physicalMediaEnrichBtn"),
  physicalMediaClearBtn: document.getElementById("physicalMediaClearBtn"),
  physicalMediaStatus: document.getElementById("physicalMediaStatus"),
  detailPhysicalMedia: document.getElementById("detailPhysicalMedia"),
  theaterStaysBtn: document.getElementById("theaterStaysBtn"),
  theaterStaysModal: document.getElementById("theaterStaysModal"),
  theaterStaysCloseBtn: document.getElementById("theaterStaysCloseBtn"),
  theaterStaysStats: document.getElementById("theaterStaysStats"),
  theaterStaysRefreshStatsBtn: document.getElementById("theaterStaysRefreshStatsBtn"),
  theaterStaysRefreshBtn: document.getElementById("theaterStaysRefreshBtn"),
  theaterStaysClearBtn: document.getElementById("theaterStaysClearBtn"),
  theaterStaysStatus: document.getElementById("theaterStaysStatus"),
  theaterStaysBody: document.getElementById("theaterStaysBody"),
  detailTheaterStays: document.getElementById("detailTheaterStays"),
  oscarModal: document.getElementById("oscarModal"),
  oscarCloseBtn: document.getElementById("oscarCloseBtn"),
  oscarStats: document.getElementById("oscarStats"),
  oscarMode: document.getElementById("oscarMode"),
  oscarDelay: document.getElementById("oscarDelay"),
  oscarRefreshStatsBtn: document.getElementById("oscarRefreshStatsBtn"),
  oscarOmdbKey: document.getElementById("oscarOmdbKey"),
  oscarEnrichBtn: document.getElementById("oscarEnrichBtn"),
  oscarClearBtn: document.getElementById("oscarClearBtn"),
  oscarWikidataMode: document.getElementById("oscarWikidataMode"),
  oscarWikidataDelay: document.getElementById("oscarWikidataDelay"),
  oscarWikidataBtn: document.getElementById("oscarWikidataBtn"),
  oscarStatus: document.getElementById("oscarStatus"),
  oscarProgress: document.getElementById("oscarProgress"),
  oscarProgressFill: document.getElementById("oscarProgressFill"),
  oscarProgressLabel: document.getElementById("oscarProgressLabel"),
  oscarReport: document.getElementById("oscarReport"),
};

const formFields = {
  title: document.getElementById("movieTitle"),
  year: document.getElementById("movieYear"),
  tmdbId: document.getElementById("movieTmdbId"),
  sourceIdentifier: document.getElementById("movieSourceIdentifier"),
  sourceTitle: document.getElementById("movieSourceTitle"),
  rank: document.getElementById("movieRank"),
  mpaaRating: document.getElementById("movieMpaa"),
  episodeDate: document.getElementById("movieEpisodeDate"),
  overview: document.getElementById("movieOverview"),
  posterPath: document.getElementById("moviePosterPath"),
  backdropPath: document.getElementById("movieBackdropPath"),
  genres: document.getElementById("movieGenres"),
  streaming: document.getElementById("movieStreaming"),
  credits: document.getElementById("movieCredits"),
  trailer: document.getElementById("movieTrailer"),
  podcastDescription: document.getElementById("moviePodcastDescription"),
  isRewatched: document.getElementById("movieIsRewatched"),
  isListened: document.getElementById("movieIsListened"),
  isSaved: document.getElementById("movieIsSaved"),
};

const themeFormFields = {
  name: document.getElementById("themeName"),
  builtInThemeName: document.getElementById("themeBuiltInName"),
  supportsLightMode: document.getElementById("themeSupportsLightMode"),
  headlineFontStyle: document.getElementById("themeHeadlineFontStyle"),
  bodyFontStyle: document.getElementById("themeBodyFontStyle"),
  accent: document.getElementById("themeAccent"),
  secondaryAccent: document.getElementById("themeSecondaryAccent"),
  darkModeHeadlineColor: document.getElementById("themeDarkModeHeadlineColor"),
  lightModeHeadlineColor: document.getElementById("themeLightModeHeadlineColor"),
  darkModeBackground: document.getElementById("themeDarkBackground"),
  lightModeBackground: document.getElementById("themeLightBackground"),
};

const sourceFormFields = {
  identifier: document.getElementById("sourceIdentifier"),
  name: document.getElementById("sourceName"),
  type: document.getElementById("sourceType"),
  url: document.getElementById("sourceUrl"),
  isRankedList: document.getElementById("sourceRanked"),
};

const themeSwatches = {
  accent: document.getElementById("themeAccentSwatch"),
  secondaryAccent: document.getElementById("themeSecondaryAccentSwatch"),
  darkModeHeadlineColor: document.getElementById("themeDarkModeHeadlineColorSwatch"),
  lightModeHeadlineColor: document.getElementById("themeLightModeHeadlineColorSwatch"),
  darkModeBackground: document.getElementById("themeDarkBackgroundSwatch"),
  lightModeBackground: document.getElementById("themeLightBackgroundSwatch"),
};

const ingestState = {
  sourceType: "podcast",
  mode: "addSource",
  previewItems: [],
  selectedFeeds: [],
  latestSourceStats: [],
};

const confirmState = {
  action: null,
};

const dedupeState = {
  groups: [],
};

const reportState = {
  report: null,
};

const streamingReportState = {
  report: null,
};

const themeColorPickerState = {
  activeField: null,
  activeAnchorElement: null,
  activeFieldLabel: "Color Picker",
  hue: 0,
  saturation: 1,
  value: 1,
  draggingSv: false,
  draggingHue: false,
};

const themeUndoState = {
  history: [],
  cursor: -1,
  isApplyingSnapshot: false,
  commitTimer: null,
};

function setRootCssVars(cssVars) {
  const rootStyle = document.documentElement.style;
  Object.entries(cssVars || {}).forEach(([name, value]) => {
    if (typeof value === "string" && value.trim()) {
      rootStyle.setProperty(name, value);
    }
  });
}

function applyDesignSystemExhibits(tokens) {
  if (!tokens || !tokens.icons) {
    return;
  }
  const iconMapping = [
    ["movie", "movie"],
    ["bookmark", "bookmark"],
    ["rewatch", "rewatch"],
    ["listen", "listen"],
    ["checkmark", "checkmark"],
    ["account", "account"],
  ];
  const iconChips = document.querySelectorAll(".token-icon-grid .icon-chip");
  iconChips.forEach((chip, index) => {
    const entry = iconMapping[index];
    if (!entry) {
      return;
    }
    const [iconTokenKey, labelToken] = entry;
    const iconSymbol = tokens.icons[iconTokenKey] || iconTokenKey;
    const iconText = chip.querySelector("span");
    const code = chip.querySelector("code");
    if (iconText) {
      iconText.textContent = iconSymbol.slice(0, 4).toUpperCase();
      iconText.title = iconSymbol;
    }
    if (code) {
      code.textContent = labelToken;
    }
  });
}

async function loadDesignSystemTokens() {
  const response = await fetch("/api/design-system/tokens");
  if (!response.ok) {
    throw new Error("Failed to load design system tokens");
  }
  const tokens = await response.json();
  state.designSystemTokens = tokens;
  setRootCssVars(tokens.cssVars);
  applyDesignSystemExhibits(tokens);
}

function showToast(message, isError = false) {
  elements.toast.textContent = message;
  elements.toast.classList.toggle("error", isError);
  elements.toast.classList.remove("hidden");
  setTimeout(() => elements.toast.classList.add("hidden"), 2800);
}

async function readErrorMessage(response, fallbackMessage) {
  try {
    const payload = await response.json();
    if (payload?.details) {
      return `${fallbackMessage}: ${payload.details}`;
    }
    if (payload?.error) {
      return `${fallbackMessage}: ${payload.error}`;
    }
  } catch (error) {
    // Ignore parse failures and fall back to the generic message.
  }
  return fallbackMessage;
}

function componentToHex(value) {
  const channel = Math.max(0, Math.min(255, Math.round((Number(value) || 0) * 255)));
  return channel.toString(16).padStart(2, "0");
}

function themeColorToHex(color) {
  const source = color || {};
  return `#${componentToHex(source.red)}${componentToHex(source.green)}${componentToHex(source.blue)}`;
}

function parseHexColor(hex) {
  const normalized = (hex || "").trim().replace(/^#/, "");
  if (!/^[0-9a-fA-F]{6}$/.test(normalized)) {
    return null;
  }
  return {
    red: Number.parseInt(normalized.slice(0, 2), 16) / 255,
    green: Number.parseInt(normalized.slice(2, 4), 16) / 255,
    blue: Number.parseInt(normalized.slice(4, 6), 16) / 255,
    alpha: 1,
  };
}

function normalizeHexColor(value) {
  const parsed = parseHexColor(value);
  if (!parsed) {
    return null;
  }
  return themeColorToHex(parsed);
}

function mixThemeColors(baseColor, targetColor, ratio) {
  const clampedRatio = Math.max(0, Math.min(1, Number(ratio) || 0));
  return {
    red: baseColor.red * (1 - clampedRatio) + targetColor.red * clampedRatio,
    green: baseColor.green * (1 - clampedRatio) + targetColor.green * clampedRatio,
    blue: baseColor.blue * (1 - clampedRatio) + targetColor.blue * clampedRatio,
    alpha: baseColor.alpha ?? 1,
  };
}

function deriveBackgroundTintHex(backgroundHex, mode) {
  const base = parseHexColor(backgroundHex);
  if (!base) {
    return null;
  }
  const target =
    mode === "dark"
      ? { red: 1, green: 1, blue: 1, alpha: 1 }
      : { red: 0, green: 0, blue: 0, alpha: 1 };
  return themeColorToHex(mixThemeColors(base, target, 0.03));
}

function rgbToHsv(color) {
  const red = color.red ?? 0;
  const green = color.green ?? 0;
  const blue = color.blue ?? 0;
  const max = Math.max(red, green, blue);
  const min = Math.min(red, green, blue);
  const delta = max - min;
  let hue = 0;
  if (delta > 0) {
    if (max === red) {
      hue = ((green - blue) / delta) % 6;
    } else if (max === green) {
      hue = (blue - red) / delta + 2;
    } else {
      hue = (red - green) / delta + 4;
    }
    hue *= 60;
    if (hue < 0) {
      hue += 360;
    }
  }
  const saturation = max === 0 ? 0 : delta / max;
  const value = max;
  return { hue, saturation, value };
}

function hsvToRgb(hue, saturation, value) {
  const normalizedHue = ((hue % 360) + 360) % 360;
  const chroma = value * saturation;
  const x = chroma * (1 - Math.abs(((normalizedHue / 60) % 2) - 1));
  const m = value - chroma;
  let redPrime = 0;
  let greenPrime = 0;
  let bluePrime = 0;
  if (normalizedHue < 60) {
    redPrime = chroma;
    greenPrime = x;
  } else if (normalizedHue < 120) {
    redPrime = x;
    greenPrime = chroma;
  } else if (normalizedHue < 180) {
    greenPrime = chroma;
    bluePrime = x;
  } else if (normalizedHue < 240) {
    greenPrime = x;
    bluePrime = chroma;
  } else if (normalizedHue < 300) {
    redPrime = x;
    bluePrime = chroma;
  } else {
    redPrime = chroma;
    bluePrime = x;
  }
  return {
    red: redPrime + m,
    green: greenPrime + m,
    blue: bluePrime + m,
    alpha: 1,
  };
}

function bindClick(element, handler) {
  if (!element) {
    console.warn("Missing element for click binding");
    return;
  }
  element.addEventListener("click", handler);
}

function setAdminView(viewName, updateHash = true) {
  const validViews = new Set(["catalog", "operations", "design", "app"]);
  const normalized = validViews.has(viewName) ? viewName : "catalog";
  state.activeAdminView = normalized;
  document.querySelectorAll("[data-admin-view]").forEach((view) => {
    view.classList.toggle("is-active", view.dataset.adminView === normalized);
  });
  document.querySelectorAll(".top-tab[data-admin-nav]").forEach((tab) => {
    tab.classList.toggle("is-active", tab.dataset.adminNav === normalized);
  });
  if (updateHash) {
    history.replaceState(null, "", `#${normalized}`);
  }
}

function getAdminViewFromHash() {
  const hash = location.hash.replace(/^#/, "");
  const validViews = new Set(["catalog", "operations", "design", "app"]);
  return validViews.has(hash) ? hash : "catalog";
}

function setDesignSection(sectionKey) {
  const sectionId = `design-${sectionKey}`;
  const targetSection = document.getElementById(sectionId);
  if (!targetSection || !elements.designContent) {
    return;
  }
  targetSection.scrollIntoView({ behavior: "smooth", block: "start" });
  document.querySelectorAll("[data-design-nav]").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.designNav === sectionKey);
  });
}

function bindDesignNavigation() {
  const designButtons = document.querySelectorAll("[data-design-nav]");
  if (!designButtons.length) {
    return;
  }
  designButtons.forEach((button) => {
    button.addEventListener("click", () => {
      setDesignSection(button.dataset.designNav);
    });
  });
}

function setOpsSection(sectionKey) {
  const targetSection = document.querySelector(`[data-ops-section="${sectionKey}"]`);
  if (!targetSection) return;
  targetSection.scrollIntoView({ behavior: "smooth", block: "start" });
  document.querySelectorAll("[data-ops-nav]").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.opsNav === sectionKey);
  });
  if (sectionKey === "history") {
    loadHistory();
  }
}

function bindOpsNavigation() {
  document.querySelectorAll("[data-ops-nav]").forEach((button) => {
    button.addEventListener("click", () => {
      setOpsSection(button.dataset.opsNav);
    });
  });
}

function setAppSection(sectionKey) {
  var sectionId = "app-" + sectionKey;
  var target = document.getElementById(sectionId);
  var viewport = document.getElementById("canvasViewport");
  if (!target || !viewport) return;
  var vr = viewport.getBoundingClientRect();
  var tr = target.getBoundingClientRect();
  var surface = document.getElementById("canvasSurface");
  if (!surface) return;
  var artboardX = (tr.left - surface.getBoundingClientRect().left) / canvas.zoom;
  var artboardY = (tr.top - surface.getBoundingClientRect().top) / canvas.zoom;
  canvas.panX = vr.width / 2 - (artboardX + target.offsetWidth / 2) * canvas.zoom;
  canvas.panY = 40;
  canvasApplyTransform();
}

function bindAppNavigation() {
  document.querySelectorAll("[data-app-jump]").forEach(function(thumb) {
    thumb.addEventListener("click", function() {
      setAppSection(thumb.dataset.appJump);
    });
  });
}

function bindAdminNavigation() {
  document.querySelectorAll(".top-tab[data-admin-nav]").forEach((tab) => {
    tab.addEventListener("click", () => {
      setAdminView(tab.dataset.adminNav);
    });
  });
  window.addEventListener("hashchange", () => {
    const view = getAdminViewFromHash();
    if (view !== state.activeAdminView) {
      setAdminView(view, false);
    }
  });
}

async function fetchBootstrap() {
  const response = await fetch("/api/bootstrap");
  if (!response.ok) {
    throw new Error("Failed to load bootstrap data");
  }
  const bootstrap = await response.json();
  state.bootstrap = bootstrap;
  state.movies = bootstrap.movies || [];
  state.dataSources = bootstrap.dataSources || [];
  state.dataSourceMap = new Map(
    state.dataSources.map((source) => [source.identifier, source])
  );
  state.podcastSourceIds = new Set(
    state.dataSources.filter((source) => source.type === "podcast").map((s) => s.identifier)
  );
}

function populateFilters() {
  const genreOptions = new Set();
  const ratingOptions = new Set();
  const streamingOptions = new Set();

  state.movies.forEach((movie) => {
    (movie.genres || []).forEach((genre) => genreOptions.add(genre));
    if (movie.mpaaRating) {
      ratingOptions.add(movie.mpaaRating);
    }
    (movie.streamingServices || []).forEach((service) => {
      if (service?.providerName) {
        streamingOptions.add(service.providerName);
      }
    });
  });

  elements.genreFilter.innerHTML = "";
  elements.genreFilter.append(new Option("All Genres", ""));
  Array.from(genreOptions)
    .sort()
    .forEach((genre) => elements.genreFilter.append(new Option(genre, genre)));

  elements.ratingFilter.innerHTML = "";
  elements.ratingFilter.append(new Option("All Ratings", ""));
  Array.from(ratingOptions)
    .sort()
    .forEach((rating) => elements.ratingFilter.append(new Option(rating, rating)));

  elements.streamingFilter.innerHTML = "";
  elements.streamingFilter.append(new Option("All Services", ""));
  Array.from(streamingOptions)
    .sort()
    .forEach((service) =>
      elements.streamingFilter.append(new Option(service, service))
    );

  elements.listFilter.innerHTML = "";
  elements.listFilter.append(new Option("All Sources", ""));
  state.dataSources
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name))
    .forEach((source) => elements.listFilter.append(new Option(source.name, source.identifier)));

  formFields.sourceIdentifier.innerHTML = "";
  state.dataSources.forEach((source) => {
    formFields.sourceIdentifier.append(new Option(source.name, source.identifier));
  });

  elements.podcastSourceSelect.innerHTML = "";
  state.dataSources
    .filter((source) => source.type === "podcast")
    .forEach((source) => {
      elements.podcastSourceSelect.append(new Option(source.name, source.identifier));
    });
}

function isListened(movie) {
  if (typeof movie.isListened === "boolean") {
    return movie.isListened;
  }
  return state.podcastSourceIds.has(movie.sourceIdentifier);
}

function isRewatched(movie) {
  if (typeof movie.isRewatched === "boolean") {
    return movie.isRewatched;
  }
  return false;
}

function isSaved(movie) {
  if (typeof movie.isSaved === "boolean") {
    return movie.isSaved;
  }
  return false;
}

function isComplete(movie) {
  return Boolean(
    movie.tmdbId &&
      movie.year &&
      movie.posterPath &&
      movie.overview &&
      (movie.genres || []).length
  );
}

function applyFilters() {
  const searchText = elements.searchInput.value.trim().toLowerCase();
  const statusFilter = elements.statusFilter.value;
  const selectedGenre = elements.genreFilter.value || null;
  const selectedRating = elements.ratingFilter.value || null;
  const selectedStreaming = elements.streamingFilter.value || null;
  const selectedList = elements.listFilter.value || null;
  const sortOption = elements.sortFilter.value;

  let movies = [...state.movies];

  if (searchText) {
    movies = movies.filter((movie) => movie.title.toLowerCase().includes(searchText));
  }

  switch (statusFilter) {
    case "completed":
      movies = movies.filter((movie) => isComplete(movie));
      break;
    case "incomplete":
      movies = movies.filter((movie) => !isComplete(movie));
      break;
    case "rewatched":
      movies = movies.filter((movie) => isRewatched(movie));
      break;
    case "listened":
      movies = movies.filter((movie) => isListened(movie));
      break;
    case "saved":
      movies = movies.filter((movie) => isSaved(movie));
      break;
    default:
      break;
  }

  if (selectedGenre) {
    movies = movies.filter((movie) => (movie.genres || []).includes(selectedGenre));
  }

  if (selectedRating) {
    movies = movies.filter((movie) => movie.mpaaRating === selectedRating);
  }

  if (selectedStreaming) {
    movies = movies.filter((movie) =>
      (movie.streamingServices || []).some(
        (service) => service?.providerName === selectedStreaming
      )
    );
  }

  if (selectedList) {
    movies = movies.filter((movie) => movie.sourceIdentifier === selectedList);
  }

  switch (sortOption) {
    case "title":
      movies.sort((a, b) => a.title.localeCompare(b.title));
      break;
    case "releaseDateAsc":
      movies.sort((a, b) => (a.year || 0) - (b.year || 0) || a.title.localeCompare(b.title));
      break;
    case "releaseDateDesc":
      movies.sort((a, b) => (b.year || 0) - (a.year || 0) || a.title.localeCompare(b.title));
      break;
    case "episodeDateAsc":
      movies.sort(
        (a, b) =>
          new Date(a.episodeDate || 0) - new Date(b.episodeDate || 0) ||
          a.title.localeCompare(b.title)
      );
      break;
    case "episodeDateDesc":
      movies.sort(
        (a, b) =>
          new Date(b.episodeDate || 0) - new Date(a.episodeDate || 0) ||
          a.title.localeCompare(b.title)
      );
      break;
    case "ranking": {
      const source = state.dataSourceMap.get(selectedList);
      if (source?.isRankedList) {
        movies.sort((a, b) => (a.rank || 0) - (b.rank || 0));
      }
      break;
    }
    default:
      break;
  }

  state.filteredMovies = movies;
  renderList();
}

function renderList() {
  elements.movieTableBody.innerHTML = "";
  state.filteredMovies.forEach((movie) => {
    const row = document.createElement("tr");
    row.dataset.index = movie.__index;
    const oscarBadge = movie.oscarAwards
      ? (movie.oscarAwards.totalWins > 0
        ? `<span class="oscar-badge winner" title="${movie.oscarAwards.totalWins}W ${movie.oscarAwards.totalNominations}N">${movie.oscarAwards.totalWins}W</span>`
        : `<span class="oscar-badge nominee" title="${movie.oscarAwards.totalNominations} nominations">${movie.oscarAwards.totalNominations}N</span>`)
      : "";
    row.innerHTML = `
      <td>${movie.title || ""}</td>
      <td>${movie.year || ""}</td>
      <td>${state.dataSourceMap.get(movie.sourceIdentifier)?.name || movie.sourceIdentifier}</td>
      <td>${movie.rank ?? ""}</td>
      <td>${movie.mpaaRating || ""}</td>
      <td>${oscarBadge}</td>
      <td>${movie.tmdbId || ""}</td>
    `;
    row.addEventListener("click", () => selectMovie(movie.__index));
    if (movie.__index === state.selectedMovieIndex) {
      row.classList.add("selected");
    }
    elements.movieTableBody.append(row);
  });
}

function selectMovie(index) {
  const movie = state.movies.find((item) => item.__index === index);
  if (!movie) {
    return;
  }
  state.selectedMovieIndex = index;
  elements.detailEmpty.classList.add("hidden");
  elements.movieForm.classList.remove("hidden");
  elements.detailMedia.classList.remove("hidden");
  elements.detailMeta.classList.remove("hidden");
  fillForm(movie);
  renderList();
}

function buildImageUrl(path, size) {
  if (!path) {
    return null;
  }
  if (path.startsWith("http")) {
    return path;
  }
  const trimmed = path.startsWith("/") ? path : `/${path}`;
  return `https://image.tmdb.org/t/p/${size}${trimmed}`;
}

function sanitizeTmdbQuery(value) {
  if (!value) {
    return "";
  }
  return value.replace(/^['"“”‘’]+|['"“”‘’]+$/g, "").trim();
}

function formatDateForUi(value) {
  if (!value) {
    return "—";
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value;
  }
  return parsed.toLocaleString();
}

function renderDetailOscars(movie) {
  const awards = movie.oscarAwards;
  const hasData = awards && (awards.totalWins > 0 || awards.totalNominations > 0);
  const hasDetail = awards && ((awards.wins?.length || 0) > 0 || (awards.nominations?.length || 0) > 0);

  if (!hasData && !movie.tmdbId) {
    elements.detailOscars.classList.add("hidden");
    elements.detailOscars.innerHTML = "";
    return;
  }
  elements.detailOscars.classList.remove("hidden");

  const chips = [];
  if (hasData) {
    if (awards.totalWins > 0) {
      chips.push(`<span class="oscar-chip winner"><span class="oscar-chip-icon">🏆</span>${awards.totalWins} Win${awards.totalWins !== 1 ? "s" : ""}</span>`);
    }
    if (awards.totalNominations > 0) {
      chips.push(`<span class="oscar-chip nominee"><span class="oscar-chip-icon">🎬</span>${awards.totalNominations} Nom${awards.totalNominations !== 1 ? "s" : ""}</span>`);
    }
  }

  let detailHtml = "";
  if (hasDetail) {
    const winsHtml = (awards.wins || [])
      .map((w) => `<div class="oscar-entry win"><span class="oscar-entry-icon">🏆</span><span class="oscar-entry-cat">${w.category}</span>${w.recipient ? `<span class="oscar-entry-who">${w.recipient}</span>` : ""}</div>`)
      .join("");
    const nomsHtml = (awards.nominations || [])
      .map((n) => `<div class="oscar-entry nom"><span class="oscar-entry-icon">🎬</span><span class="oscar-entry-cat">${n.category}</span>${n.nominee ? `<span class="oscar-entry-who">${n.nominee}</span>` : ""}</div>`)
      .join("");
    detailHtml = `<div class="oscar-entries">${winsHtml}${nomsHtml}</div>`;
  }

  const rawText = awards?.rawAwardsText
    ? `<div class="oscar-raw">${awards.rawAwardsText}</div>`
    : "";

  const fetchLabel = hasDetail ? "Re-fetch" : "Fetch Details";
  const fetchBtn = movie.tmdbId
    ? `<button class="oscar-fetch-btn" data-tmdb="${movie.tmdbId}">${fetchLabel}</button>`
    : "";

  elements.detailOscars.innerHTML = `
    <div class="oscar-detail-row">
      <div class="oscar-detail-header">Academy Awards</div>
      ${fetchBtn}
    </div>
    ${chips.length ? `<div class="oscar-chips">${chips.join("")}</div>` : ""}
    ${detailHtml}
    ${rawText}
  `;

  const btn = elements.detailOscars.querySelector(".oscar-fetch-btn");
  if (btn) {
    btn.addEventListener("click", async () => {
      btn.disabled = true;
      btn.textContent = "Fetching…";
      try {
        const response = await fetch("/api/oscar-awards/wikidata-single", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ tmdbId: movie.tmdbId }),
        });
        const data = await response.json();
        if (data.success && data.oscarAwards) {
          movie.oscarAwards = data.oscarAwards;
          renderDetailOscars(movie);
          showToast(`Updated Oscar data for ${data.title}`);
        } else {
          showToast(data.reason === "no-imdb" ? "No IMDb ID found" : "No Oscar data on Wikidata", true);
          btn.disabled = false;
          btn.textContent = fetchLabel;
        }
      } catch (error) {
        showToast(error.message, true);
        btn.disabled = false;
        btn.textContent = fetchLabel;
      }
    });
  }
}

function renderDetailMeta(movie) {
  const source = state.dataSourceMap.get(movie.sourceIdentifier);
  const director = movie.credits?.director || "—";
  const castNames = movie.credits?.cast?.slice(0, 4).map((c) => c.name).join(", ");
  const streaming = movie.streamingServices?.map((s) => s.providerName).join(", ");
  const trailerLink = movie.trailer?.youtubeKey
    ? `https://www.youtube.com/watch?v=${movie.trailer.youtubeKey}`
    : null;

  const rows = [
    ["Source Name", source?.name || "—"],
    ["Source Type", source?.type || "—"],
    ["Ranked List", source?.isRankedList ? "Yes" : "No"],
    ["Director", director],
    ["Top Cast", castNames || "—"],
    ["Streaming", streaming || "—"],
    ["Trailer", trailerLink ? `<a href="${trailerLink}" target="_blank">Open</a>` : "—"],
  ];

  elements.detailMeta.innerHTML = rows
    .map(
      ([label, value]) => `
        <div class="meta-row">
          <div class="meta-label">${label}</div>
          <div class="meta-value">${value}</div>
        </div>
      `
    )
    .join("");
}

function fillForm(movie) {
  formFields.title.value = movie.title || "";
  formFields.year.value = movie.year ?? "";
  formFields.tmdbId.value = movie.tmdbId ?? "";
  formFields.sourceIdentifier.value = movie.sourceIdentifier || "";
  formFields.sourceTitle.value = movie.sourceTitle || "";
  formFields.rank.value = movie.rank ?? "";
  formFields.mpaaRating.value = movie.mpaaRating || "";
  formFields.episodeDate.value = movie.episodeDate || "";
  formFields.overview.value = movie.overview || "";
  formFields.posterPath.value = movie.posterPath || "";
  formFields.backdropPath.value = movie.backdropPath || "";
  formFields.genres.value = (movie.genres || []).join(", ");
  formFields.streaming.value = movie.streamingServices
    ? JSON.stringify(movie.streamingServices, null, 2)
    : "";
  formFields.credits.value = movie.credits ? JSON.stringify(movie.credits, null, 2) : "";
  formFields.trailer.value = movie.trailer ? JSON.stringify(movie.trailer, null, 2) : "";
  formFields.podcastDescription.value = movie.podcastEpisodeDescription || "";
  formFields.isRewatched.value = isRewatched(movie) ? "true" : "false";
  formFields.isListened.value = isListened(movie) ? "true" : "false";
  formFields.isSaved.value = isSaved(movie) ? "true" : "false";

  const posterUrl = buildImageUrl(movie.posterPath, "w342");
  const backdropUrl = buildImageUrl(movie.backdropPath, "w780");
  elements.detailPoster.src = posterUrl || "";
  elements.detailPoster.style.visibility = posterUrl ? "visible" : "hidden";
  elements.detailBackdrop.src = backdropUrl || "";
  elements.detailBackdrop.style.visibility = backdropUrl ? "visible" : "hidden";
  renderDetailOscars(movie);
  renderDetailPhysicalMedia(movie);
  renderDetailTheaterStays(movie);
  renderDetailMeta(movie);

  const cleanedTitle = sanitizeTmdbQuery(movie.title || "");
  elements.tmdbQuery.value = cleanedTitle;
  if (cleanedTitle) {
    searchTmdb();
  } else {
    elements.tmdbResults.textContent = "";
  }
}

function parseJsonField(value, fallback) {
  if (!value.trim()) {
    return fallback;
  }
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function buildMoviePayload() {
  const genres = formFields.genres.value
    .split(",")
    .map((genre) => genre.trim())
    .filter(Boolean);
  const streamingServices = parseJsonField(formFields.streaming.value, []);
  const credits = parseJsonField(formFields.credits.value, null);
  const trailer = parseJsonField(formFields.trailer.value, null);

  return {
    __index: state.selectedMovieIndex,
    title: formFields.title.value.trim(),
    year: formFields.year.value ? Number(formFields.year.value) : null,
    tmdbId: formFields.tmdbId.value ? Number(formFields.tmdbId.value) : null,
    sourceIdentifier: formFields.sourceIdentifier.value,
    sourceTitle: formFields.sourceTitle.value.trim() || null,
    rank: formFields.rank.value ? Number(formFields.rank.value) : null,
    mpaaRating: formFields.mpaaRating.value.trim() || null,
    episodeDate: formFields.episodeDate.value.trim() || null,
    overview: formFields.overview.value.trim() || null,
    posterPath: formFields.posterPath.value.trim() || null,
    backdropPath: formFields.backdropPath.value.trim() || null,
    genres,
    streamingServices: streamingServices || [],
    credits: credits || null,
    trailer: trailer || null,
    podcastEpisodeDescription: formFields.podcastDescription.value.trim() || null,
    isRewatched: formFields.isRewatched.value === "true" ? true : undefined,
    isListened: formFields.isListened.value === "true" ? true : undefined,
    isSaved: formFields.isSaved.value === "true" ? true : undefined,
  };
}

async function saveMovie() {
  if (state.selectedMovieIndex === null) {
    showToast("Select a movie first", true);
    return;
  }
  const payload = buildMoviePayload();
  if (!payload.title || !payload.sourceIdentifier) {
    showToast("Title and source identifier are required", true);
    return;
  }
  const response = await fetch(`/api/movies/${state.selectedMovieIndex}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    showToast("Failed to save movie", true);
    return;
  }
  await reloadData(state.selectedMovieIndex);
  showToast("Movie saved");
}

async function deleteMovie() {
  if (state.selectedMovieIndex === null) {
    return;
  }
  const response = await fetch(`/api/movies/${state.selectedMovieIndex}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    showToast("Failed to delete", true);
    return;
  }
  state.selectedMovieIndex = null;
  elements.movieForm.classList.add("hidden");
  elements.detailMedia.classList.add("hidden");
  elements.detailOscars.classList.add("hidden");
  if (elements.detailPhysicalMedia) elements.detailPhysicalMedia.classList.add("hidden");
  if (elements.detailTheaterStays) elements.detailTheaterStays.classList.add("hidden");
  elements.detailMeta.classList.add("hidden");
  elements.detailEmpty.classList.remove("hidden");
  await reloadData();
  showToast("Movie deleted");
}

async function createNewMovie() {
  state.selectedMovieIndex = null;
  elements.detailEmpty.classList.add("hidden");
  elements.movieForm.classList.remove("hidden");
  elements.detailMedia.classList.remove("hidden");
  elements.detailMeta.classList.remove("hidden");
  const defaultSource = state.dataSources[0]?.identifier || "";
  fillForm({
    title: "",
    year: null,
    tmdbId: null,
    sourceIdentifier: defaultSource,
    sourceTitle: "",
    rank: null,
    mpaaRating: "",
    episodeDate: "",
    overview: "",
    posterPath: "",
    backdropPath: "",
    genres: [],
    streamingServices: [],
    credits: null,
    trailer: null,
    podcastEpisodeDescription: "",
  });
}

async function persistNewMovie() {
  if (state.selectedMovieIndex !== null) {
    return;
  }
  const payload = buildMoviePayload();
  if (!payload.title || !payload.sourceIdentifier) {
    showToast("Title and source identifier are required", true);
    return;
  }
  const response = await fetch("/api/movies", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    showToast("Failed to create movie", true);
    return;
  }
  await reloadData();
  showToast("Movie added");
}

async function regenerateStore() {
  const response = await fetch("/api/bootstrap/regenerate", { method: "POST" });
  if (!response.ok) {
    showToast("Regenerate failed", true);
    return;
  }
  showToast("Bootstrap store regenerated");
}

async function refreshFeeds() {
  elements.refreshFeedsBtn.disabled = true;
  elements.refreshFeedsBtn.textContent = "Refreshing...";
  const response = await fetch("/api/feeds/refresh-all", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  elements.refreshFeedsBtn.disabled = false;
  elements.refreshFeedsBtn.textContent = "Refresh Feeds";
  if (!response.ok) {
    showToast("Feed refresh failed", true);
    return;
  }
  const data = await response.json();
  elements.podcastStatus.textContent = `Added ${data.addedCount} items, skipped ${data.skippedCount}.`;
  await reloadData(state.selectedMovieIndex);
  showToast("Feeds refreshed");
}

async function loadDataHealth() {
  const response = await fetch("/api/data/health");
  if (!response.ok) {
    showToast("Health check failed", true);
    return;
  }
  const data = await response.json();
  elements.healthStatus.textContent = `Movies: ${data.totalMovies}, Sources: ${data.totalSources}`;
  elements.healthMetrics.innerHTML = [
    ["Missing TMDB", data.missingTmdbId],
    ["Missing Year", data.missingYear],
    ["Missing Poster", data.missingPoster],
    ["Missing Overview", data.missingOverview],
    ["Missing Genres", data.missingGenres],
    ["Missing Streaming", data.missingStreaming],
    ["Missing Credits", data.missingCredits],
    ["Missing Trailer", data.missingTrailer],
    ["Duplicate Sources", data.duplicateSourceTitles],
    ["Discs", data.withPhysicalMedia],
    ["Theater Stays", data.theaterStays],
    ["IMAX Stays", data.theaterStaysIMAX],
  ]
    .map(
      ([label, value]) => `
        <div class="health-metric">
          <strong>${value}</strong>
          ${label}
        </div>
      `
    )
    .join("");
}

function openIngestModal(type) {
  ingestState.sourceType = type;
  ingestState.mode = "addSource";
  ingestState.previewItems = [];
  ingestState.selectedFeeds = [];
  ingestState.latestSourceStats = [];
  elements.ingestTitle.textContent = type === "podcast" ? "Add Feed" : "Add List";
  elements.ingestIdentifier.value = "";
  elements.ingestName.value = "";
  elements.ingestUrl.value = "";
  elements.ingestRanked.value = "false";
  elements.refreshFeedsStepConfig.classList.add("hidden");
  elements.ingestStepConfig.classList.remove("hidden");
  setIngestStep("config");
  elements.ingestModal.classList.remove("hidden");
}

function closeIngestModal() {
  elements.ingestModal.classList.add("hidden");
}

function openRefreshFeedsModal() {
  ingestState.sourceType = "podcast";
  ingestState.mode = "refreshFeeds";
  ingestState.previewItems = [];
  ingestState.selectedFeeds = [];
  ingestState.latestSourceStats = [];
  elements.ingestTitle.textContent = "Refresh Feeds";
  elements.ingestStepConfig.classList.add("hidden");
  elements.refreshFeedsStepConfig.classList.remove("hidden");
  setIngestStep("config");
  renderFeedsList();
  elements.ingestModal.classList.remove("hidden");
}

function openLatestPodcastsModal() {
  ingestState.sourceType = "podcast";
  ingestState.mode = "latestPodcasts";
  ingestState.previewItems = [];
  ingestState.selectedFeeds = [];
  ingestState.latestSourceStats = [];
  elements.ingestTitle.textContent = "Latest Podcasts";
  elements.ingestStepConfig.classList.add("hidden");
  elements.refreshFeedsStepConfig.classList.remove("hidden");
  setIngestStep("config");
  renderFeedsList();
  elements.ingestModal.classList.remove("hidden");
}

function openConfirmModal({ message, onConfirm }) {
  confirmState.action = onConfirm;
  elements.confirmMessage.textContent = message;
  elements.confirmModal.classList.remove("hidden");
}

function closeConfirmModal() {
  confirmState.action = null;
  elements.confirmModal.classList.add("hidden");
}

function openDedupeModal() {
  elements.dedupeModal.classList.remove("hidden");
  loadDedupeGroups();
}

function closeDedupeModal() {
  elements.dedupeModal.classList.add("hidden");
  dedupeState.groups = [];
  elements.dedupeGroups.innerHTML = "";
}

function openReportModal(report) {
  reportState.report = report;
  elements.reportModal.classList.remove("hidden");
  renderReport();
}

function closeReportModal() {
  elements.reportModal.classList.add("hidden");
  reportState.report = null;
  elements.reportSummary.innerHTML = "";
  elements.reportItems.innerHTML = "";
}

function openStreamingModal(statusText) {
  elements.streamingModal.classList.remove("hidden");
  elements.streamingStatus.textContent = statusText;
  elements.streamingSummary.innerHTML = "";
  elements.streamingItems.innerHTML = "";
}

function closeStreamingModal() {
  elements.streamingModal.classList.add("hidden");
  streamingReportState.report = null;
  elements.streamingSummary.innerHTML = "";
  elements.streamingItems.innerHTML = "";
}

function sourceTypeLabel(sourceType) {
  return sourceType === "podcast" ? "Podcast" : "List";
}

function blankSource(preferredType = "podcast") {
  return {
    identifier: "",
    name: "",
    type: preferredType === "podcast" ? "podcast" : "url",
    url: "",
    isRankedList: false,
  };
}

function renderSourcesList() {
  elements.sourcesList.innerHTML = "";
  const sources = [...state.dataSources].sort((a, b) => a.name.localeCompare(b.name));
  sources.forEach((source) => {
    const row = document.createElement("div");
    row.className = "source-list-item";
    if (source.identifier === state.selectedSourceIdentifier) {
      row.classList.add("selected");
    }
    row.innerHTML = `
      <div class="source-list-title">${source.name}</div>
      <div class="source-list-subtitle">${sourceTypeLabel(source.type)}   ${source.identifier}</div>
    `;
    row.addEventListener("click", () => {
      state.selectedSourceIdentifier = source.identifier;
      fillSourceForm(source);
      renderSourcesList();
    });
    elements.sourcesList.append(row);
  });
}

function fillSourceForm(source) {
  const value = source || blankSource();
  if (value.identifier) {
    state.selectedSourceIdentifier = value.identifier;
  }
  elements.sourceForm.classList.remove("hidden");
  elements.sourcesStatus.textContent = value.identifier
    ? `Editing "${value.name}"`
    : "New source (not saved yet)";
  sourceFormFields.identifier.value = value.identifier || "";
  sourceFormFields.name.value = value.name || "";
  sourceFormFields.type.value = value.type === "podcast" ? "podcast" : "url";
  sourceFormFields.url.value = value.url || "";
  sourceFormFields.isRankedList.value = value.isRankedList ? "true" : "false";
}

function createSourceDraft(preferredType = "podcast") {
  state.selectedSourceIdentifier = null;
  fillSourceForm(blankSource(preferredType));
  renderSourcesList();
}

function buildSourcePayload() {
  return {
    identifier: sourceFormFields.identifier.value.trim(),
    name: sourceFormFields.name.value.trim(),
    type: sourceFormFields.type.value === "podcast" ? "podcast" : "url",
    url: sourceFormFields.url.value.trim(),
    isRankedList: sourceFormFields.isRankedList.value === "true",
  };
}

async function saveSource() {
  const payload = buildSourcePayload();
  if (!payload.identifier || !payload.name || !payload.url) {
    showToast("Identifier, name, and URL are required", true);
    return;
  }
  const previousIdentifier = state.selectedSourceIdentifier;
  const existingIdentifier =
    previousIdentifier && state.dataSourceMap.has(previousIdentifier)
      ? previousIdentifier
      : state.dataSourceMap.has(payload.identifier)
        ? payload.identifier
        : null;
  const isUpdate = Boolean(existingIdentifier);
  const endpoint = isUpdate
    ? `/api/sources/${encodeURIComponent(existingIdentifier)}`
    : "/api/sources";
  const method = isUpdate ? "PUT" : "POST";
  const response = await fetch(endpoint, {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    showToast(body.error || "Failed to save source", true);
    return;
  }
  const data = await response.json().catch(() => ({}));
  state.selectedSourceIdentifier = data.source?.identifier || payload.identifier;
  await reloadData(state.selectedMovieIndex);
  renderSourcesList();
  const selected = state.dataSourceMap.get(state.selectedSourceIdentifier);
  fillSourceForm(selected || blankSource(payload.type));
  showToast(isUpdate ? "Source updated" : "Source created");
}

function closeSourcesModal() {
  elements.sourcesModal.classList.add("hidden");
}

function openSourcesModal(preferredType = null) {
  elements.sourcesModal.classList.remove("hidden");
  renderSourcesList();
  if (preferredType) {
    createSourceDraft(preferredType);
    return;
  }
  if (state.selectedSourceIdentifier && state.dataSourceMap.has(state.selectedSourceIdentifier)) {
    fillSourceForm(state.dataSourceMap.get(state.selectedSourceIdentifier));
    return;
  }
  if (state.dataSources.length) {
    state.selectedSourceIdentifier = state.dataSources[0].identifier;
    fillSourceForm(state.dataSources[0]);
    renderSourcesList();
    return;
  }
  elements.sourceForm.classList.add("hidden");
  elements.sourcesStatus.textContent = "No sources yet. Create one.";
}

function blankTheme() {
  return {
    id: null,
    name: "",
    builtInThemeName: "",
    supportsLightMode: true,
    headlineFontStyle: "system-default",
    bodyFontStyle: "system-default",
    accent: { red: 0.2745, green: 0.4392, blue: 1, alpha: 1 },
    secondaryAccent: { red: 0.2471, green: 0.3529, blue: 0.7216, alpha: 1 },
    darkModeHeadlineColor: { red: 0.8078, green: 0.8471, blue: 1, alpha: 1 },
    lightModeHeadlineColor: { red: 0.1216, green: 0.1765, blue: 0.3412, alpha: 1 },
    darkModeBackground: { red: 0.0588, green: 0.0706, blue: 0.1255, alpha: 1 },
    lightModeBackground: { red: 0.9608, green: 0.9686, blue: 1, alpha: 1 },
  };
}

function themeFontStyleToCss(style, isHeadline) {
  const normalized = String(style || "system-default").toLowerCase();
  switch (normalized) {
    case "system-rounded":
      return isHeadline
        ? '"SF Pro Rounded", "Arial Rounded MT Bold", "Helvetica Neue", Arial, sans-serif'
        : '"SF Pro Rounded", "Helvetica Neue", Arial, sans-serif';
    case "system-monospaced":
      return 'ui-monospace, "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace';
    case "new-york":
      return '"New York", "Times New Roman", Georgia, serif';
    case "system-condensed":
      return '"SF Pro Display", "Arial Narrow", "Helvetica Neue", Arial, sans-serif';
    case "system-default":
    default:
      return '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif';
  }
}

function themePreviewColor(field, fallback) {
  const normalized = normalizeHexColor(field?.value || "");
  return normalized || fallback;
}

function captureThemeFormState() {
  return {
    name: themeFormFields.name.value,
    builtInThemeName: themeFormFields.builtInThemeName.value,
    supportsLightMode: themeFormFields.supportsLightMode.value,
    headlineFontStyle: themeFormFields.headlineFontStyle.value,
    bodyFontStyle: themeFormFields.bodyFontStyle.value,
    accent: themeFormFields.accent.value,
    secondaryAccent: themeFormFields.secondaryAccent.value,
    darkModeHeadlineColor: themeFormFields.darkModeHeadlineColor.value,
    lightModeHeadlineColor: themeFormFields.lightModeHeadlineColor.value,
    darkModeBackground: themeFormFields.darkModeBackground.value,
    lightModeBackground: themeFormFields.lightModeBackground.value,
  };
}

function themeStatesEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function updateThemeUndoButton() {
  if (!elements.themeUndoBtn) {
    return;
  }
  elements.themeUndoBtn.disabled = themeUndoState.cursor <= 0;
}

function initializeThemeUndoHistory() {
  const snapshot = captureThemeFormState();
  themeUndoState.history = [snapshot];
  themeUndoState.cursor = 0;
  updateThemeUndoButton();
}

function commitThemeUndoSnapshotImmediate() {
  if (themeUndoState.isApplyingSnapshot) {
    return;
  }
  const snapshot = captureThemeFormState();
  const current = themeUndoState.history[themeUndoState.cursor];
  if (current && themeStatesEqual(current, snapshot)) {
    return;
  }
  if (themeUndoState.cursor < themeUndoState.history.length - 1) {
    themeUndoState.history = themeUndoState.history.slice(0, themeUndoState.cursor + 1);
  }
  themeUndoState.history.push(snapshot);
  themeUndoState.cursor = themeUndoState.history.length - 1;
  updateThemeUndoButton();
}

function scheduleThemeUndoSnapshotCommit() {
  if (themeUndoState.commitTimer) {
    clearTimeout(themeUndoState.commitTimer);
  }
  themeUndoState.commitTimer = setTimeout(() => {
    themeUndoState.commitTimer = null;
    commitThemeUndoSnapshotImmediate();
  }, 180);
}

function flushThemeUndoSnapshotCommit() {
  if (themeUndoState.commitTimer) {
    clearTimeout(themeUndoState.commitTimer);
    themeUndoState.commitTimer = null;
  }
  commitThemeUndoSnapshotImmediate();
}

function applyThemeFormStateSnapshot(snapshot) {
  if (!snapshot) {
    return;
  }
  themeUndoState.isApplyingSnapshot = true;
  themeFormFields.name.value = snapshot.name ?? "";
  themeFormFields.builtInThemeName.value = snapshot.builtInThemeName ?? "";
  themeFormFields.supportsLightMode.value = snapshot.supportsLightMode ?? "true";
  themeFormFields.headlineFontStyle.value = snapshot.headlineFontStyle ?? "system-default";
  themeFormFields.bodyFontStyle.value = snapshot.bodyFontStyle ?? "system-default";
  themeFormFields.accent.value = snapshot.accent ?? themeFormFields.accent.value;
  themeFormFields.secondaryAccent.value =
    snapshot.secondaryAccent ?? themeFormFields.secondaryAccent.value;
  themeFormFields.darkModeHeadlineColor.value =
    snapshot.darkModeHeadlineColor ?? themeFormFields.darkModeHeadlineColor.value;
  themeFormFields.lightModeHeadlineColor.value =
    snapshot.lightModeHeadlineColor ?? themeFormFields.lightModeHeadlineColor.value;
  themeFormFields.darkModeBackground.value =
    snapshot.darkModeBackground ?? themeFormFields.darkModeBackground.value;
  themeFormFields.lightModeBackground.value =
    snapshot.lightModeBackground ?? themeFormFields.lightModeBackground.value;
  themeUndoState.isApplyingSnapshot = false;
  updateThemeSwatches();
  renderThemePreview();
}

function undoThemeFormChange() {
  flushThemeUndoSnapshotCommit();
  if (themeUndoState.cursor <= 0) {
    updateThemeUndoButton();
    return;
  }
  themeUndoState.cursor -= 1;
  const snapshot = themeUndoState.history[themeUndoState.cursor];
  applyThemeFormStateSnapshot(snapshot);
  updateThemeUndoButton();
}

function renderThemePreview() {
  const root = elements.themePreviewRoot;
  if (!root) {
    return;
  }
  const mode = elements.themePreviewMode?.value || "dark";
  const supportsLightMode = themeFormFields.supportsLightMode.value === "true";
  const accent = themePreviewColor(themeFormFields.accent, "#4670ff");
  const secondaryAccent = themePreviewColor(themeFormFields.secondaryAccent, "#3f5ab8");
  const darkModeHeadlineColor = themePreviewColor(themeFormFields.darkModeHeadlineColor, "#cfd8ff");
  const lightModeHeadlineColor = themePreviewColor(themeFormFields.lightModeHeadlineColor, "#1f2430");
  const darkBackground = themePreviewColor(themeFormFields.darkModeBackground, "#0b1220");
  const lightBackground = themePreviewColor(themeFormFields.lightModeBackground, "#f5f7ff");
  const darkBackgroundTint = deriveBackgroundTintHex(darkBackground, "dark") || "#121a2c";
  const lightBackgroundTint = deriveBackgroundTintHex(lightBackground, "light") || "#edf1f8";
  const effectiveMode = mode === "light" && supportsLightMode ? "light" : "dark";
  const headlineColor = effectiveMode === "light" ? lightModeHeadlineColor : darkModeHeadlineColor;
  const backgroundTint = effectiveMode === "light" ? lightBackgroundTint : darkBackgroundTint;
  const rootBackground = effectiveMode === "light" ? lightBackground : darkBackground;
  const surfaceBackground = effectiveMode === "light" ? "#ffffffde" : "#11172ae6";
  const textColor = effectiveMode === "light" ? "#1f2430" : "#f2f4f8";
  const mutedColor = effectiveMode === "light" ? "#4e576b" : "#b3bac7";
  const borderColor = effectiveMode === "light" ? "#6c789940" : "#8d9bba45";

  root.classList.toggle("theme-preview-mode-light", effectiveMode === "light");
  root.classList.toggle("theme-preview-mode-dark", effectiveMode === "dark");
  root.style.setProperty("--tp-accent", accent);
  root.style.setProperty("--tp-secondary-accent", secondaryAccent);
  root.style.setProperty("--tp-headline", headlineColor);
  root.style.setProperty("--tp-bg", rootBackground);
  root.style.setProperty("--tp-surface", surfaceBackground);
  root.style.setProperty("--tp-text", textColor);
  root.style.setProperty("--tp-muted", mutedColor);
  root.style.setProperty("--tp-border", borderColor);
  root.style.setProperty("--tp-headline-font", themeFontStyleToCss(themeFormFields.headlineFontStyle.value, true));
  root.style.setProperty("--tp-body-font", themeFontStyleToCss(themeFormFields.bodyFontStyle.value, false));
  root.style.setProperty("--tp-background-tint", backgroundTint);
}

async function loadThemes() {
  const response = await fetch("/api/themes");
  if (!response.ok) {
    throw new Error("Failed to load themes");
  }
  const data = await response.json();
  state.themes = Array.isArray(data.themes) ? data.themes : [];
}

function renderThemesList() {
  elements.themesList.innerHTML = "";
  const themes = [...state.themes].sort((a, b) => a.name.localeCompare(b.name));
  themes.forEach((theme) => {
    const row = document.createElement("div");
    row.className = "theme-list-item";
    if (String(theme.id) === String(state.selectedThemeId)) {
      row.classList.add("selected");
    }
    const builtInTag = theme.builtInThemeName ? `Overrides ${theme.builtInThemeName}` : "Custom";
    row.innerHTML = `
      <div class="theme-list-title">${theme.name}</div>
      <div class="theme-list-subtitle">${builtInTag}</div>
    `;
    row.addEventListener("click", () => {
      state.selectedThemeId = theme.id;
      fillThemeForm(theme);
      renderThemesList();
    });
    elements.themesList.append(row);
  });
}

function fillThemeForm(theme) {
  const value = theme || blankTheme();
  elements.themeForm.classList.remove("hidden");
  elements.themesStatus.textContent = value.id
    ? `Editing "${value.name}"`
    : "New theme (not saved yet)";
  themeFormFields.name.value = value.name || "";
  themeFormFields.builtInThemeName.value = value.builtInThemeName || "";
  themeFormFields.supportsLightMode.value = value.supportsLightMode ? "true" : "false";
  themeFormFields.headlineFontStyle.value = value.headlineFontStyle || "system-default";
  themeFormFields.bodyFontStyle.value = value.bodyFontStyle || "system-default";
  themeFormFields.accent.value = themeColorToHex(value.accent);
  themeFormFields.secondaryAccent.value = themeColorToHex(value.secondaryAccent);
  themeFormFields.darkModeHeadlineColor.value = themeColorToHex(
    value.darkModeHeadlineColor || value.headlineColor
  );
  themeFormFields.lightModeHeadlineColor.value = themeColorToHex(
    value.lightModeHeadlineColor || value.headlineColor
  );
  themeFormFields.darkModeBackground.value = themeColorToHex(value.darkModeBackground);
  themeFormFields.lightModeBackground.value = themeColorToHex(value.lightModeBackground);
  updateThemeSwatches();
  initializeThemeUndoHistory();
}

function buildThemePayload() {
  const accent = parseHexColor(themeFormFields.accent.value);
  const secondaryAccent = parseHexColor(themeFormFields.secondaryAccent.value);
  const darkModeHeadlineColor = parseHexColor(themeFormFields.darkModeHeadlineColor.value);
  const lightModeHeadlineColor = parseHexColor(themeFormFields.lightModeHeadlineColor.value);
  const darkModeBackground = parseHexColor(themeFormFields.darkModeBackground.value);
  const lightModeBackground = parseHexColor(themeFormFields.lightModeBackground.value);
  const darkModeBackgroundTint = parseHexColor(
    deriveBackgroundTintHex(themeFormFields.darkModeBackground.value, "dark") || ""
  );
  const lightModeBackgroundTint = parseHexColor(
    deriveBackgroundTintHex(themeFormFields.lightModeBackground.value, "light") || ""
  );
  if (
    !accent ||
    !secondaryAccent ||
    !darkModeHeadlineColor ||
    !lightModeHeadlineColor ||
    !darkModeBackgroundTint ||
    !lightModeBackgroundTint ||
    !darkModeBackground ||
    !lightModeBackground
  ) {
    return null;
  }
  return {
    id: state.selectedThemeId,
    name: themeFormFields.name.value.trim(),
    builtInThemeName: themeFormFields.builtInThemeName.value.trim() || null,
    supportsLightMode: themeFormFields.supportsLightMode.value === "true",
    headlineFontStyle: themeFormFields.headlineFontStyle.value || "system-default",
    bodyFontStyle: themeFormFields.bodyFontStyle.value || "system-default",
    accent,
    secondaryAccent,
    // Backward compatibility: older server versions only accept headlineColor.
    headlineColor: darkModeHeadlineColor,
    darkModeHeadlineColor,
    lightModeHeadlineColor,
    // Backward compatibility for older native decoding paths.
    backgroundTint: darkModeBackgroundTint,
    darkModeBackgroundTint,
    lightModeBackgroundTint,
    darkModeBackground,
    lightModeBackground,
  };
}

async function saveTheme() {
  flushThemeUndoSnapshotCommit();
  const payload = buildThemePayload();
  if (!payload || !payload.name) {
    showToast("Theme name and valid hex colors are required", true);
    return;
  }
  const isUpdate = state.selectedThemeId && state.themes.some((t) => t.id === state.selectedThemeId);
  const endpoint = isUpdate
    ? `/api/themes/${encodeURIComponent(state.selectedThemeId)}`
    : "/api/themes";
  const method = isUpdate ? "PUT" : "POST";
  const response = await fetch(endpoint, {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    showToast(body.error || "Failed to save theme", true);
    return;
  }
  const data = await response.json();
  state.selectedThemeId = data.theme?.id || null;
  await loadThemes();
  if (state.selectedThemeId) {
    const selected = state.themes.find((theme) => String(theme.id) === String(state.selectedThemeId));
    fillThemeForm(selected || blankTheme());
  }
  renderThemesList();
  showToast("Theme saved");
}

async function deleteTheme() {
  if (!state.selectedThemeId) {
    showToast("Select a theme first", true);
    return;
  }
  const response = await fetch(`/api/themes/${encodeURIComponent(state.selectedThemeId)}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    showToast("Failed to delete theme", true);
    return;
  }
  state.selectedThemeId = null;
  await loadThemes();
  renderThemesList();
  elements.themeForm.classList.add("hidden");
  elements.themesStatus.textContent = "No theme selected.";
  fillThemeForm(blankTheme());
  elements.themeForm.classList.add("hidden");
  showToast("Theme deleted");
}

async function openThemesModal() {
  try {
    await loadThemes();
    elements.themesModal.classList.remove("hidden");
    renderThemesList();
    if (state.selectedThemeId) {
      const selected = state.themes.find((theme) => String(theme.id) === String(state.selectedThemeId));
      fillThemeForm(selected || blankTheme());
    } else if (state.themes.length) {
      state.selectedThemeId = state.themes[0].id;
      fillThemeForm(state.themes[0]);
      renderThemesList();
    } else {
      elements.themeForm.classList.add("hidden");
      elements.themesStatus.textContent = "No themes yet. Create one.";
      fillThemeForm(blankTheme());
      elements.themeForm.classList.add("hidden");
    }
  } catch (error) {
    showToast(error.message || "Failed to open theme editor", true);
  }
}

function closeThemesModal() {
  elements.themesModal.classList.add("hidden");
  closeThemeColorPicker();
}

function createThemeDraft() {
  state.selectedThemeId = null;
  fillThemeForm(blankTheme());
  renderThemesList();
}

function getThemeColorFieldById(fieldId) {
  return Object.values(themeFormFields).find((field) => field && field.id === fieldId) || null;
}

function updateThemeSwatches() {
  const mapping = [
    ["accent", themeFormFields.accent],
    ["secondaryAccent", themeFormFields.secondaryAccent],
    ["darkModeHeadlineColor", themeFormFields.darkModeHeadlineColor],
    ["lightModeHeadlineColor", themeFormFields.lightModeHeadlineColor],
    ["darkModeBackground", themeFormFields.darkModeBackground],
    ["lightModeBackground", themeFormFields.lightModeBackground],
  ];
  mapping.forEach(([key, field]) => {
    const swatch = themeSwatches[key];
    if (!swatch || !field) {
      return;
    }
    const normalized = normalizeHexColor(field.value);
    swatch.style.background = normalized || "#202733";
  });
  renderThemePreview();
}

function positionThemeColorPicker(anchorElement) {
  const anchorRect = anchorElement.getBoundingClientRect();
  const picker = elements.themeColorPickerPopover;
  const pickerWidth = 300;
  const pickerHeight = 320;
  const spacing = 8;
  let left = anchorRect.left;
  let top = anchorRect.bottom + spacing;
  if (left + pickerWidth > window.innerWidth - 12) {
    left = window.innerWidth - pickerWidth - 12;
  }
  if (top + pickerHeight > window.innerHeight - 12) {
    top = Math.max(12, anchorRect.top - pickerHeight - spacing);
  }
  picker.style.left = `${Math.max(12, left)}px`;
  picker.style.top = `${Math.max(12, top)}px`;
}

function renderThemeColorPicker() {
  const { hue, saturation, value } = themeColorPickerState;
  const hueColor = `hsl(${Math.round(hue)}, 100%, 50%)`;
  elements.themeSvSquare.style.background = `
    linear-gradient(to top, #000, rgba(0, 0, 0, 0)),
    linear-gradient(to right, #fff, ${hueColor})
  `;
  const svRect = elements.themeSvSquare.getBoundingClientRect();
  elements.themeSvCursor.style.left = `${Math.round(saturation * svRect.width)}px`;
  elements.themeSvCursor.style.top = `${Math.round((1 - value) * svRect.height)}px`;
  const hueRect = elements.themeHueStrip.getBoundingClientRect();
  elements.themeHueCursor.style.top = `${Math.round((hue / 360) * hueRect.height)}px`;
  const rgb = hsvToRgb(hue, saturation, value);
  const hex = themeColorToHex(rgb);
  elements.themeColorPickerHex.value = hex;
  elements.themeColorPickerPreview.style.background = hex;
}

function applyThemeColorFromPicker() {
  const field = themeColorPickerState.activeField;
  if (!field) {
    return;
  }
  const rgb = hsvToRgb(
    themeColorPickerState.hue,
    themeColorPickerState.saturation,
    themeColorPickerState.value
  );
  field.value = themeColorToHex(rgb);
  updateThemeSwatches();
  renderThemeColorPicker();
  scheduleThemeUndoSnapshotCommit();
}

function openThemeColorPicker(field, anchorElement = null) {
  const parsed = parseHexColor(field.value) || { red: 1, green: 0, blue: 0, alpha: 1 };
  const hsv = rgbToHsv(parsed);
  themeColorPickerState.activeField = field;
  themeColorPickerState.activeAnchorElement = anchorElement || field;
  themeColorPickerState.activeFieldLabel = field.dataset.colorLabel || "Color Picker";
  themeColorPickerState.hue = hsv.hue;
  themeColorPickerState.saturation = hsv.saturation;
  themeColorPickerState.value = hsv.value;
  elements.themeColorPickerLabel.textContent = themeColorPickerState.activeFieldLabel;
  elements.themeColorPickerPopover.classList.remove("hidden");
  positionThemeColorPicker(themeColorPickerState.activeAnchorElement);
  renderThemeColorPicker();
}

function closeThemeColorPicker() {
  elements.themeColorPickerPopover.classList.add("hidden");
  themeColorPickerState.activeField = null;
  themeColorPickerState.activeAnchorElement = null;
  themeColorPickerState.draggingHue = false;
  themeColorPickerState.draggingSv = false;
}

function updatePickerSvFromClientPosition(clientX, clientY) {
  const rect = elements.themeSvSquare.getBoundingClientRect();
  const x = Math.max(0, Math.min(rect.width, clientX - rect.left));
  const y = Math.max(0, Math.min(rect.height, clientY - rect.top));
  themeColorPickerState.saturation = rect.width ? x / rect.width : 0;
  themeColorPickerState.value = rect.height ? 1 - y / rect.height : 0;
  applyThemeColorFromPicker();
}

function updatePickerHueFromClientPosition(clientY) {
  const rect = elements.themeHueStrip.getBoundingClientRect();
  const y = Math.max(0, Math.min(rect.height, clientY - rect.top));
  themeColorPickerState.hue = rect.height ? (y / rect.height) * 360 : 0;
  applyThemeColorFromPicker();
}

function renderStreamingReport() {
  const report = streamingReportState.report;
  if (!report) {
    elements.streamingStatus.textContent = "No report available.";
    return;
  }
  if (report.failedCount > 0) {
    elements.streamingStatus.textContent = `Updated ${report.updatedCount} of ${report.totalCount} movies (${report.failedCount} failed).`;
  } else {
    elements.streamingStatus.textContent = `Updated ${report.updatedCount} of ${report.totalCount} movies.`;
  }
  elements.streamingSummary.innerHTML = [
    ["Updated", report.updatedCount],
    ["Unchanged", report.unchangedCount],
    ["Skipped", report.skippedCount],
    ["Failed", report.failedCount || 0],
  ]
    .map(
      ([label, value]) => `
        <div class="health-metric">
          <strong>${value}</strong>
          ${label}
        </div>
      `
    )
    .join("");

  const rows = report.items
    .map(
      (item) => `
      <tr>
        <td>${item.title || ""}</td>
        <td>${item.tmdbId || ""}</td>
        <td>${item.status || ""}</td>
      </tr>
    `
    )
    .join("");
  elements.streamingItems.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Title</th>
          <th>TMDB</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function renderReport() {
  const report = reportState.report;
  if (!report) {
    elements.reportStatus.textContent = "No report available.";
    return;
  }
  elements.reportStatus.textContent = `Added ${report.addedCount} items from ${report.sourceCount} feed(s).`;
  elements.reportSummary.innerHTML = [
    ["Added", report.addedCount],
    ["Skipped", report.skippedCount],
    ["No Match", report.missingCount],
    ["Data-light", report.lightCount],
  ]
    .map(
      ([label, value]) => `
        <div class="health-metric">
          <strong>${value}</strong>
          ${label}
        </div>
      `
    )
    .join("");

  const rows = report.items
    .map(
      (item) => `
      <tr>
        <td>${item.sourceName || ""}</td>
        <td>${item.title || ""}</td>
        <td>${item.status || ""}</td>
        <td>${item.tmdbId || ""}</td>
      </tr>
    `
    )
    .join("");
  elements.reportItems.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Source</th>
          <th>Title</th>
          <th>Status</th>
          <th>TMDB</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

async function loadDedupeGroups() {
  elements.dedupeStatus.textContent = "Loading duplicates...";
  const response = await fetch("/api/dedupe/preview");
  if (!response.ok) {
    elements.dedupeStatus.textContent = "Failed to load duplicates.";
    return;
  }
  const data = await response.json();
  dedupeState.groups = data.groups || [];
  if (!dedupeState.groups.length) {
    elements.dedupeStatus.textContent = "No duplicates detected.";
  } else {
    elements.dedupeStatus.textContent = `Found ${dedupeState.groups.length} duplicate groups.`;
  }
  renderDedupeGroups();
}

function renderDedupeGroups() {
  elements.dedupeGroups.innerHTML = "";
  dedupeState.groups.forEach((group, groupIndex) => {
    const wrapper = document.createElement("div");
    wrapper.className = "dedupe-group";
    wrapper.innerHTML = `
      <div class="dedupe-title">${group.title}</div>
      <div class="dedupe-meta">Source: ${group.sourceName} (${group.sourceIdentifier})</div>
      <div class="dedupe-items"></div>
    `;
    const itemsContainer = wrapper.querySelector(".dedupe-items");
    group.items.forEach((item, itemIndex) => {
      const row = document.createElement("label");
      row.className = "dedupe-item";
      row.innerHTML = `
        <input type="radio" name="dedupe-${groupIndex}" value="${item.index}" ${
          itemIndex === 0 ? "checked" : ""
        }>
        <span>${item.title}${item.year ? ` (${item.year})` : ""}</span>
        <span class="dedupe-meta">TMDB ${item.tmdbId || "—"}</span>
      `;
      itemsContainer.append(row);
    });
    elements.dedupeGroups.append(wrapper);
  });
}

async function commitDedupe() {
  const selections = dedupeState.groups.map((group, groupIndex) => {
    const selected = elements.dedupeGroups.querySelector(
      `input[name="dedupe-${groupIndex}"]:checked`
    );
    return {
      key: group.key,
      keepIndex: selected ? Number(selected.value) : group.items[0].index,
    };
  });

  const response = await fetch("/api/dedupe/commit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ selections }),
  });

  if (!response.ok) {
    showToast("Dedupe failed", true);
    return;
  }
  await reloadData(state.selectedMovieIndex);
  closeDedupeModal();
  showToast("Duplicates removed");
}

function setIngestStep(step) {
  const isFeedMode = ingestState.mode === "refreshFeeds" || ingestState.mode === "latestPodcasts";
  elements.ingestStepConfig.classList.toggle("hidden", step !== "config" || isFeedMode);
  elements.refreshFeedsStepConfig.classList.toggle("hidden", step !== "config" || !isFeedMode);
  elements.ingestStepPreview.classList.toggle("hidden", step !== "preview");
  elements.ingestStepReview.classList.toggle("hidden", step !== "review");
}

function renderFeedsList() {
  elements.feedsList.innerHTML = "";
  const feeds = state.dataSources.filter((source) => source.type === "podcast");
  feeds.forEach((source) => {
    const row = document.createElement("label");
    row.className = "feeds-item";
    row.innerHTML = `
      <input type="checkbox" value="${source.identifier}">
      <span>${source.name}</span>
    `;
    elements.feedsList.append(row);
  });
  elements.feedsList.querySelectorAll("input[type='checkbox']").forEach((input) => {
    input.addEventListener("change", () => {
      ingestState.selectedFeeds = Array.from(
        elements.feedsList.querySelectorAll("input[type='checkbox']:checked")
      ).map((checkbox) => checkbox.value);
    });
  });
}

function renderIngestPreview() {
  elements.ingestPreviewBody.innerHTML = "";
  const counts = {
    total: ingestState.previewItems.length,
    enriched: ingestState.previewItems.filter((item) => item.status === "enriched").length,
    light: ingestState.previewItems.filter((item) => item.status === "light").length,
    missing: ingestState.previewItems.filter((item) => item.status === "missing").length,
    duplicates: ingestState.previewItems.filter((item) => item.isDuplicate).length,
  };
  elements.ingestPreviewSummary.textContent = `Total ${counts.total}   Enriched ${counts.enriched}   Data-light ${counts.light}   No-match ${counts.missing}   Duplicates ${counts.duplicates}`;
  const latestStatsBySource = new Map(
    ingestState.latestSourceStats.map((stat) => [stat.sourceIdentifier, stat])
  );
  if (ingestState.mode === "latestPodcasts" && ingestState.latestSourceStats.length) {
    elements.ingestLatestStats.textContent = ingestState.latestSourceStats
      .map((stat) => {
        const latestKnown = formatDateForUi(stat.latestKnownEpisodeDate);
        const latestTitle = stat.latestKnownSourceTitle || "—";
        const stopReason = stat.stopReason || "none";
        const skippedByNoise = stat.skippedByNoise || 0;
        return `${stat.sourceName}: latest known ${latestKnown} ("${latestTitle}"), scanned ${stat.scannedCount || 0}, candidates ${stat.candidateCount || 0}, noise-skipped ${skippedByNoise}, stop=${stopReason}`;
      })
      .join(" | ");
  } else {
    elements.ingestLatestStats.textContent = "";
  }

  ingestState.previewItems.forEach((item, index) => {
    const row = document.createElement("tr");
    const statusLabel =
      item.status === "enriched"
        ? "Enriched"
        : item.status === "missing"
          ? "No Match"
          : "Data-light";
    const statusClass =
      item.status === "enriched"
        ? "enriched"
        : item.status === "missing"
          ? "missing"
          : "light";
    const sourceStat = latestStatsBySource.get(item.sourceIdentifier);
    const episodeDate = formatDateForUi(item.episodeDate);
    const latestKnown = formatDateForUi(sourceStat?.latestKnownEpisodeDate);
    row.innerHTML = `
      <td><input type="checkbox" data-index="${index}" ${item.selected ? "checked" : ""}></td>
      <td>${item.sourceName || ""}</td>
      <td><input type="text" data-title-index="${index}" value="${item.title || ""}"></td>
      <td>${item.sourceTitle || ""}</td>
      <td>${item.rank ?? ""}</td>
      <td>${episodeDate}</td>
      <td>${latestKnown}</td>
      <td><span class="status-pill ${statusClass}">${statusLabel}</span></td>
      <td>${item.isDuplicate ? "Yes" : "No"}</td>
      <td>${item.tmdbId || ""}</td>
      <td><button data-enrich-index="${index}">Enrich It</button></td>
    `;
    elements.ingestPreviewBody.append(row);
  });

  elements.ingestPreviewBody.querySelectorAll("input[type='checkbox']").forEach((input) => {
    input.addEventListener("change", (event) => {
      const index = Number(event.target.dataset.index);
      ingestState.previewItems[index].selected = event.target.checked;
    });
  });

  elements.ingestPreviewBody.querySelectorAll("input[data-title-index]").forEach((input) => {
    input.addEventListener("input", (event) => {
      const index = Number(event.target.dataset.titleIndex);
      ingestState.previewItems[index].title = event.target.value;
    });
  });

  elements.ingestPreviewBody.querySelectorAll("button[data-enrich-index]").forEach((button) => {
    button.addEventListener("click", async (event) => {
      event.preventDefault();
      const index = Number(event.target.dataset.enrichIndex);
      await enrichSingleIngestItem(index);
    });
  });
}

async function previewIngestItems() {
  if (ingestState.mode === "refreshFeeds") {
    await previewRefreshFeeds();
    return;
  }
  if (ingestState.mode === "latestPodcasts") {
    await previewLatestPodcasts();
    return;
  }
  const identifier = elements.ingestIdentifier.value.trim();
  const name = elements.ingestName.value.trim();
  const url = elements.ingestUrl.value.trim();
  const isRanked = elements.ingestRanked.value === "true";

  if (!identifier || !name || !url) {
    showToast("Identifier, name, and URL required", true);
    return;
  }

  const response = await fetch("/api/ingest/preview", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      sourceType: ingestState.sourceType,
      identifier,
      name,
      url,
      isRankedList: isRanked,
    }),
  });
  if (!response.ok) {
    showToast("Preview failed", true);
    return;
  }
  const data = await response.json();
  ingestState.previewItems = data.items.map((item) => ({
    ...item,
    sourceName: name,
    selected: item.status !== "missing" && !item.isDuplicate,
  }));
  renderIngestPreview();
  setIngestStep("preview");
}

async function previewRefreshFeeds() {
  if (!ingestState.selectedFeeds.length) {
    showToast("Select at least one feed", true);
    return;
  }
  elements.feedsLoader.classList.remove("hidden");
  const response = await fetch("/api/feeds/preview", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifiers: ingestState.selectedFeeds }),
  });
  if (!response.ok) {
    elements.feedsLoader.classList.add("hidden");
    showToast("Feed preview failed", true);
    return;
  }
  const data = await response.json();
  ingestState.latestSourceStats = [];
  ingestState.previewItems = data.items.map((item) => ({
    ...item,
    selected: item.status !== "missing" && !item.isDuplicate,
  }));
  elements.feedsLoader.classList.add("hidden");
  renderIngestPreview();
  setIngestStep("preview");
}

async function previewLatestPodcasts() {
  if (!ingestState.selectedFeeds.length) {
    showToast("Select at least one feed", true);
    return;
  }
  elements.feedsLoader.classList.remove("hidden");
  const response = await fetch("/api/podcasts/latest/preview", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifiers: ingestState.selectedFeeds }),
  });
  if (!response.ok) {
    elements.feedsLoader.classList.add("hidden");
    showToast("Latest preview failed", true);
    return;
  }
  const data = await response.json();
  const sourceStats = Array.isArray(data.sourceStats) ? data.sourceStats : [];
  ingestState.latestSourceStats = sourceStats;
  if (sourceStats.length) {
    const totalScanned = sourceStats.reduce(
      (sum, stat) => sum + (stat.scannedCount || 0),
      0
    );
    const earlyStoppedSources = sourceStats.filter((stat) => stat.stoppedEarly).length;
    const withWatermark = sourceStats.filter(
      (stat) => stat.latestKnownEpisodeDate
    ).length;
    const totalNoiseSkipped = sourceStats.reduce(
      (sum, stat) => sum + (stat.skippedByNoise || 0),
      0
    );
    elements.podcastStatus.textContent =
      `Latest mode: scanned ${totalScanned} episodes across ${sourceStats.length} feed(s), ` +
      `${earlyStoppedSources} stopped early, ${withWatermark} with known latest episode, ${totalNoiseSkipped} skipped as non-movie noise.`;
  } else {
    elements.podcastStatus.textContent = "Latest mode: no source stats returned.";
  }
  ingestState.previewItems = data.items.map((item) => ({
    ...item,
    selected: item.status !== "missing" && !item.isDuplicate,
  }));
  elements.feedsLoader.classList.add("hidden");
  renderIngestPreview();
  setIngestStep("preview");
}

async function enrichIngestItems() {
  const selectedItems = ingestState.previewItems.filter((item) => item.selected);
  if (!selectedItems.length) {
    showToast("Select items to enrich", true);
    return;
  }
  const response = await fetch("/api/ingest/enrich", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ items: selectedItems }),
  });
  if (!response.ok) {
    showToast("Enrich failed", true);
    return;
  }
  const data = await response.json();
  ingestState.previewItems = ingestState.previewItems.map((item) => {
    const enriched = data.items.find((entry) => entry.sourceTitle === item.sourceTitle);
    if (!enriched) {
      return item;
    }
    const updated = { ...item, ...enriched };
    updated.selected = updated.status !== "missing";
    return updated;
  });
  renderIngestPreview();
  showToast("Enrichment complete");
}

async function enrichSingleIngestItem(index) {
  const item = ingestState.previewItems[index];
  if (!item) {
    return;
  }
  const response = await fetch("/api/ingest/enrich", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ items: [item] }),
  });
  if (!response.ok) {
    showToast("Enrich failed", true);
    return;
  }
  const data = await response.json();
  const enriched = data.items?.[0];
  if (enriched) {
    const updated = { ...item, ...enriched };
    updated.selected = updated.status !== "missing";
    ingestState.previewItems[index] = updated;
    renderIngestPreview();
  }
}

function selectIngestByStatus(status) {
  ingestState.previewItems = ingestState.previewItems.map((item) => ({
    ...item,
    selected: item.status === status,
  }));
  renderIngestPreview();
}

function deselectDuplicateIngest() {
  ingestState.previewItems = ingestState.previewItems.map((item) => ({
    ...item,
    selected: item.isDuplicate ? false : item.selected,
  }));
  renderIngestPreview();
}

function reviewIngestItems() {
  const selectedCount = ingestState.previewItems.filter((item) => item.selected).length;
  const duplicateCount = ingestState.previewItems.filter((item) => item.isDuplicate).length;
  elements.ingestSummary.textContent = `${selectedCount} items selected. ${duplicateCount} duplicates flagged.`;
  setIngestStep("review");
}

async function commitIngestItems() {
  const identifier = elements.ingestIdentifier.value.trim();
  const name = elements.ingestName.value.trim();
  const url = elements.ingestUrl.value.trim();
  const isRanked = elements.ingestRanked.value === "true";
  const items = ingestState.previewItems.filter((item) => item.selected);

  if (!items.length) {
    showToast("No items selected", true);
    return;
  }

  const endpoint =
    ingestState.mode === "refreshFeeds"
      ? "/api/feeds/commit"
      : ingestState.mode === "latestPodcasts"
        ? "/api/podcasts/latest/commit"
        : "/api/ingest/commit";
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      sourceType: ingestState.sourceType,
      identifier,
      name,
      url,
      isRankedList: isRanked,
      items,
    }),
  });

  if (!response.ok) {
    showToast("Commit failed", true);
    return;
  }

  const data = await response.json();
  await reloadData();
  closeIngestModal();
  showToast("Items added to bootstrap");
  if (ingestState.mode === "refreshFeeds" || ingestState.mode === "latestPodcasts") {
    openReportModal(data.report);
  }
}
async function refreshStreamingForSelected() {
  if (state.selectedMovieIndex === null) {
    showToast("Select a movie first", true);
    return;
  }
  openConfirmModal({
    message:
      "Refresh streaming services for the selected movie? This will update the Min Cloud catalog.",
    onConfirm: async () => {
      const response = await fetch(
        `/api/movies/${state.selectedMovieIndex}/streaming/refresh`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ region: "US" }),
        }
      );
      if (!response.ok) {
        const message = await readErrorMessage(response, "Streaming refresh failed");
        showToast(message, true);
        return;
      }
      await reloadData(state.selectedMovieIndex);
      showToast("Streaming services updated");
    },
  });
}

async function refreshStreamingAll() {
  openConfirmModal({
    message:
      "Refresh streaming services for all movies? This writes to the Min Cloud catalog and may take several minutes.",
    onConfirm: async () => {
      openStreamingModal("Refreshing streaming services...");
      elements.refreshStreamingAllBtn.disabled = true;
      elements.refreshStreamingAllBtn.textContent = "Refreshing...";
      const response = await fetch("/api/streaming/refresh-all", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ region: "US", delayMs: 150 }),
      });
      elements.refreshStreamingAllBtn.disabled = false;
      elements.refreshStreamingAllBtn.textContent = "Refresh Streaming (All)";
      if (!response.ok) {
        const message = await readErrorMessage(response, "Streaming refresh failed");
        elements.streamingStatus.textContent = message;
        showToast(message, true);
        return;
      }
      const data = await response.json();
      await reloadData(state.selectedMovieIndex);
      streamingReportState.report = data.report;
      renderStreamingReport();
      if (data.report?.failedCount > 0) {
        showToast(
          `Streaming refresh completed with ${data.report.failedCount} failures`,
          true
        );
      } else {
        showToast("Streaming services refreshed");
      }
    },
  });
}

async function reloadData(selectIndex = null) {
  await fetchBootstrap();
  populateFilters();
  applyFilters();
  if (selectIndex !== null) {
    selectMovie(selectIndex);
  }
}

async function searchTmdb() {
  const query = elements.tmdbQuery.value.trim();
  if (!query) {
    return;
  }
  elements.tmdbResults.textContent = "Searching...";
  const params = new URLSearchParams({ query });
  if (elements.tmdbYear.value) {
    params.set("year", elements.tmdbYear.value);
  }
  const response = await fetch(`/api/tmdb/search?${params.toString()}`);
  if (!response.ok) {
    elements.tmdbResults.textContent = "Search failed";
    return;
  }
  const data = await response.json();
  renderTmdbResults(data.results || []);
}

function renderTmdbResults(results) {
  elements.tmdbResults.innerHTML = "";
  if (!results.length) {
    elements.tmdbResults.textContent = "No results.";
    return;
  }
  results.slice(0, 8).forEach((result) => {
    const entry = document.createElement("div");
    entry.className = "tmdb-result";
    const year = result.release_date ? result.release_date.slice(0, 4) : "—";
    entry.innerHTML = `
      <div class="tmdb-title">${result.title} (${year})</div>
      <div class="tmdb-meta">TMDB ID: ${result.id}</div>
    `;
    const applyButton = document.createElement("button");
    applyButton.textContent = "Apply";
    applyButton.addEventListener("click", async () => {
      await applyTmdb(result.id);
    });
    entry.appendChild(applyButton);
    elements.tmdbResults.append(entry);
  });
}

async function applyTmdb(tmdbId) {
  if (state.selectedMovieIndex === null) {
    showToast("Select a movie first", true);
    return;
  }
  const response = await fetch(`/api/tmdb/apply/${state.selectedMovieIndex}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tmdbId }),
  });
  if (!response.ok) {
    showToast("TMDB apply failed", true);
    return;
  }
  await reloadData(state.selectedMovieIndex);
  showToast("TMDB data applied");
}

async function refreshPodcast() {
  const sourceIdentifier = elements.podcastSourceSelect.value;
  if (!sourceIdentifier) {
    return;
  }
  elements.podcastStatus.textContent = "Fetching RSS feed...";
  const response = await fetch("/api/podcasts/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sourceIdentifier }),
  });
  if (!response.ok) {
    elements.podcastStatus.textContent = "Fetch failed.";
    return;
  }
  const data = await response.json();
  elements.podcastStatus.textContent = `Added ${data.addedCount} new episodes.`;
  await reloadData();
}

function escapeHistory(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function historyWhen(value) {
  return value ? new Date(value).toLocaleString() : "";
}

function historyDetail(entry) {
  const details = entry.details || {};
  const parts = [
    details.title,
    details.identifier,
    details.tmdbId != null ? `TMDB ${details.tmdbId}` : "",
    details.addedCount != null ? `${details.addedCount} added` : "",
    details.removedCount != null ? `${details.removedCount} removed` : "",
    details.updatedCount != null ? `${details.updatedCount} updated` : "",
    details.movieCount != null ? `${details.movieCount} movies` : "",
    details.label,
    details.snapshotId ? String(details.snapshotId).slice(0, 8) : ""
  ].filter(Boolean);
  return parts.join("   ");
}

async function loadHistory() {
  const status = document.getElementById("historyStatus");
  const snapshotsBody = document.getElementById("historySnapshotsBody");
  const auditBody = document.getElementById("historyAuditBody");
  if (!status || !snapshotsBody || !auditBody) {
    return;
  }
  status.textContent = "Loading history…";
  try {
    const response = await fetch("/api/history");
    if (!response.ok) {
      throw new Error("Could not load history");
    }
    const data = await response.json();
    const snapshots = data.snapshots || [];
    const audit = data.audit || [];
    status.textContent = `${snapshots.length} snapshots   ${audit.length} recent edits`;
    snapshotsBody.innerHTML = snapshots
      .map((snapshot) => {
        const label = snapshot.label || "Unlabeled";
        return `<tr>
          <td>${escapeHistory(historyWhen(snapshot.created_at))}</td>
          <td>${escapeHistory(label)}</td>
          <td>${escapeHistory(snapshot.trigger)}</td>
          <td>${escapeHistory(snapshot.movie_count)}</td>
          <td>${escapeHistory(snapshot.source_count)}</td>
          <td><button type="button" data-restore-snapshot="${escapeHistory(snapshot.id)}">Restore</button></td>
        </tr>`;
      })
      .join("");
    auditBody.innerHTML = audit
      .map((entry) => {
        const action = entry.reversible
          ? `<button type="button" data-revert-audit="${escapeHistory(entry.id)}">Revert</button>`
          : "";
        return `<tr>
          <td>${escapeHistory(historyWhen(entry.created_at))}</td>
          <td>${escapeHistory(entry.action)}</td>
          <td>${escapeHistory(historyDetail(entry))}</td>
          <td>${action}</td>
        </tr>`;
      })
      .join("");
    snapshotsBody.querySelectorAll("[data-restore-snapshot]").forEach((button) => {
      button.addEventListener("click", () => restoreHistorySnapshot(button.getAttribute("data-restore-snapshot")));
    });
    auditBody.querySelectorAll("[data-revert-audit]").forEach((button) => {
      button.addEventListener("click", () => revertHistoryAudit(button.getAttribute("data-revert-audit")));
    });
  } catch (error) {
    status.textContent = error instanceof Error ? error.message : "Could not load history";
  }
}

async function saveHistorySnapshot() {
  const input = document.getElementById("historySnapshotLabel");
  const label = input ? input.value.trim() : "";
  const response = await fetch("/api/history/snapshots", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ label }),
  });
  if (!response.ok) {
    showToast("Could not save snapshot", true);
    return;
  }
  if (input) {
    input.value = "";
  }
  await loadHistory();
  showToast(label ? `Saved snapshot ${label}` : "Saved snapshot");
}

async function restoreHistorySnapshot(id) {
  if (!id || !confirm("Restore this snapshot? The current catalog is saved first so you can undo.")) {
    return;
  }
  const response = await fetch(`/api/history/snapshots/${id}/restore`, { method: "POST" });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    showToast(data.error || "Restore failed", true);
    return;
  }
  await reloadData();
  await loadHistory();
  showToast("Catalog restored");
}

async function revertHistoryAudit(id) {
  if (!id || !confirm("Revert this single edit?")) {
    return;
  }
  const response = await fetch(`/api/history/audit/${id}/revert`, { method: "POST" });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    showToast(data.error || "Revert failed", true);
    return;
  }
  await reloadData();
  await loadHistory();
  showToast("Edit reverted");
}

function bindEvents() {
  [
    elements.searchInput,
    elements.statusFilter,
    elements.genreFilter,
    elements.ratingFilter,
    elements.streamingFilter,
    elements.listFilter,
    elements.sortFilter,
  ].forEach((el) => el.addEventListener("input", applyFilters));

  bindClick(elements.saveMovieBtn, (event) => {
    event.preventDefault();
    if (state.selectedMovieIndex === null) {
      persistNewMovie();
    } else {
      saveMovie();
    }
  });
  bindClick(elements.deleteMovieBtn, (event) => {
    event.preventDefault();
    deleteMovie();
  });
  bindClick(elements.newMovieBtn, () => {
    createNewMovie();
    applyFilters();
  });
  bindClick(elements.regenerateBtn, () => regenerateStore());
  bindClick(elements.refreshDataBtn, () => reloadData());
  bindClick(document.getElementById("historySaveSnapshotBtn"), () => saveHistorySnapshot());
  bindClick(document.getElementById("historyReloadBtn"), () => loadHistory());
  bindClick(elements.refreshStreamingBtn, (event) => {
    event.preventDefault();
    refreshStreamingForSelected();
  });
  bindClick(elements.refreshStreamingAllBtn, (event) => {
    event.preventDefault();
    refreshStreamingAll();
  });
  bindClick(elements.sourcesBtn, (event) => {
    event.preventDefault();
    openSourcesModal();
  });
  bindClick(elements.themesBtn, (event) => {
    event.preventDefault();
    openThemesModal();
  });
  bindClick(elements.themesOpsBtn, (event) => {
    event.preventDefault();
    openThemesModal();
  });
  bindClick(elements.tmdbSearchBtn, (event) => {
    event.preventDefault();
    searchTmdb();
  });
  bindClick(elements.podcastRunBtn, (event) => {
    event.preventDefault();
    refreshPodcast();
  });
  bindClick(elements.refreshFeedsBtn, (event) => {
    event.preventDefault();
    openRefreshFeedsModal();
  });
  bindClick(elements.latestPodcastsBtn, (event) => {
    event.preventDefault();
    openLatestPodcastsModal();
  });
  bindClick(elements.dataHealthBtn, (event) => {
    event.preventDefault();
    loadDataHealth();
  });
  bindClick(elements.dedupeBtn, (event) => {
    event.preventDefault();
    openDedupeModal();
  });
  bindClick(elements.oscarAwardsBtn, (event) => {
    event.preventDefault();
    openOscarModal();
  });
  bindClick(elements.physicalMediaBtn, (event) => {
    event.preventDefault();
    openPhysicalMediaModal();
  });
  bindClick(elements.physicalMediaCloseBtn, () => closePhysicalMediaModal());
  bindClick(elements.physicalMediaRefreshStatsBtn, () => loadPhysicalMediaStats());
  bindClick(elements.physicalMediaEnrichBtn, () => runPhysicalMediaEnrichment());
  bindClick(elements.physicalMediaClearBtn, () => clearPhysicalMedia());
  bindClick(elements.theaterStaysBtn, (event) => {
    event.preventDefault();
    openTheaterStaysModal();
  });
  bindClick(elements.theaterStaysCloseBtn, () => closeTheaterStaysModal());
  bindClick(elements.theaterStaysRefreshStatsBtn, () => loadTheaterStaysStats());
  bindClick(elements.theaterStaysRefreshBtn, () => refreshTheaterStays());
  bindClick(elements.theaterStaysClearBtn, () => clearTheaterStays());
  bindClick(elements.oscarCloseBtn, () => closeOscarModal());
  bindClick(elements.oscarRefreshStatsBtn, () => loadOscarStats());
  bindClick(elements.oscarEnrichBtn, () => runOscarEnrichment());
  bindClick(elements.oscarClearBtn, () => clearOscarAwards());
  bindClick(elements.oscarWikidataBtn, () => runWikidataEnrichment());
  bindClick(elements.addFeedBtn, () => openIngestModal("podcast"));
  bindClick(elements.addListBtn, () => openIngestModal("list"));
  bindClick(elements.addFeedTopBtn, () => openIngestModal("podcast"));
  bindClick(elements.addListTopBtn, () => openIngestModal("list"));
  bindClick(elements.addFeedOpsBtn, () => openIngestModal("podcast"));
  bindClick(elements.addListOpsBtn, () => openIngestModal("list"));
  bindClick(elements.ingestCloseBtn, () => closeIngestModal());
  bindClick(elements.ingestPreviewBtn, () => previewIngestItems());
  bindClick(elements.ingestBackBtn, () => setIngestStep("config"));
  bindClick(elements.ingestEnrichBtn, () => enrichIngestItems());
  bindClick(elements.ingestReviewBtn, () => reviewIngestItems());
  bindClick(elements.feedsSelectAllBtn, () => {
    elements.feedsList
      .querySelectorAll("input[type='checkbox']")
      .forEach((input) => (input.checked = true));
    ingestState.selectedFeeds = Array.from(
      elements.feedsList.querySelectorAll("input[type='checkbox']:checked")
    ).map((checkbox) => checkbox.value);
  });
  bindClick(elements.feedsSelectNoneBtn, () => {
    elements.feedsList
      .querySelectorAll("input[type='checkbox']")
      .forEach((input) => (input.checked = false));
    ingestState.selectedFeeds = [];
  });
  bindClick(elements.feedsPreviewBtn, () => previewIngestItems());
  bindClick(elements.ingestSelectEnrichedBtn, () => selectIngestByStatus("enriched"));
  bindClick(elements.ingestSelectLightBtn, () => selectIngestByStatus("light"));
  bindClick(elements.ingestSelectMissingBtn, () => selectIngestByStatus("missing"));
  bindClick(elements.ingestDeselectDuplicatesBtn, () => deselectDuplicateIngest());
  bindClick(elements.ingestReviewBackBtn, () => setIngestStep("preview"));
  bindClick(elements.ingestCommitBtn, () => commitIngestItems());
  bindClick(elements.confirmCloseBtn, () => closeConfirmModal());
  bindClick(elements.confirmCancelBtn, () => closeConfirmModal());
  bindClick(elements.confirmConfirmBtn, async () => {
    const action = confirmState.action;
    closeConfirmModal();
    if (action) {
      await action();
    }
  });
  bindClick(elements.dedupeCloseBtn, () => closeDedupeModal());
  bindClick(elements.dedupeCancelBtn, () => closeDedupeModal());
  bindClick(elements.dedupeCommitBtn, () => commitDedupe());
  bindClick(elements.reportCloseBtn, () => closeReportModal());
  bindClick(elements.streamingCloseBtn, () => closeStreamingModal());
  bindClick(elements.sourcesCloseBtn, () => closeSourcesModal());
  bindClick(elements.sourceNewBtn, (event) => {
    event.preventDefault();
    createSourceDraft("podcast");
  });
  bindClick(elements.sourceSaveBtn, (event) => {
    event.preventDefault();
    saveSource();
  });
  bindClick(elements.themesCloseBtn, () => closeThemesModal());
  bindClick(elements.themeNewBtn, (event) => {
    event.preventDefault();
    createThemeDraft();
  });
  bindClick(elements.themeDeleteBtn, (event) => {
    event.preventDefault();
    deleteTheme();
  });
  bindClick(elements.themeUndoBtn, (event) => {
    event.preventDefault();
    undoThemeFormChange();
  });
  bindClick(elements.themeSaveBtn, (event) => {
    event.preventDefault();
    saveTheme();
  });
  if (elements.themePreviewMode) {
    elements.themePreviewMode.addEventListener("change", () => renderThemePreview());
  }
  bindClick(elements.themeColorPickerCloseBtn, () => closeThemeColorPicker());

  Object.values(themeFormFields).forEach((field) => {
    if (!field) {
      return;
    }
    field.addEventListener("change", () => renderThemePreview());
    field.addEventListener("change", () => commitThemeUndoSnapshotImmediate());
    if (!field.classList.contains("theme-color-input")) {
      field.addEventListener("input", () => renderThemePreview());
      field.addEventListener("input", () => scheduleThemeUndoSnapshotCommit());
    }
  });

  document.querySelectorAll(".theme-color-card").forEach((card) => {
    card.addEventListener("click", (event) => {
      event.preventDefault();
      const targetId = card.dataset.target;
      const field = getThemeColorFieldById(targetId);
      if (!field) {
        return;
      }
      openThemeColorPicker(field, card);
    });
  });

  document.querySelectorAll(".theme-color-input").forEach((field) => {
    field.addEventListener("input", () => {
      const normalized = normalizeHexColor(field.value);
      if (normalized) {
        field.value = normalized;
      }
      updateThemeSwatches();
      if (themeColorPickerState.activeField === field) {
        const parsed = parseHexColor(field.value);
        if (parsed) {
          const hsv = rgbToHsv(parsed);
          themeColorPickerState.hue = hsv.hue;
          themeColorPickerState.saturation = hsv.saturation;
          themeColorPickerState.value = hsv.value;
          renderThemeColorPicker();
        }
      }
      scheduleThemeUndoSnapshotCommit();
    });
  });

  elements.themeSvSquare.addEventListener("mousedown", (event) => {
    themeColorPickerState.draggingSv = true;
    updatePickerSvFromClientPosition(event.clientX, event.clientY);
  });
  elements.themeHueStrip.addEventListener("mousedown", (event) => {
    themeColorPickerState.draggingHue = true;
    updatePickerHueFromClientPosition(event.clientY);
  });
  document.addEventListener("mousemove", (event) => {
    if (themeColorPickerState.draggingSv) {
      updatePickerSvFromClientPosition(event.clientX, event.clientY);
    }
    if (themeColorPickerState.draggingHue) {
      updatePickerHueFromClientPosition(event.clientY);
    }
  });
  document.addEventListener("mouseup", () => {
    const hadDrag = themeColorPickerState.draggingSv || themeColorPickerState.draggingHue;
    themeColorPickerState.draggingSv = false;
    themeColorPickerState.draggingHue = false;
    if (hadDrag) {
      flushThemeUndoSnapshotCommit();
    }
  });
  document.addEventListener("click", (event) => {
    if (elements.themeColorPickerPopover.classList.contains("hidden")) {
      return;
    }
    const target = event.target;
    if (
      elements.themeColorPickerPopover.contains(target) ||
      target.classList?.contains("theme-color-card") ||
      target.closest?.(".theme-color-card")
    ) {
      return;
    }
    closeThemeColorPicker();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeThemeColorPicker();
    }
  });
  elements.themeColorPickerHex.addEventListener("input", () => {
    const parsed = parseHexColor(elements.themeColorPickerHex.value);
    if (!parsed) {
      return;
    }
    const hsv = rgbToHsv(parsed);
    themeColorPickerState.hue = hsv.hue;
    themeColorPickerState.saturation = hsv.saturation;
    themeColorPickerState.value = hsv.value;
    applyThemeColorFromPicker();
  });
  window.addEventListener("resize", () => {
    if (!themeColorPickerState.activeField || !themeColorPickerState.activeAnchorElement) {
      return;
    }
    positionThemeColorPicker(themeColorPickerState.activeAnchorElement);
    renderThemeColorPicker();
  });
}

// ---- Design Inspector ----

let inspectSelected = null;

function closeInspector() {
  var container = document.getElementById("ds-inspector-inline");
  if (container) container.innerHTML = "";
  var empty = document.getElementById("inspectorEmpty");
  if (empty) empty.style.display = "";
  if (inspectSelected) {
    inspectSelected.classList.remove("ds-inspect-selected");
    inspectSelected = null;
  }
}

function showInspectorPanel(el) {
  var container = document.getElementById("ds-inspector-inline");
  if (!container) return;

  switchPanelTab("inspect");

  var ds = {};
  try { ds = JSON.parse(el.dataset.ds || "{}"); } catch (_) {}
  var rect = el.getBoundingClientRect();
  var cs = getComputedStyle(el);

  var elName = ds.el || el.className.split(" ")[0];
  var html = '<div class="insp-header">' + elName + '</div>';

  html += '<div class="insp-section"><div class="insp-section-title">Computed</div>';
  html += inspRow("Width", Math.round(rect.width) + "px");
  html += inspRow("Height", Math.round(rect.height) + "px");
  html += inspRow("Font Size", cs.fontSize);
  html += inspRow("Font Weight", cs.fontWeight);
  if (cs.borderRadius && cs.borderRadius !== "0px") inspRow("Border Radius", cs.borderRadius);
  html += "</div>";

  var tokenMap = {
    size: "Size", radius: "Corner Radius", bg: "Background", border: "Border",
    type: "Typography", color: "Color", icon: "Icon", spacing: "Spacing",
    style: "Style", layout: "Layout", effect: "Effect",
    shadow: "Shadow", opacity: "Opacity", glass: "Glass", anim: "Animation"
  };
  var tokenEntries = Object.entries(ds).filter(function(e) { return e[0] !== "el"; });
  if (tokenEntries.length > 0) {
    html += '<div class="insp-section"><div class="insp-section-title">Design Tokens</div>';
    for (var i = 0; i < tokenEntries.length; i++) {
      html += inspRow(tokenMap[tokenEntries[i][0]] || tokenEntries[i][0], tokenEntries[i][1], true);
    }
    html += "</div>";
  }

  html += '<div class="insp-section"><div class="insp-section-title">CSS Class</div>';
  html += '<div class="insp-classname">' +
    el.className.replace("ds-inspect-selected", "").trim() + "</div></div>";

  container.innerHTML = html;
  var empty = document.getElementById("inspectorEmpty");
  if (empty) empty.style.display = "none";
}

function inspRow(label, value, isToken) {
  var cls = isToken ? " insp-val-token" : "";
  return '<div class="insp-row"><span class="insp-label">' + label +
    '</span><span class="insp-value' + cls + '">' + value + '</span></div>';
}

function switchPanelTab(tabKey) {
  document.querySelectorAll(".crp-tab").forEach(function(t) {
    t.classList.toggle("is-active", t.dataset.panelTab === tabKey);
  });
  document.querySelectorAll(".crp-tab-content").forEach(function(c) {
    c.classList.toggle("is-active", c.dataset.panelContent === tabKey);
  });
}

document.addEventListener("click", function (e) {
  if (canvas.activeTool !== "inspect") return;
  var target = e.target.closest("[data-ds]");
  if (!target) return;
  if (e.target.closest(".canvas-bottombar") || e.target.closest(".canvas-right-panel")) return;
  e.preventDefault();
  e.stopPropagation();
  if (inspectSelected) inspectSelected.classList.remove("ds-inspect-selected");
  inspectSelected = target;
  target.classList.add("ds-inspect-selected");
  showInspectorPanel(target);
}, true);

// ---- Appearance Settings ----

// ---- Live Appearance Settings (loaded from Swift source) ----

var appThemes = [];
var activeTheme = null;
var appSettings = null;

function to255(v) { return Math.round(Math.min(1, Math.max(0, v)) * 255); }

function rgb(c, a) {
  if (a !== undefined) return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a + ")";
  return "rgb(" + c[0] + "," + c[1] + "," + c[2] + ")";
}

function c01(obj, key, fallback) {
  return obj && obj[key] != null ? obj[key] : fallback;
}

function themePresetToRenderTheme(preset) {
  var ac = preset.accent || {};
  var bg = preset.darkModeBackground || {};
  var bgTint = preset.darkModeBackgroundTint || preset.backgroundTint || {};
  var hl = preset.darkModeHeadlineColor || preset.headlineColor || {};
  var sec = preset.secondaryAccent || ac;

  var accent = [to255(c01(ac, "red", 0)), to255(c01(ac, "green", 0)), to255(c01(ac, "blue", 0))];
  var bgColor = [to255(c01(bg, "red", 0.04)), to255(c01(bg, "green", 0.04)), to255(c01(bg, "blue", 0.06))];
  var bgTintColor = bgTint.red != null
    ? [to255(bgTint.red), to255(c01(bgTint, "green", 0)), to255(c01(bgTint, "blue", 0))]
    : [Math.min(255, bgColor[0] + 8), Math.min(255, bgColor[1] + 8), Math.min(255, bgColor[2] + 8)];
  var headlineColor = [to255(c01(hl, "red", 1)), to255(c01(hl, "green", 1)), to255(c01(hl, "blue", 1))];
  var secondaryAccent = [to255(c01(sec, "red", 0)), to255(c01(sec, "green", 0)), to255(c01(sec, "blue", 0))];

  var textPrimary = deriveBodyText(bgColor, bgTintColor, accent);
  var textSecondary = [
    Math.round(textPrimary[0] * 0.75 + bgColor[0] * 0.25),
    Math.round(textPrimary[1] * 0.75 + bgColor[1] * 0.25),
    Math.round(textPrimary[2] * 0.75 + bgColor[2] * 0.25)
  ];
  var borderRule = [
    Math.round(bgColor[0] * 0.64 + bgTintColor[0] * 0.36 + 36),
    Math.round(bgColor[1] * 0.64 + bgTintColor[1] * 0.36 + 36),
    Math.round(bgColor[2] * 0.64 + bgTintColor[2] * 0.36 + 36)
  ].map(function(v) { return Math.min(255, v); });

  var font = "system-default";
  if (preset.headlineFontStyle === "system-monospaced") font = "monospace";
  else if (preset.headlineFontStyle === "new-york") font = "'Georgia', 'Times New Roman', serif";
  else if (preset.headlineFontStyle === "system-condensed") font = "system-default";

  return {
    name: preset.name,
    accent: accent,
    bg: bgColor,
    bgTint: bgTintColor,
    headline: headlineColor,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    secondaryAccent: secondaryAccent,
    borderRule: borderRule,
    font: font
  };
}

function deriveBodyText(bg, tint, accent) {
  var source = tint[0] + tint[1] + tint[2] > 0 ? tint : accent;
  var candidate = [
    Math.round(source[0] * 0.12 + 255 * 0.88),
    Math.round(source[1] * 0.12 + 255 * 0.88),
    Math.round(source[2] * 0.12 + 255 * 0.88)
  ];
  var bgLum = 0.2126 * (bg[0] / 255) + 0.7152 * (bg[1] / 255) + 0.0722 * (bg[2] / 255);
  var candLum = 0.2126 * (candidate[0] / 255) + 0.7152 * (candidate[1] / 255) + 0.0722 * (candidate[2] / 255);
  var ratio = (Math.max(bgLum, candLum) + 0.05) / (Math.min(bgLum, candLum) + 0.05);
  if (ratio < 4.5) {
    candidate = [
      Math.min(255, candidate[0] + 40),
      Math.min(255, candidate[1] + 40),
      Math.min(255, candidate[2] + 40)
    ];
  }
  return candidate;
}

async function loadThemesFromServer() {
  try {
    var resp = await fetch("/api/themes");
    if (!resp.ok) return;
    var data = await resp.json();
    var presets = data.themes || [];
    appThemes = presets.map(themePresetToRenderTheme);
    if (appThemes.length > 0) activeTheme = appThemes[0];
  } catch (_) {}
}

async function loadAppSettingsFromServer() {
  try {
    var resp = await fetch("/api/design-system/settings");
    if (!resp.ok) return;
    appSettings = await resp.json();
    if (appSettings && appSettings.movieDetailLayoutParameters) {
      var serverDefaults = appSettings.movieDetailLayoutParameters;
      Object.keys(serverDefaults).forEach(function(k) {
        if (k in layoutParams) layoutParams[k] = serverDefaults[k];
      });
    }
  } catch (_) {}
}

function applyTheme(themeName) {
  var theme = appThemes.find(function(t) { return t.name === themeName; });
  if (!theme) return;
  activeTheme = theme;

  document.querySelectorAll(".app-phone-screen").forEach(function(screen) {
    screen.style.setProperty("--phone-accent", rgb(theme.accent, 0.9));
    screen.style.setProperty("--phone-accent-15", rgb(theme.accent, 0.15));
    screen.style.setProperty("--phone-accent-30", rgb(theme.accent, 0.3));
    screen.style.setProperty("--phone-bg", rgb(theme.bg));
    screen.style.setProperty("--phone-bg-tint", rgb(theme.bgTint, 0.5));
    screen.style.setProperty("--phone-headline", rgb(theme.headline));
    screen.style.setProperty("--phone-text-primary", rgb(theme.textPrimary));
    screen.style.setProperty("--phone-text-secondary", rgb(theme.textSecondary, 0.65));
    screen.style.setProperty("--phone-secondary-accent", rgb(theme.secondaryAccent, 0.9));
    screen.style.setProperty("--phone-border-rule", rgb(theme.borderRule, 0.08));
    screen.style.background = rgb(theme.bg);

    if (theme.font === "monospace") {
      screen.style.fontFamily = "'SF Mono', 'Menlo', 'Consolas', monospace";
    } else if (theme.font !== "system-default") {
      screen.style.fontFamily = theme.font;
    } else {
      screen.style.fontFamily = "";
    }
  });

  document.querySelectorAll(".app-theme-chip").forEach(function(chip) {
    chip.classList.toggle("is-active", chip.dataset.theme === themeName);
  });
}

function initThemeChips() {
  var container = document.getElementById("app-theme-chips");
  if (!container) return;
  container.innerHTML = "";
  appThemes.forEach(function(theme) {
    var chip = document.createElement("button");
    chip.className = "app-theme-chip" + (activeTheme && theme.name === activeTheme.name ? " is-active" : "");
    chip.dataset.theme = theme.name;
    chip.innerHTML = '<span class="app-theme-chip-swatch" style="background:' +
      rgb(theme.accent) + '"></span>' + theme.name;
    chip.onclick = function() { applyTheme(theme.name); };
    container.appendChild(chip);
  });
}

function slugify(val) {
  return val.replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-|-$/g, "").toLowerCase();
}

function populateSelect(selectId, enumData, defaultRawValue) {
  var select = document.getElementById(selectId);
  if (!select || !enumData || !enumData.cases || !enumData.cases.length) return;
  select.innerHTML = "";
  enumData.cases.forEach(function(c) {
    var opt = document.createElement("option");
    opt.value = c.rawValue;
    opt.textContent = c.rawValue;
    if (c.description) opt.title = c.description;
    if (c.rawValue === defaultRawValue) opt.selected = true;
    select.appendChild(opt);
  });
}

function applyPosterSize(value) {
  var appContent = document.getElementById("appContent");
  if (!appContent) return;

  var allClasses = Array.from(appContent.classList).filter(function(c) { return c.startsWith("poster-size-"); });
  allClasses.forEach(function(c) { appContent.classList.remove(c); });

  if (appSettings && appSettings.posterSizePreference) {
    var psp = appSettings.posterSizePreference;
    var match = psp.cases.find(function(c) { return c.rawValue === value; });
    if (match && match.scale) {
      var w = Math.round((match.scale * psp.baseWidth) / 8) * 8;
      appContent.classList.add("poster-size-" + w);
      applyDynamicPosterCSS(w);
    }
  } else {
    var fallback = { "+10%": "poster-size-112", "+20%": "poster-size-120", "+40%": "poster-size-144", "+60%": "poster-size-160" };
    if (fallback[value]) appContent.classList.add(fallback[value]);
  }
}

function applyDynamicPosterCSS(widthPx) {
  var styleId = "dynamic-poster-size";
  var existing = document.getElementById(styleId);
  if (existing) existing.remove();
  var style = document.createElement("style");
  style.id = styleId;
  style.textContent = "[class*='poster-size-" + widthPx + "'] .app-home-poster-row { grid-auto-columns: " + widthPx + "px; }";
  document.head.appendChild(style);
}

function applyToolbarStyle(value) {
  var appContent = document.getElementById("appContent");
  if (!appContent) return;
  appContent.classList.remove("toolbar-system", "toolbar-floating");
  if (appSettings && appSettings.mainListToolbarStyle) {
    var match = appSettings.mainListToolbarStyle.cases.find(function(c) { return c.rawValue === value; });
    if (match && match.id === "system") {
      appContent.classList.add("toolbar-system");
    } else {
      appContent.classList.add("toolbar-floating");
    }
  } else {
    if (value === "System Toolbar") {
      appContent.classList.add("toolbar-system");
    } else {
      appContent.classList.add("toolbar-floating");
    }
  }
}

var layoutParams = {
  classicBackdropHeight: 250, classicPosterHeight: 400,
  compactPosterWidth: 120, compactPosterHeight: 180, compactBlurRadius: 20,
  splitPosterWidth: 140, splitBackdropOpacity: 0.8, splitTitleOverlap: 40,
  posterFocusWidth: 220, posterFocusHeight: 330, posterFocusShadowRadius: 20,
  posterFocusFullBleed: true, posterFocusActionBarPosition: "below", posterFocusFadePercentage: 0,
  cinematicBackdropHeight: 350, cinematicPosterScale: 0.75, cinematicOverlayOpacity: 0.3
};

function setLayoutVar(k, v) {
  layoutParams[k] = v;
  applyLayoutParamsCSS();
}

function applyLayoutParamsCSS() {
  var p = layoutParams;
  var appContent = document.getElementById("appContent");
  if (!appContent) return;
  var screens = document.querySelectorAll(".app-phone-screen");

  var isFull = p.posterFocusFullBleed;
  appContent.classList.toggle("pf-card", !isFull);

  screens.forEach(function(s) {
    s.style.setProperty("--pf-fade-pct", p.posterFocusFadePercentage + "%");
    s.style.setProperty("--pf-width", p.posterFocusWidth + "px");
    s.style.setProperty("--pf-height", p.posterFocusHeight + "px");
    s.style.setProperty("--pf-shadow", p.posterFocusShadowRadius + "px");
    s.style.setProperty("--classic-backdrop-h", p.classicBackdropHeight + "px");
    s.style.setProperty("--classic-poster-h", p.classicPosterHeight + "px");
    s.style.setProperty("--compact-poster-w", p.compactPosterWidth + "px");
    s.style.setProperty("--compact-poster-h", p.compactPosterHeight + "px");
    s.style.setProperty("--compact-blur", p.compactBlurRadius + "px");
    s.style.setProperty("--split-poster-w", p.splitPosterWidth + "px");
    s.style.setProperty("--split-backdrop-opacity", p.splitBackdropOpacity);
    s.style.setProperty("--cinematic-backdrop-h", p.cinematicBackdropHeight + "px");
    s.style.setProperty("--cinematic-poster-scale", p.cinematicPosterScale);
    s.style.setProperty("--cinematic-overlay-opacity", p.cinematicOverlayOpacity);
  });

  var actionBar = document.querySelector(".app-detail-actions");
  if (actionBar) {
    var isFullBleedFocus = appContent.classList.contains("detail-poster-focus") && isFull;
    if (isFullBleedFocus && p.posterFocusActionBarPosition === "overlapping") {
      actionBar.style.marginTop = "-40px";
    } else if (isFullBleedFocus) {
      actionBar.style.marginTop = "12px";
    } else {
      actionBar.style.marginTop = "";
    }
  }
}

function buildParamSlider(key, title, min, max, step, desc, fmt) {
  var v = layoutParams[key];
  var fmtFn = fmt || function(x) { return Math.round(x); };
  var row = document.createElement("div");
  row.className = "app-param-row";
  row.innerHTML =
    '<div class="app-param-header"><span class="app-param-title">' + title + '</span><span class="app-param-value" id="pv-' + key + '">' + fmtFn(v) + '</span></div>' +
    '<input type="range" min="' + min + '" max="' + max + '" step="' + (step||1) + '" value="' + v + '">' +
    '<div class="app-param-desc">' + desc + '</div>';
  row.querySelector("input").addEventListener("input", function(e) {
    var val = parseFloat(e.target.value);
    setLayoutVar(key, val);
    document.getElementById("pv-" + key).textContent = fmtFn(val);
  });
  return row;
}

function buildParamToggle(key, title, desc) {
  var row = document.createElement("div");
  row.className = "app-param-row";
  row.innerHTML =
    '<label class="app-setting-toggle" style="padding:0;"><input type="checkbox" ' + (layoutParams[key] ? 'checked' : '') + '><span style="font-size:10px;font-weight:600;">' + title + '</span></label>' +
    '<div class="app-param-desc">' + desc + '</div>';
  row.querySelector("input").addEventListener("change", function(e) {
    setLayoutVar(key, e.target.checked);
    var sel = document.getElementById("app-detail-layout");
    buildLayoutParams(sel ? sel.value : "Poster Focus");
  });
  return row;
}

function buildParamSegment(key, title, options, desc) {
  var row = document.createElement("div");
  row.className = "app-param-row";
  var btns = options.map(function(opt) {
    var active = layoutParams[key] === opt.value ? ' style="background:var(--color-primary);color:#fff;font-weight:700;"' : '';
    return '<button class="app-param-seg-btn" data-val="' + opt.value + '"' + active + '>' + opt.label + '</button>';
  }).join('');
  row.innerHTML =
    '<span class="app-param-title">' + title + '</span>' +
    '<div style="display:flex;gap:2px;margin-top:2px;">' + btns + '</div>' +
    '<div class="app-param-desc">' + desc + '</div>';
  row.querySelectorAll(".app-param-seg-btn").forEach(function(btn) {
    btn.style.cssText += "flex:1;padding:3px 4px;font-size:9px;border:1px solid var(--color-border);border-radius:4px;background:var(--color-bg-elevated);color:var(--color-text-secondary);cursor:pointer;";
    btn.addEventListener("click", function() {
      setLayoutVar(key, btn.dataset.val);
      var sel = document.getElementById("app-detail-layout");
      buildLayoutParams(sel ? sel.value : "Poster Focus");
    });
  });
  return row;
}

function buildLayoutParams(layoutValue) {
  var container = document.getElementById("app-layout-params");
  if (!container) return;
  container.innerHTML = "";
  var slug = slugify(layoutValue);

  switch (slug) {
    case "classic":
      container.appendChild(buildParamSlider("classicBackdropHeight", "Backdrop Height", 150, 400, 1, "Height of the backdrop image at the top"));
      container.appendChild(buildParamSlider("classicPosterHeight", "Poster Height", 250, 500, 1, "Height when showing poster instead of backdrop"));
      break;
    case "compact":
      container.appendChild(buildParamSlider("compactPosterWidth", "Poster Width", 80, 180, 1, "Width of the poster on the left side"));
      container.appendChild(buildParamSlider("compactPosterHeight", "Poster Height", 120, 270, 1, "Height of the poster on the left side"));
      container.appendChild(buildParamSlider("compactBlurRadius", "Blur Radius", 5, 40, 1, "Amount of blur on the backdrop background"));
      break;
    case "split":
      container.appendChild(buildParamSlider("splitPosterWidth", "Poster Width", 100, 200, 1, "Width of the poster on the left"));
      container.appendChild(buildParamSlider("splitBackdropOpacity", "Backdrop Opacity", 0.3, 1.0, 0.05, "Transparency of the backdrop", function(x) { return x.toFixed(2); }));
      break;
    case "poster-focus":
      container.appendChild(buildParamToggle("posterFocusFullBleed", "Full Bleed Top Poster", "Make poster fill the full width at the top"));
      container.appendChild(buildParamSlider("posterFocusHeight", "Poster Height", 225, 450, 1, "Height of the poster"));
      if (layoutParams.posterFocusFullBleed) {
        container.appendChild(buildParamSegment("posterFocusActionBarPosition", "Action Bar Position",
          [{ value: "below", label: "Below" }, { value: "overlapping", label: "Overlapping" }],
          "Place actions below poster or overlapping its bottom edge"));
        container.appendChild(buildParamSlider("posterFocusFadePercentage", "Poster Fade", 0, 25, 0.5, "Fade from poster bottom upward (% of poster height)", function(x) { return x.toFixed(1) + "%"; }));
      } else {
        container.appendChild(buildParamSlider("posterFocusWidth", "Poster Width", 150, 300, 1, "Width of the centered poster"));
        container.appendChild(buildParamSlider("posterFocusShadowRadius", "Shadow Radius", 5, 40, 1, "Size of the drop shadow around poster"));
      }
      break;
    case "cinematic":
    case "cinematic-with-transition":
      container.appendChild(buildParamSlider("cinematicBackdropHeight", "Backdrop Height", 250, 450, 1, "Height of the full-width backdrop"));
      container.appendChild(buildParamSlider("cinematicPosterScale", "Poster Scale", 0.5, 1.2, 0.05, "Size of the floating poster card (1.0 = normal)", function(x) { return x.toFixed(2); }));
      container.appendChild(buildParamSlider("cinematicOverlayOpacity", "Overlay Opacity", 0.1, 0.7, 0.05, "Darkness of the gradient overlay", function(x) { return x.toFixed(2); }));
      break;
  }

  applyLayoutParamsCSS();
}

function applyDetailLayout(value) {
  var appContent = document.getElementById("appContent");
  if (!appContent) return;
  var allClasses = Array.from(appContent.classList).filter(function(c) { return c.startsWith("detail-") || c === "pf-card"; });
  allClasses.forEach(function(c) { appContent.classList.remove(c); });
  var cls = "detail-" + slugify(value);
  appContent.classList.add(cls);
  buildLayoutParams(value);
}

function applyActionBarLayout(value) {
  var screens = document.querySelectorAll(".app-phone-screen");
  var align = value === "centered" ? "center" : "flex-start";
  screens.forEach(function(s) { s.style.setProperty("--action-bar-align", align); });
  var actions = document.querySelector(".app-detail-actions");
  if (actions) actions.style.justifyContent = align;
}

var deviceChromeOn = false;
function applyDeviceChrome(on) {
  deviceChromeOn = on;
  var appContent = document.getElementById("appContent");
  if (!appContent) return;
  appContent.classList.toggle("chrome-off", !on);
  var btn = document.getElementById("toggleChromeBtn");
  if (btn) btn.classList.toggle("is-active", on);
}
function toggleDeviceChrome() { applyDeviceChrome(!deviceChromeOn); }
function toggleCanvasUI() {
  var shell = document.getElementById("canvasShell");
  if (shell) shell.classList.toggle("ui-hidden");
}

function applySearchBar(value) {
  var appContent = document.getElementById("appContent");
  if (!appContent) return;
  var allClasses = Array.from(appContent.classList).filter(function(c) { return c.startsWith("searchbar-"); });
  allClasses.forEach(function(c) { appContent.classList.remove(c); });
  var cls = "searchbar-" + slugify(value);
  appContent.classList.add(cls);
}

function initAppearanceSettings() {
  initThemeChips();

  if (appSettings) {
    populateSelect("app-poster-size", appSettings.posterSizePreference, "+60%");
    populateSelect("app-toolbar-style", appSettings.mainListToolbarStyle, "Custom Floating Toolbar");
    populateSelect("app-detail-layout", appSettings.movieDetailLayoutStyle, "Poster Focus");
    populateSelect("app-search-bar", appSettings.searchBarAppearance, "Glass");
    if (appSettings.movieDetailActionBarLayout) {
      populateSelect("app-action-bar-layout", appSettings.movieDetailActionBarLayout, "Left Aligned");
    }
  }

  var posterSel = document.getElementById("app-poster-size");
  var toolbarSel = document.getElementById("app-toolbar-style");
  var detailSel = document.getElementById("app-detail-layout");
  var searchSel = document.getElementById("app-search-bar");

  applyPosterSize(posterSel ? posterSel.value : "+60%");
  applyToolbarStyle(toolbarSel ? toolbarSel.value : "Custom Floating Toolbar");
  applyDetailLayout(detailSel ? detailSel.value : "Poster Focus");
  applySearchBar(searchSel ? searchSel.value : "Glass");

  var actionBarSel = document.getElementById("app-action-bar-layout");
  applyActionBarLayout(actionBarSel ? actionBarSel.value : "leftAligned");

  applyDeviceChrome(false);
}

// ---- Physical Media ----

function openPhysicalMediaModal() {
  elements.physicalMediaModal.classList.remove("hidden");
  elements.physicalMediaStatus.textContent = "";
  loadPhysicalMediaStats();
}

function closePhysicalMediaModal() {
  elements.physicalMediaModal.classList.add("hidden");
}

async function loadPhysicalMediaStats() {
  const response = await fetch("/api/physical-media/stats");
  const stats = await response.json();
  elements.physicalMediaStats.innerHTML = `
    <div>Tagged ${stats.withPhysicalMedia || 0}</div>
    <div>Criterion ${stats.withCriterion || 0}</div>
    <div>4K ${stats.with4K || 0}</div>
    <div>Manual ${stats.manualOverrides || 0}</div>
  `;
}

async function runPhysicalMediaEnrichment() {
  elements.physicalMediaStatus.textContent = "Querying Wikidata…";
  elements.physicalMediaEnrichBtn.disabled = true;
  try {
    const response = await fetch("/api/physical-media/enrich", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    const data = await response.json();
    if (!data.success) throw new Error(data.error || "Enrichment failed");
    elements.physicalMediaStatus.textContent = `Updated ${data.updatedCount} movies (${data.overlayCount} overlay titles).`;
    await loadPhysicalMediaStats();
    showToast("Discs overlay updated");
  } catch (error) {
    elements.physicalMediaStatus.textContent = error.message;
    showToast(error.message, true);
  } finally {
    elements.physicalMediaEnrichBtn.disabled = false;
  }
}

async function clearPhysicalMedia() {
  if (!confirm("Clear inferred disc tags from the Min Cloud catalog? Manual pins are kept.")) return;
  const response = await fetch("/api/physical-media/clear", { method: "POST" });
  const data = await response.json();
  elements.physicalMediaStatus.textContent = `Cleared ${data.clearedCount || 0} movies.`;
  await loadPhysicalMediaStats();
}

function renderDetailPhysicalMedia(movie) {
  if (!elements.detailPhysicalMedia) return;
  if (!movie.tmdbId && !movie.physicalMedia) {
    elements.detailPhysicalMedia.classList.add("hidden");
    elements.detailPhysicalMedia.innerHTML = "";
    return;
  }
  elements.detailPhysicalMedia.classList.remove("hidden");
  const media = movie.physicalMedia || {};
  const spine = (media.editions || []).find((edition) => edition.spineNumber)?.spineNumber || "";
  elements.detailPhysicalMedia.innerHTML = `
    <div class="oscar-detail-row">
      <div class="oscar-detail-header">Discs</div>
      <button class="oscar-fetch-btn" data-save="1">Save</button>
    </div>
    <label><input type="checkbox" data-flag="hasCriterion" ${media.hasCriterion ? "checked" : ""}/> Criterion</label>
    <label><input type="checkbox" data-flag="has4K" ${media.has4K ? "checked" : ""}/> 4K UHD</label>
    <label><input type="checkbox" data-flag="hasBluRay" ${media.hasBluRay ? "checked" : ""}/> Blu-ray</label>
    <label>Spine <input type="text" data-spine="1" value="${spine}" placeholder="42" /></label>
  `;
  const saveBtn = elements.detailPhysicalMedia.querySelector("[data-save]");
  saveBtn.addEventListener("click", async () => {
    if (!movie.tmdbId) {
      showToast("TMDB id required to save physical media", true);
      return;
    }
    const flags = {};
    elements.detailPhysicalMedia.querySelectorAll("[data-flag]").forEach((input) => {
      flags[input.dataset.flag] = input.checked;
    });
    const spineValue = elements.detailPhysicalMedia.querySelector("[data-spine]")?.value.trim();
    const editions = [];
    if (flags.hasCriterion) {
      editions.push({
        id: "criterion-bluray",
        label: "criterion",
        format: flags.has4K ? "uhd4k" : "bluRay",
        spineNumber: spineValue || null,
      });
    } else if (flags.has4K) {
      editions.push({ id: "other-uhd4k", label: "other", format: "uhd4k" });
    }
    saveBtn.disabled = true;
    try {
      const response = await fetch("/api/physical-media/update", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          tmdbId: movie.tmdbId,
          ...flags,
          editions,
          manualOverride: true,
        }),
      });
      const data = await response.json();
      if (!data.success) throw new Error(data.error || "Save failed");
      movie.physicalMedia = data.physicalMedia;
      showToast("Saved discs");
    } catch (error) {
      showToast(error.message, true);
    } finally {
      saveBtn.disabled = false;
    }
  });
}

// ---- Theater Stays ----

function openTheaterStaysModal() {
  if (!elements.theaterStaysModal) return;
  elements.theaterStaysModal.classList.remove("hidden");
  if (elements.theaterStaysStatus) elements.theaterStaysStatus.textContent = "";
  loadTheaterStaysStats();
}

function closeTheaterStaysModal() {
  if (elements.theaterStaysModal) elements.theaterStaysModal.classList.add("hidden");
}

function renderTheaterStayStats(stats) {
  if (!elements.theaterStaysStats) return;
  const refreshed = stats.refreshedAt ? new Date(stats.refreshedAt).toLocaleString() : "Never";
  elements.theaterStaysStats.innerHTML = `
    <div>In theaters ${stats.inTheaters || 0}</div>
    <div>In catalog ${stats.inCatalog || 0}</div>
    <div>IMAX ${stats.withIMAX || 0}</div>
    <div>Manual ${stats.manualOverrides || 0}</div>
    <div>Ticket links ${stats.withTicketLinks || 0}</div>
    <div>${stats.region || "US"}   ${refreshed}</div>
  `;
  if (!elements.theaterStaysBody) return;
  const stays = stats.stays || [];
  if (!stays.length) {
    elements.theaterStaysBody.innerHTML = `<tr><td colspan="7">No theater stays stored.</td></tr>`;
    return;
  }
  elements.theaterStaysBody.innerHTML = stays
    .map((stay) => {
      const links = stay.ticketLinks || {};
      return `
        <tr data-tmdb="${stay.tmdbId || ""}">
          <td>${escapeHistory(stay.title || "")}</td>
          <td>${stay.tmdbId || ""}</td>
          <td>${stay.hasIMAX ? "IMAX" : ""}</td>
          <td><input type="url" data-ticket-site="amc" value="${escapeHistory(links.amc || "")}" placeholder="AMC showtimes URL" /></td>
          <td><input type="url" data-ticket-site="fandango" value="${escapeHistory(links.fandango || "")}" placeholder="Fandango movie URL" /></td>
          <td><input type="url" data-ticket-site="atom" value="${escapeHistory(links.atom || "")}" placeholder="Atom movie URL" /></td>
          <td><button type="button" data-save-ticket-links="1">Save</button></td>
        </tr>
      `;
    })
    .join("");
  elements.theaterStaysBody.querySelectorAll("[data-save-ticket-links]").forEach((button) => {
    button.addEventListener("click", () => saveTheaterStayTicketLinks(button.closest("tr")));
  });
}

async function saveTheaterStayTicketLinks(row) {
  if (!row) return;
  const tmdbId = Number(row.dataset.tmdb);
  if (!tmdbId) return;
  const title = row.querySelector("td")?.textContent || "";
  const ticketLinks = {};
  row.querySelectorAll("[data-ticket-site]").forEach((input) => {
    ticketLinks[input.dataset.ticketSite] = input.value.trim();
  });
  const saveBtn = row.querySelector("[data-save-ticket-links]");
  if (saveBtn) saveBtn.disabled = true;
  try {
    const response = await fetch("/api/theater-stays/ticket-links", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tmdbId, title, ticketLinks }),
    });
    const data = await response.json();
    if (!data.success) throw new Error(data.error || "Save failed");
    showToast("Saved ticket links");
    await loadTheaterStaysStats();
  } catch (error) {
    showToast(error.message, true);
  } finally {
    if (saveBtn) saveBtn.disabled = false;
  }
}

async function loadTheaterStaysStats() {
  if (!elements.theaterStaysStats) return;
  elements.theaterStaysStats.innerHTML = "<div class='health-metric'>Loading...</div>";
  try {
    const response = await fetch("/api/theater-stays/stats");
    const stats = await response.json();
    if (!response.ok) throw new Error(stats.error || "Failed to load theater stays");
    renderTheaterStayStats(stats);
  } catch (error) {
    elements.theaterStaysStats.innerHTML = "<div class='health-metric'>Failed to load stats</div>";
    if (elements.theaterStaysStatus) elements.theaterStaysStatus.textContent = error.message;
  }
}

async function refreshTheaterStays() {
  if (!elements.theaterStaysRefreshBtn) return;
  elements.theaterStaysStatus.textContent = "Refreshing TMDB now-playing…";
  elements.theaterStaysRefreshBtn.disabled = true;
  try {
    const response = await fetch("/api/theater-stays/refresh", { method: "POST" });
    const data = await response.json();
    if (!data.success) throw new Error(data.error || "Refresh failed");
    renderTheaterStayStats(data.stats || {});
    elements.theaterStaysStatus.textContent = `Stored ${data.stats?.inTheaters || 0} stays (${data.stats?.withIMAX || 0} IMAX).`;
    showToast("Theater stays refreshed");
  } catch (error) {
    elements.theaterStaysStatus.textContent = error.message;
    showToast(error.message, true);
  } finally {
    elements.theaterStaysRefreshBtn.disabled = false;
  }
}

async function clearTheaterStays() {
  if (!confirm("Clear inferred theater stays? Manual pins are kept.")) return;
  const response = await fetch("/api/theater-stays/clear", { method: "POST" });
  const data = await response.json();
  if (!data.success) {
    showToast(data.error || "Clear failed", true);
    return;
  }
  renderTheaterStayStats(data.stats || {});
  elements.theaterStaysStatus.textContent = `Cleared ${data.clearedCount || 0} inferred stays.`;
}

function renderDetailTheaterStays(movie) {
  if (!elements.detailTheaterStays) return;
  if (!movie.tmdbId) {
    elements.detailTheaterStays.classList.add("hidden");
    elements.detailTheaterStays.innerHTML = "";
    return;
  }
  elements.detailTheaterStays.classList.remove("hidden");
  elements.detailTheaterStays.innerHTML = `
    <div class="oscar-detail-row">
      <div class="oscar-detail-header">Theater Stay</div>
      <button class="oscar-fetch-btn" data-save="1">Save</button>
    </div>
    <label><input type="checkbox" data-flag="inTheaters" /> In theaters</label>
    <label><input type="checkbox" data-flag="hasIMAX" /> IMAX</label>
    <label>AMC <input type="url" data-ticket-site="amc" placeholder="https://www.amctheatres.com/movies/…/showtimes" /></label>
    <label>Fandango <input type="url" data-ticket-site="fandango" placeholder="https://www.fandango.com/…/movie-overview" /></label>
    <label>Atom <input type="url" data-ticket-site="atom" placeholder="https://www.atomtickets.com/movies/…" /></label>
  `;
  const inTheatersInput = elements.detailTheaterStays.querySelector("[data-flag='inTheaters']");
  const imaxInput = elements.detailTheaterStays.querySelector("[data-flag='hasIMAX']");
  fetch(`/api/theater-stays/${movie.tmdbId}`)
    .then((response) => response.json())
    .then((data) => {
      const stay = data.theaterStay;
      if (stay) {
        inTheatersInput.checked = true;
        imaxInput.checked = Boolean(stay.hasIMAX);
        const links = stay.ticketLinks || {};
        elements.detailTheaterStays.querySelectorAll("[data-ticket-site]").forEach((input) => {
          input.value = links[input.dataset.ticketSite] || "";
        });
      }
    })
    .catch(() => {});
  const saveBtn = elements.detailTheaterStays.querySelector("[data-save]");
  saveBtn.addEventListener("click", async () => {
    saveBtn.disabled = true;
    try {
      const ticketLinks = {};
      elements.detailTheaterStays.querySelectorAll("[data-ticket-site]").forEach((input) => {
        ticketLinks[input.dataset.ticketSite] = input.value.trim();
      });
      const response = await fetch("/api/theater-stays/update", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          tmdbId: movie.tmdbId,
          title: movie.title,
          inTheaters: inTheatersInput.checked,
          hasIMAX: imaxInput.checked,
          ticketLinks,
        }),
      });
      const data = await response.json();
      if (!data.success) throw new Error(data.error || "Save failed");
      showToast(data.theaterStay ? "Saved theater stay" : "Removed theater stay");
    } catch (error) {
      showToast(error.message, true);
    } finally {
      saveBtn.disabled = false;
    }
  });
}

// ---- Oscar Awards Enrichment ----

function openOscarModal() {
  elements.oscarModal.classList.remove("hidden");
  elements.oscarStatus.textContent = "";
  elements.oscarReport.innerHTML = "";
  elements.oscarProgress.classList.add("hidden");
  elements.oscarProgressFill.style.width = "0";
  const savedKey = localStorage.getItem("watchedit-omdb-api-key") || "";
  elements.oscarOmdbKey.value = savedKey;
  loadOscarStats();
}

function closeOscarModal() {
  elements.oscarModal.classList.add("hidden");
}

async function loadOscarStats() {
  elements.oscarStats.innerHTML = "<div class='health-metric'>Loading...</div>";
  try {
    const response = await fetch("/api/oscar-awards/stats");
    if (!response.ok) {
      elements.oscarStats.innerHTML = "<div class='health-metric'>Failed to load stats</div>";
      return;
    }
    const data = await response.json();
    elements.oscarStats.innerHTML = [
      ["Total Movies", data.totalMovies],
      ["With TMDB ID", data.moviesWithTmdb],
      ["With Oscar Data", data.moviesWithAwards],
      ["Oscar Winners", data.moviesWithWins],
      ["Oscar Nominees", data.moviesWithNominations],
      ["OMDB Eligible", data.eligibleForEnrichment],
      ["With Categories", data.withCategoryDetail ?? "—"],
      ["Wikidata Eligible", data.eligibleForWikidata ?? "—"],
    ]
      .map(
        ([label, value]) => `
          <div class="health-metric">
            <strong>${value}</strong>
            ${label}
          </div>
        `
      )
      .join("");
  } catch (error) {
    elements.oscarStats.innerHTML = `<div class='health-metric'>Error: ${error.message}</div>`;
  }
}

async function runOscarEnrichment() {
  const mode = elements.oscarMode.value;
  const delayMs = parseInt(elements.oscarDelay.value, 10) || 200;
  const omdbApiKey = elements.oscarOmdbKey.value.trim();
  const modeLabel = mode === "all" ? "re-enrich all movies" : "enrich movies missing Oscar data";

  if (!omdbApiKey) {
    showToast("Enter an OMDB API key first (free at omdbapi.com/apikey.aspx)", true);
    elements.oscarOmdbKey.focus();
    return;
  }

  localStorage.setItem("watchedit-omdb-api-key", omdbApiKey);

  openConfirmModal({
    message: `Run Oscar Awards enrichment (${modeLabel})? This calls OMDB API for each eligible movie and writes to the Min Cloud catalog. Movies are processed in batches of 100.`,
    onConfirm: async () => {
      elements.oscarEnrichBtn.disabled = true;
      elements.oscarEnrichBtn.textContent = "Enriching...";
      elements.oscarStatus.textContent = "Starting Oscar enrichment...";
      elements.oscarProgress.classList.remove("hidden");
      elements.oscarProgressFill.style.width = "0";
      elements.oscarProgressLabel.textContent = "Preparing...";
      elements.oscarReport.innerHTML = "";

      let offset = 0;
      let totalEnriched = 0;
      let totalNoAwards = 0;
      let totalFailed = 0;
      let totalProcessed = 0;
      let totalEligible = 0;
      const allReportItems = [];
      let aborted = false;

      try {
        while (true) {
          const response = await fetch("/api/oscar-awards/enrich", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ mode, delayMs, omdbApiKey, batchSize: 100, offset }),
          });

          if (!response.ok) {
            const message = await readErrorMessage(response, "Oscar enrichment failed");
            elements.oscarStatus.textContent = message;
            showToast(message, true);
            aborted = true;
            break;
          }

          const data = await response.json();
          totalEligible = data.totalEligible;
          totalEnriched += data.enrichedCount;
          totalNoAwards += data.noAwardsCount;
          totalFailed += data.failedCount;
          totalProcessed += data.processedInBatch;
          allReportItems.push(...(data.report || []));

          const pct = totalEligible > 0 ? Math.round((totalProcessed / totalEligible) * 100) : 100;
          elements.oscarProgressFill.style.width = `${pct}%`;
          elements.oscarProgressLabel.textContent =
            `${totalProcessed} / ${totalEligible} movies   ${totalEnriched} enriched`;
          elements.oscarStatus.textContent =
            `Batch ${Math.ceil(totalProcessed / 100)}: Enriched ${totalEnriched}   No Oscars ${totalNoAwards}   Failed ${totalFailed}`;

          renderOscarReport(allReportItems);

          if (data.abortedDueToKey) {
            showToast("Invalid OMDB API key — get a free key at omdbapi.com/apikey.aspx", true);
            aborted = true;
            break;
          }

          if (data.nextOffset == null || data.processedInBatch === 0) {
            break;
          }

          offset = data.nextOffset;
        }

        elements.oscarProgressFill.style.width = "100%";
        elements.oscarProgressLabel.textContent = `Done — ${totalProcessed} / ${totalEligible} movies processed`;
        elements.oscarStatus.textContent =
          `Enriched: ${totalEnriched}   No Oscars: ${totalNoAwards}   Failed: ${totalFailed}`;

        await loadOscarStats();
        await reloadData(state.selectedMovieIndex);

        if (!aborted) {
          if (totalFailed > 0) {
            showToast(`Oscar enrichment completed with ${totalFailed} failures`, true);
          } else {
            showToast(`Oscar enrichment complete — ${totalEnriched} movies enriched`);
          }
        }
      } catch (error) {
        elements.oscarStatus.textContent = `Error: ${error.message}`;
        showToast(error.message, true);
      } finally {
        elements.oscarEnrichBtn.disabled = false;
        elements.oscarEnrichBtn.textContent = "Enrich Movies";
      }
    },
  });
}

async function clearOscarAwards() {
  openConfirmModal({
    message: "Clear ALL Oscar award data from every movie? This cannot be undone.",
    onConfirm: async () => {
      elements.oscarClearBtn.disabled = true;
      try {
        const response = await fetch("/api/oscar-awards/clear", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
        });
        if (!response.ok) {
          showToast("Failed to clear Oscar data", true);
          return;
        }
        const data = await response.json();
        showToast(`Cleared Oscar data from ${data.clearedCount} movies`);
        await loadOscarStats();
        await reloadData(state.selectedMovieIndex);
      } catch (error) {
        showToast(error.message, true);
      } finally {
        elements.oscarClearBtn.disabled = false;
      }
    },
  });
}

async function runWikidataEnrichment() {
  const mode = elements.oscarWikidataMode.value;
  const delayMs = parseInt(elements.oscarWikidataDelay.value, 10) || 350;
  const modeLabel = mode === "all" ? "re-fetch all" : "fetch missing category details";

  openConfirmModal({
    message: `Run Wikidata enrichment (${modeLabel})? This queries Wikidata SPARQL for category-level Oscar data. Movies are processed in batches of 50.`,
    onConfirm: async () => {
      elements.oscarWikidataBtn.disabled = true;
      elements.oscarWikidataBtn.textContent = "Fetching…";
      elements.oscarStatus.textContent = "Starting Wikidata enrichment…";
      elements.oscarProgress.classList.remove("hidden");
      elements.oscarProgressFill.style.width = "0";
      elements.oscarProgressLabel.textContent = "Preparing…";
      elements.oscarReport.innerHTML = "";

      let offset = 0;
      let totalEnriched = 0;
      let totalNoData = 0;
      let totalFailed = 0;
      let totalProcessed = 0;
      let totalEligible = 0;
      const allReportItems = [];

      try {
        while (true) {
          const response = await fetch("/api/oscar-awards/wikidata-enrich", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ mode, delayMs, batchSize: 50, offset }),
          });

          if (!response.ok) {
            const message = await readErrorMessage(response, "Wikidata enrichment failed");
            elements.oscarStatus.textContent = message;
            showToast(message, true);
            break;
          }

          const data = await response.json();
          totalEligible = data.totalEligible;
          totalProcessed += data.processedInBatch;
          totalEnriched += data.enrichedCount || 0;
          totalNoData += data.noDataCount || 0;
          totalFailed += data.failedCount || 0;
          allReportItems.push(...(data.report || []));

          const pct = totalEligible > 0 ? Math.round((totalProcessed / totalEligible) * 100) : 100;
          elements.oscarProgressFill.style.width = `${pct}%`;
          elements.oscarProgressLabel.textContent =
            `${totalProcessed} / ${totalEligible}   ${totalEnriched} enriched`;
          elements.oscarStatus.textContent =
            `Batch ${Math.ceil(totalProcessed / 50)}: ${data.enrichedCount} enriched   ${data.noDataCount} no data   ${data.failedCount} failed`;
          renderOscarReport(allReportItems);

          if (!data.nextOffset || data.processedInBatch === 0) break;
          offset = data.nextOffset;
        }

        elements.oscarProgressFill.style.width = "100%";
        elements.oscarProgressLabel.textContent = `Done — ${totalProcessed} processed   ${totalEnriched} enriched`;
        elements.oscarStatus.textContent =
          `Enriched: ${totalEnriched}   No data: ${totalNoData}   Failed: ${totalFailed}`;
        await loadOscarStats();
        await reloadData(state.selectedMovieIndex);
        showToast(`Wikidata enrichment complete — ${totalEnriched} movies enriched`);
      } catch (error) {
        elements.oscarStatus.textContent = `Error: ${error.message}`;
        showToast(error.message, true);
      } finally {
        elements.oscarWikidataBtn.disabled = false;
        elements.oscarWikidataBtn.textContent = "Wikidata Categories";
      }
    },
  });
}

function renderOscarReport(items) {
  if (!items.length) {
    elements.oscarReport.innerHTML = "<div class='status-text'>No results.</div>";
    return;
  }

  const enriched = items.filter((i) => i.status === "enriched");
  const noOscars = items.filter((i) => i.status === "no-oscars");
  const failed = items.filter((i) => i.status === "failed");
  const sorted = [...enriched, ...failed, ...noOscars];

  const rows = sorted
    .map((item) => {
      const statusClass = `status-${item.status}`;
      let detail = "";
      if (item.status === "enriched") {
        const parts = [];
        if (item.wins > 0) parts.push(`${item.wins}W`);
        if (item.nominations > 0) parts.push(`${item.nominations}N`);
        detail = parts.join(" / ");
      } else if (item.status === "failed") {
        detail = item.error || "";
      } else if (item.rawAwards) {
        detail = item.rawAwards;
      }
      const statusLabel =
        item.status === "enriched" ? "Enriched" :
        item.status === "no-oscars" ? "No Oscars" :
        item.status === "failed" ? "Failed" : item.status;
      return `<tr>
        <td>${item.title || ""}</td>
        <td>${item.tmdbId || ""}</td>
        <td class="${statusClass}">${statusLabel}</td>
        <td>${detail}</td>
      </tr>`;
    })
    .join("");

  elements.oscarReport.innerHTML = `
    <table class="oscar-report-table">
      <thead><tr><th>Title</th><th>TMDB</th><th>Status</th><th>Detail</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function refreshLucideIcons(root) {
  if (typeof lucide !== "undefined" && lucide.createIcons) {
    lucide.createIcons(root ? { root: root } : undefined);
  }
}

function proxyMockupImages() {
  var allowedDomains = ["image.tmdb.org", "is1-ssl.mzstatic.com", "is2-ssl.mzstatic.com", "is3-ssl.mzstatic.com", "is4-ssl.mzstatic.com", "is5-ssl.mzstatic.com"];
  var imgs = document.querySelectorAll(".app-phone-screen img, .theme-preview-poster-card img, .theme-preview-backdrop img");
  imgs.forEach(function(img) {
    var src = img.getAttribute("src") || "";
    if (!src.startsWith("https://")) return;
    var dominated = allowedDomains.some(function(d) { return src.indexOf(d) !== -1; });
    if (!dominated) return;
    var proxied = "/api/image-proxy?url=" + encodeURIComponent(src);
    img.setAttribute("data-original-src", src);
    img.setAttribute("src", proxied);
    img.onerror = function() {
      if (img.dataset.placeholderApplied) return;
      img.dataset.placeholderApplied = "1";
      img.style.display = "none";
      var ph = document.createElement("div");
      ph.className = "img-placeholder";
      ph.style.width = img.width ? img.width + "px" : "100%";
      ph.style.height = img.height ? img.height + "px" : "100%";
      img.parentNode.insertBefore(ph, img);
    };
  });
}

// ---- Canvas Design Tool ----

var canvas = {
  zoom: 0.7, panX: 0, panY: 0,
  isPanning: false, startX: 0, startY: 0,
  activeTool: "inspect",
  spaceHeld: false
};

function canvasApplyTransform() {
  var surface = document.getElementById("canvasSurface");
  if (!surface) return;
  surface.style.transform = "translate(" + canvas.panX + "px," + canvas.panY + "px) scale(" + canvas.zoom + ")";
  var label = document.getElementById("canvasZoomLabel");
  if (label) label.textContent = Math.round(canvas.zoom * 100) + "%";
}

function canvasZoom(delta, cx, cy) {
  var viewport = document.getElementById("canvasViewport");
  if (!viewport) return;
  var rect = viewport.getBoundingClientRect();
  if (cx === undefined) cx = rect.width / 2;
  if (cy === undefined) cy = rect.height / 2;

  var oldZoom = canvas.zoom;
  canvas.zoom = Math.min(3, Math.max(0.1, canvas.zoom + delta));
  var scale = canvas.zoom / oldZoom;

  canvas.panX = cx - scale * (cx - canvas.panX);
  canvas.panY = cy - scale * (cy - canvas.panY);
  canvasApplyTransform();
}

function canvasZoomToFit() {
  var viewport = document.getElementById("canvasViewport");
  var artboards = document.getElementById("appContent");
  if (!viewport || !artboards) return;
  var vr = viewport.getBoundingClientRect();
  var contentW = artboards.scrollWidth;
  var contentH = artboards.scrollHeight;
  if (!contentW || !contentH) return;
  var pad = 60;
  var scaleX = (vr.width - pad) / contentW;
  var scaleY = (vr.height - pad) / contentH;
  canvas.zoom = Math.min(scaleX, scaleY, 1);
  canvas.panX = (vr.width - contentW * canvas.zoom) / 2;
  canvas.panY = (vr.height - contentH * canvas.zoom) / 2;
  canvasApplyTransform();
}

function canvasSetTool(tool) {
  canvas.activeTool = tool;
  var viewport = document.getElementById("canvasViewport");
  document.querySelectorAll(".cbb-btn[data-tool]").forEach(function(btn) {
    btn.classList.toggle("is-active", btn.dataset.tool === tool);
  });
  if (viewport) {
    viewport.classList.toggle("is-panning", tool === "pan");
    viewport.style.cursor = tool === "pan" ? "grab" : "";
  }
  if (tool === "inspect") {
    switchPanelTab("inspect");
  }
}

function toggleArtboardInfo(btn) {
  var artboard = btn.closest(".canvas-artboard");
  if (!artboard) return;
  var panel = artboard.querySelector(".artboard-info-panel");
  if (!panel) return;
  var isOpen = panel.classList.toggle("open");
  btn.classList.toggle("is-active", isOpen);
}

function initCanvas() {
  var viewport = document.getElementById("canvasViewport");
  if (!viewport) return;

  canvasApplyTransform();

  viewport.addEventListener("wheel", function(e) {
    e.preventDefault();
    var rect = viewport.getBoundingClientRect();
    if (e.ctrlKey || e.metaKey) {
      canvasZoom(-e.deltaY * 0.003, e.clientX - rect.left, e.clientY - rect.top);
    } else {
      canvas.panX -= e.deltaX;
      canvas.panY -= e.deltaY;
      canvasApplyTransform();
    }
  }, { passive: false });

  viewport.addEventListener("mousedown", function(e) {
    if (canvas.activeTool === "pan" || canvas.spaceHeld) {
      canvas.isPanning = true;
      canvas.startX = e.clientX - canvas.panX;
      canvas.startY = e.clientY - canvas.panY;
      viewport.classList.add("is-panning");
      e.preventDefault();
    }
  });

  window.addEventListener("mousemove", function(e) {
    if (canvas.isPanning) {
      canvas.panX = e.clientX - canvas.startX;
      canvas.panY = e.clientY - canvas.startY;
      canvasApplyTransform();
    }
  });

  window.addEventListener("mouseup", function() {
    if (canvas.isPanning) {
      canvas.isPanning = false;
      if (canvas.activeTool !== "pan") {
        var vp = document.getElementById("canvasViewport");
        if (vp) vp.classList.remove("is-panning");
      }
    }
  });

  window.addEventListener("keydown", function(e) {
    var isInput = e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA";
    if (e.code === "Space" && !e.repeat && !isInput) {
      e.preventDefault();
      canvas.spaceHeld = true;
      viewport.classList.add("is-panning");
    }
    if (!isInput) {
      if (e.key === "v" || e.key === "V") canvasSetTool("inspect");
      if (e.key === "h" || e.key === "H") canvasSetTool("pan");
      if (e.key === "=" || e.key === "+") { e.preventDefault(); canvasZoom(0.1); }
      if (e.key === "-") { e.preventDefault(); canvasZoom(-0.1); }
      if (e.key === "1" && e.shiftKey) { e.preventDefault(); canvasZoomToFit(); }
      if (e.key === "0" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        canvas.zoom = 1;
        canvasApplyTransform();
      }
    }
    if (e.key === "." && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      toggleCanvasUI();
    }
  });

  window.addEventListener("keyup", function(e) {
    if (e.code === "Space") {
      canvas.spaceHeld = false;
      if (canvas.activeTool !== "pan") {
        viewport.classList.remove("is-panning");
      }
    }
  });

  // Bottom bar: tool buttons
  document.querySelectorAll(".cbb-btn[data-tool]").forEach(function(btn) {
    btn.addEventListener("click", function() { canvasSetTool(btn.dataset.tool); });
  });

  // Bottom bar: zoom
  var zoomInBtn = document.getElementById("zoomInBtn");
  var zoomOutBtn = document.getElementById("zoomOutBtn");
  var zoomFitBtn = document.getElementById("zoomFitBtn");
  var zoomLabel = document.getElementById("canvasZoomLabel");
  if (zoomInBtn) zoomInBtn.addEventListener("click", function() { canvasZoom(0.1); });
  if (zoomOutBtn) zoomOutBtn.addEventListener("click", function() { canvasZoom(-0.1); });
  if (zoomFitBtn) zoomFitBtn.addEventListener("click", canvasZoomToFit);
  if (zoomLabel) zoomLabel.addEventListener("click", function() {
    canvas.zoom = 1; canvasApplyTransform();
  });

  // Chrome toggle button
  var chromeBtn = document.getElementById("toggleChromeBtn");
  if (chromeBtn) chromeBtn.addEventListener("click", toggleDeviceChrome);

  // Right panel tabs
  document.querySelectorAll(".crp-tab").forEach(function(tab) {
    tab.addEventListener("click", function() { switchPanelTab(tab.dataset.panelTab); });
  });

  setTimeout(canvasZoomToFit, 150);
}

// ---- Live Link (SSE) ----

var liveLink = { connected: false, evtSource: null, watching: [] };

function setLiveLinkStatus(connected, detail) {
  liveLink.connected = connected;
  var dot = document.getElementById("live-link-dot");
  var label = document.getElementById("live-link-label");
  if (dot) dot.className = "live-link-dot " + (connected ? "live" : "disconnected");
  if (label) label.textContent = detail || (connected ? "Live" : "Disconnected");
}

async function handleLiveChange(source) {
  var label = document.getElementById("live-link-label");
  var fileLabels = {
    designSystem: "DesignSystem.swift",
    settings: "MovieListView.swift",
    detailLayout: "MovieDetailLayoutStyles.swift",
    themes: "theme_presets.json"
  };
  var fileName = fileLabels[source] || source;
  if (label) label.textContent = fileName + " changed…";

  try {
    if (source === "designSystem") {
      await loadDesignSystemTokens();
    } else if (source === "settings") {
      await loadAppSettingsFromServer();
      initAppearanceSettings();
      refreshLucideIcons();
    } else if (source === "detailLayout") {
      await loadAppSettingsFromServer();
      var detailSel = document.getElementById("app-detail-layout");
      if (detailSel) applyDetailLayout(detailSel.value);
      var actionSel = document.getElementById("app-action-bar-layout");
      if (actionSel) applyActionBarLayout(actionSel.value);
    } else if (source === "themes") {
      await loadThemesFromServer();
      initThemeChips();
      if (activeTheme) applyTheme(activeTheme);
      renderThemePreview();
      refreshLucideIcons();
    }
  } catch (err) {
    console.log("❌ [LIVE] Refresh failed:", err);
  }

  setTimeout(function() { setLiveLinkStatus(true); }, 1200);
}

function connectLiveLink() {
  if (liveLink.evtSource) { liveLink.evtSource.close(); }

  var es = new EventSource("/api/live/changes");
  liveLink.evtSource = es;

  es.addEventListener("connected", function(e) {
    try {
      var data = JSON.parse(e.data);
      liveLink.watching = data.watching || [];
    } catch (_) {}
    setLiveLinkStatus(true);
  });

  es.addEventListener("file-change", function(e) {
    try {
      var data = JSON.parse(e.data);
      handleLiveChange(data.source);
    } catch (_) {}
  });

  es.onerror = function() {
    setLiveLinkStatus(false, "Reconnecting…");
  };
}

async function init() {
  try {
    await loadDesignSystemTokens();
    await Promise.all([loadThemesFromServer(), loadAppSettingsFromServer()]);
    await reloadData();
    bindAdminNavigation();
    bindDesignNavigation();
    bindOpsNavigation();
    bindAppNavigation();
    setAdminView(getAdminViewFromHash());
    bindEvents();
    renderThemePreview();
    initAppearanceSettings();
    refreshLucideIcons();
    proxyMockupImages();
    initCanvas();
    connectLiveLink();
  } catch (error) {
    showToast(error.message, true);
  }
}

init();

