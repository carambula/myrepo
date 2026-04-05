const state = {
  bootstrap: null,
  races: [],
  stages: [],
  stagePodcastEpisodes: [],
  filteredRaces: [],
  selectedRaceIndex: null,
  selectedRace: null,
  podcastPreviewItems: [],
};

const elements = {
  searchInput: document.getElementById("searchInput"),
  seriesInput: document.getElementById("seriesInput"),
  disciplineInput: document.getElementById("disciplineInput"),
  raceTableBody: document.getElementById("raceTableBody"),
  raceCount: document.getElementById("raceCount"),
  detailEmpty: document.getElementById("detailEmpty"),
  detailCard: document.getElementById("detailCard"),
  healthBtn: document.getElementById("healthBtn"),
  previewPodcastsBtn: document.getElementById("previewPodcastsBtn"),
  commitPodcastsBtn: document.getElementById("commitPodcastsBtn"),
  themesBtn: document.getElementById("themesBtn"),
  refreshResultsBtn: document.getElementById("refreshResultsBtn"),
  regenerateBtn: document.getElementById("regenerateBtn"),
  refreshBtn: document.getElementById("refreshBtn"),
  healthStatus: document.getElementById("healthStatus"),
  healthMetrics: document.getElementById("healthMetrics"),
  podcastStatus: document.getElementById("podcastStatus"),
  podcastPreview: document.getElementById("podcastPreview"),
  toast: document.getElementById("toast"),
};

function getEffectiveImageUrl(race) {
  const url = race?.effectiveImageUrl ?? race?.imageUrl ?? race?.image_url ?? null;
  return url && (/^https?:\/\//i.test(url) || /^\//.test(url)) ? url : null;
}

function getArtworkVariants(race) {
  const v = race?.artworkVariants || race?.artwork_variants || {};
  const portrait = v.portraitUrl || v.portrait_url || null;
  const landscape = v.landscapeUrl || v.landscape_url || null;
  const square = v.squareUrl || v.square_url || null;
  return { portrait, landscape, square };
}

function showToast(message, isError = false) {
  elements.toast.textContent = message;
  elements.toast.classList.toggle("error", isError);
  elements.toast.classList.remove("hidden");
  setTimeout(() => elements.toast.classList.add("hidden"), 2800);
}

function bindInput(element, handler) {
  if (!element) return;
  element.addEventListener("input", handler);
}

function raceDate(race) {
  return race?.startDate ?? race?.start_date ?? "";
}

function raceId(race) {
  return race?.raceId ?? race?.race_id ?? "";
}

function formatDateRange(race) {
  const start = race?.startDate ?? race?.start_date ?? "—";
  const end = race?.endDate ?? race?.end_date ?? "—";
  return `${start} → ${end}`;
}

function formatRaceStartInfo(race) {
  const local = race?.startTimeLocal ?? race?.start_time_local ?? null;
  const tz = race?.startTimezone ?? race?.start_timezone ?? null;
  const utc = race?.startDatetimeUtc ?? race?.start_datetime_utc ?? null;
  const localText = local ? `${local}${tz ? ` (${tz})` : ""}` : "—";
  return {
    localText,
    utcText: utc || "—",
  };
}

function getStagesCollection() {
  return state.bootstrap?.stages || state.bootstrap?.raceStages || state.bootstrap?.race_stages || [];
}

function getStagePodcastLinksCollection() {
  return (
    state.bootstrap?.stagePodcastEpisodes ||
    state.bootstrap?.stage_podcast_episodes ||
    []
  );
}

function getRaceResultsCollection() {
  return state.bootstrap?.raceResults || state.bootstrap?.race_results || [];
}

function getStageResultsCollection() {
  return state.bootstrap?.stageResults || state.bootstrap?.stage_results || [];
}

function humanizeResultSource(source) {
  const normalized = String(source || "").toLowerCase();
  if (normalized === "wikidata") return "Wikidata";
  if (normalized === "pcs") return "PCS";
  if (normalized === "official") return "Official";
  return source || "Unknown";
}

function getRaceStages(race) {
  const id = raceId(race);
  if (!id) return [];
  return getStagesCollection()
    .filter((stage) => (stage.raceId ?? stage.race_id) === id)
    .sort((left, right) => {
      const leftDate = left.date || "";
      const rightDate = right.date || "";
      if (leftDate !== rightDate) return leftDate.localeCompare(rightDate);
      const leftNum = Number(left.stageNumber ?? left.stage_number ?? 9999);
      const rightNum = Number(right.stageNumber ?? right.stage_number ?? 9999);
      return leftNum - rightNum;
    });
}

async function fetchBootstrap() {
  const response = await fetch("/api/bootstrap");
  if (!response.ok) {
    throw new Error("Failed to load bootstrap data");
  }
  const bootstrap = await response.json();
  state.bootstrap = bootstrap;
  state.races = bootstrap.races || [];
  state.stages = bootstrap.stages || bootstrap.raceStages || bootstrap.race_stages || [];
  state.stagePodcastEpisodes =
    bootstrap.stagePodcastEpisodes || bootstrap.stage_podcast_episodes || [];
}

async function loadHealth() {
  const response = await fetch("/api/health");
  if (!response.ok) {
    showToast("Health check failed", true);
    return;
  }
  const data = await response.json();
  elements.healthStatus.textContent = `Races: ${data.races}, Streamers: ${data.streamers ?? 0}, Links: ${data.raceStreams ?? 0}`;
  elements.healthMetrics.innerHTML = [
    ["Races", data.races],
    ["Stages", data.stages ?? 0],
    ["Teams", data.teams],
    ["Athletes", data.athletes],
    ["Participants", data.participants],
    ["Streamers", data.streamers ?? 0],
    ["Race–stream links", data.raceStreams ?? 0],
    ["Podcast sources", data.podcastSources ?? 0],
    ["Podcast episodes", data.podcastEpisodes ?? 0],
    ["Race–podcast links", data.racePodcastEpisodes ?? 0],
    ["Stage–podcast links", data.stagePodcastEpisodes ?? 0],
    ["Race results", data.raceResults ?? 0],
    ["Stage results", data.stageResults ?? 0],
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

function renderPodcastPreview() {
  if (!elements.podcastPreview) return;
  if (!state.podcastPreviewItems.length) {
    elements.podcastPreview.innerHTML = "";
    return;
  }
  const rows = state.podcastPreviewItems
    .slice(0, 50)
    .map(
      (item) => `
        <tr>
          <td>${item.sourceName || ""}</td>
          <td>${item.title || ""}</td>
          <td>${item.raceName || ""}</td>
          <td>${item.publishedAt ? String(item.publishedAt).slice(0, 10) : ""}</td>
        </tr>
      `
    )
    .join("");
  elements.podcastPreview.innerHTML = `
    <table class="race-table">
      <thead>
        <tr>
          <th>Podcast</th>
          <th>Episode</th>
          <th>Matched Race</th>
          <th>Published</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

async function previewPodcasts() {
  if (!elements.podcastStatus) return;
  elements.podcastStatus.textContent = "Scraping podcast feeds...";
  const response = await fetch("/api/podcasts/preview", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifiers: [] }),
  });
  if (!response.ok) {
    elements.podcastStatus.textContent = "Podcast preview failed.";
    showToast("Podcast preview failed", true);
    return;
  }
  const data = await response.json();
  state.podcastPreviewItems = data.items || [];
  elements.podcastStatus.textContent = `Matched ${state.podcastPreviewItems.length} new episodes to races (4-month lookback).`;
  renderPodcastPreview();
  showToast("Podcast preview complete");
}

async function commitPodcasts() {
  if (!state.podcastPreviewItems.length) {
    showToast("Run podcast preview first", true);
    return;
  }
  const response = await fetch("/api/podcasts/commit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ items: state.podcastPreviewItems }),
  });
  if (!response.ok) {
    showToast("Podcast commit failed", true);
    return;
  }
  const data = await response.json();
  const report = data.report || {};
  elements.podcastStatus.textContent = `Committed ${report.addedLinks ?? 0} race links from ${report.addedEpisodes ?? 0} episodes.`;
  state.podcastPreviewItems = [];
  renderPodcastPreview();
  await reloadData();
  showToast("Podcast links committed");
}

function applyFilters() {
  const searchText = elements.searchInput.value.trim().toLowerCase();
  const seriesText = elements.seriesInput.value.trim().toLowerCase();
  const disciplineText = elements.disciplineInput.value.trim().toLowerCase();

  let races = [...state.races];
  if (searchText) {
    races = races.filter((race) => race.name?.toLowerCase().includes(searchText));
  }
  if (seriesText) {
    races = races.filter((race) => (race.series || "").toLowerCase().includes(seriesText));
  }
  if (disciplineText) {
    races = races.filter((race) => (race.discipline || "").toLowerCase().includes(disciplineText));
  }

  races.sort((a, b) => raceDate(a).localeCompare(raceDate(b)));
  state.filteredRaces = races;
  renderList();
}

function renderList() {
  elements.raceTableBody.innerHTML = "";
  elements.raceCount.textContent = `${state.filteredRaces.length} races`;
  state.filteredRaces.forEach((race) => {
    const imgUrl = getEffectiveImageUrl(race);
    const row = document.createElement("tr");
    row.dataset.index = race.__index;
    row.innerHTML = `
      <td class="col-thumb">${imgUrl ? `<img src="${imgUrl}" alt="" class="race-thumb" />` : ""}</td>
      <td>${race.name || ""}</td>
      <td>${formatDateRange(race)}</td>
      <td>${race.series || ""}</td>
      <td>${race.discipline || ""}</td>
      <td>${race.genderDivision || ""}</td>
    `;
    row.addEventListener("click", () => selectRace(race.__index));
    if (race.__index === state.selectedRaceIndex) {
      row.classList.add("selected");
    }
    elements.raceTableBody.append(row);
  });
}

function getStreamersForRace(race) {
  const raceId = race?.raceId ?? race?.race_id ?? "";
  if (!raceId) return [];
  const streamers = state.bootstrap?.streamers || [];
  const raceStreams = state.bootstrap?.raceStreams || [];
  return raceStreams
    .filter((rs) => (rs.raceId ?? rs.race_id) === raceId)
    .map((rs) => {
      const sid = rs.streamerId ?? rs.streamer_id;
      const s = streamers.find((x) => (x.streamerId ?? x.streamer_id) === sid);
      return s ? { streamer: s, stream: rs } : null;
    })
    .filter(Boolean);
}

function getPodcastsForRace(race) {
  const id = raceId(race);
  if (!id) return [];
  const episodes = state.bootstrap?.podcastEpisodes || [];
  const links = state.bootstrap?.racePodcastEpisodes || [];
  const sources = state.bootstrap?.podcastSources || [];
  return links
    .filter((link) => (link.raceId ?? link.race_id) === id)
    .map((link) => {
      const episodeId = link.episodeId ?? link.episode_id;
      const episode = episodes.find((ep) => (ep.episodeId ?? ep.episode_id) === episodeId);
      if (!episode) return null;
      const sourceId = episode.sourceId ?? episode.source_id;
      const source = sources.find((s) => (s.sourceId ?? s.source_id) === sourceId);
      return { episode, source, link };
    })
    .filter(Boolean);
}

function selectRace(index) {
  const race = state.races.find((item) => item.__index === index);
  if (!race) return;
  state.selectedRaceIndex = index;
  state.selectedRace = race;
  elements.detailEmpty.classList.add("hidden");
  elements.detailCard.classList.remove("hidden");

  const streamersForRace = getStreamersForRace(race);
  const podcastsForRace = getPodcastsForRace(race);
  const raceStages = getRaceStages(race);
  const stagePodcastLinks = getStagePodcastLinksCollection();
  const raceStageIds = new Set(raceStages.map((stage) => stage.stageId ?? stage.stage_id));
  const stagePodcastCount = stagePodcastLinks.filter((link) =>
    raceStageIds.has(link.stageId ?? link.stage_id)
  ).length;
  const raceStartInfo = formatRaceStartInfo(race);
  const streamingHtml =
    streamersForRace.length > 0
      ? `
    <div class="detail-section">Streaming</div>
    ${streamersForRace
      .map(({ streamer, stream }) => {
        const url = stream.streamUrl ?? stream.stream_url ?? streamer.websiteUrl ?? streamer.website_url;
        const regionCodes = stream.regionCodes ?? stream.region_codes ?? [];
        const regions = (Array.isArray(regionCodes) ? regionCodes : []).join(", ") || "—";
        const name = streamer.name || streamer.slug || "Stream";
        const label = url
          ? `<a href="${url}" target="_blank" rel="noopener">${name}</a>`
          : name;
        return `<div class="detail-row"><span>${label}</span><strong>${regions}</strong></div>`;
      })
      .join("")}
  `
      : "";
  const podcastsHtml =
    podcastsForRace.length > 0
      ? `
    <div class="detail-section">Podcasts</div>
    ${podcastsForRace
      .map(({ episode, source }) => {
        const url = episode.episodeUrl ?? episode.episode_url;
        const sourceName = source?.name || "Podcast";
        const title = episode.title || episode.rawTitle || "Episode";
        const published = (episode.publishedAt ?? episode.published_at ?? "").slice(0, 10);
        const label = url
          ? `<a href="${url}" target="_blank" rel="noopener">${sourceName}: ${title}</a>`
          : `${sourceName}: ${title}`;
        return `<div class="detail-row"><span>${label}</span><strong>${published || "—"}</strong></div>`;
      })
      .join("")}
  `
      : "";
  const raceResults = getRaceResultsCollection().filter(
    (result) => (result.raceId ?? result.race_id) === raceId(race)
  );
  const stageResultsByStageId = new Map();
  for (const result of getStageResultsCollection()) {
    const stageId = result.stageId ?? result.stage_id;
    if (!stageId) continue;
    const list = stageResultsByStageId.get(stageId) || [];
    list.push(result);
    stageResultsByStageId.set(stageId, list);
  }
  const raceResultsHtml =
    raceResults.length > 0
      ? `
    <div class="detail-section">Race Results</div>
    ${raceResults
      .slice()
      .sort((a, b) => Number(a.rank ?? a.rank ?? 999) - Number(b.rank ?? b.rank ?? 999))
      .map((result) => {
        const rank = result.rank ?? "—";
        const rider = result.athleteName ?? result.athlete_name ?? "Unknown";
        const source = humanizeResultSource(result.source);
        const resultText = result.resultText ?? result.result_text ?? "";
        return `<div class="detail-row"><span>#${rank} ${rider}</span><strong>${source}${resultText ? `   ${resultText}` : ""}</strong></div>`;
      })
      .join("")}
  `
      : "";
  const stagesHtml =
    raceStages.length > 0
      ? `
    <div class="detail-section">Stages (${raceStages.length})</div>
    ${raceStages
      .map((stage) => {
        const number = stage.stageNumber ?? stage.stage_number;
        const isRestDay = Boolean(stage.isRestDay ?? stage.is_rest_day);
        const name = stage.name || (isRestDay ? "Rest Day" : "Stage");
        const stageType = stage.stageType ?? stage.stage_type;
        const date = stage.date || "—";
        const departTime = stage.departTimeLocal ?? stage.depart_time_local;
        const departTz = stage.departTimezone ?? stage.depart_timezone;
        const leftLabel = isRestDay
          ? `${name} (${date})`
          : `${number ? `Stage ${number}: ` : ""}${name}`;
        const rightParts = [date];
        if (stageType) rightParts.push(stageType);
        if (departTime) rightParts.push(`${departTime}${departTz ? ` ${departTz}` : ""}`);
        const stageId = stage.stageId ?? stage.stage_id;
        const stageResults = (stageResultsByStageId.get(stageId) || [])
          .slice()
          .sort((a, b) => Number(a.rank ?? 999) - Number(b.rank ?? 999));
        const stageWinner = stageResults.find((result) => Number(result.rank) === 1) || null;
        if (stageWinner) {
          const winner = stageWinner.athleteName ?? stageWinner.athlete_name ?? "Unknown";
          const source = humanizeResultSource(stageWinner.source);
          rightParts.push(`Winner: ${winner} (${source})`);
        }
        return `<div class="detail-row"><span>${leftLabel}</span><strong>${rightParts.join("   ")}</strong></div>`;
      })
      .join("")}
    <div class="detail-row"><span>Stage podcast links</span><strong>${stagePodcastCount}</strong></div>
  `
      : "";

  const imageUrl = getEffectiveImageUrl(race);
  const currentImageUrl = race?.imageUrl ?? race?.image_url ?? "";
  const variants = getArtworkVariants(race);
  const variantButtons = [
    ["portrait", variants.portrait],
    ["landscape", variants.landscape],
    ["square", variants.square],
  ]
    .filter(([, url]) => !!url)
    .map(
      ([format, url]) =>
        `<button type="button" class="variant-btn" data-variant-url="${url}" data-format="${format}">Use ${format}</button>`
    )
    .join("");

  elements.detailCard.innerHTML = `
    <div class="detail-artwork">
      ${imageUrl ? `<img src="${imageUrl}" alt="Race artwork" class="detail-artwork-img" onerror="this.style.display='none'" />` : ""}
      <div class="detail-artwork-edit">
        <label>
          Image URL
          <input type="url" id="imageUrlInput" value="${(currentImageUrl || "").replace(/"/g, "&quot;")}" placeholder="https://..." />
        </label>
        <button type="button" id="saveImageBtn" class="primary">Save image</button>
      </div>
      ${variantButtons ? `<div class="variant-actions">${variantButtons}</div>` : ""}
    </div>
    <div class="detail-row"><span>Name</span><strong>${race.name || "—"}</strong></div>
    <div class="detail-row"><span>Dates</span><strong>${formatDateRange(race)}</strong></div>
    <div class="detail-row"><span>Start (local)</span><strong>${raceStartInfo.localText}</strong></div>
    <div class="detail-row"><span>Start (UTC)</span><strong>${raceStartInfo.utcText}</strong></div>
    <div class="detail-row"><span>Series</span><strong>${race.series || "—"}</strong></div>
    <div class="detail-row"><span>Classification</span><strong>${race.classification || "—"}</strong></div>
    <div class="detail-row"><span>Discipline</span><strong>${race.discipline || "—"}</strong></div>
    <div class="detail-row"><span>Race Type</span><strong>${race.raceType || "—"}</strong></div>
    <div class="detail-row"><span>Location</span><strong>${race.locationCity || "—"}, ${race.locationCountry || "—"}</strong></div>
    <div class="detail-row"><span>Organizer</span><strong>${race.organizer || "—"}</strong></div>
    <div class="detail-row"><span>Gender</span><strong>${race.genderDivision || "—"}</strong></div>
    <div class="detail-row"><span>Website</span><strong>${race.officialWebsite || "—"}</strong></div>
    ${streamingHtml}
    ${podcastsHtml}
    ${raceResultsHtml}
    ${stagesHtml}
  `;

  const saveBtn = document.getElementById("saveImageBtn");
  const urlInput = document.getElementById("imageUrlInput");
  const variantBtns = elements.detailCard.querySelectorAll(".variant-btn");
  if (saveBtn && urlInput) {
    saveBtn.addEventListener("click", () => saveRaceImage(race, urlInput));
  }
  variantBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      if (urlInput) {
        urlInput.value = btn.dataset.variantUrl || "";
      }
    });
  });
  renderList();
}

async function saveRaceImage(race, urlInput) {
  const raceId = race?.raceId ?? race?.race_id;
  if (!raceId) {
    showToast("Race has no ID", true);
    return;
  }
  const imageUrl = urlInput?.value?.trim() ?? "";
  const response = await fetch(`/api/races/${raceId}/image`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ imageUrl: imageUrl || null }),
  });
  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    showToast(err.error || "Failed to save image", true);
    return;
  }
  showToast("Image saved");
  await reloadData();
  const updatedRace = state.races.find((r) => (r.raceId ?? r.race_id) === raceId);
  if (updatedRace) selectRace(updatedRace.__index);
}

async function regenerateBootstrap() {
  elements.regenerateBtn.disabled = true;
  elements.regenerateBtn.textContent = "Regenerating...";
  const response = await fetch("/api/bootstrap/regenerate", { method: "POST" });
  elements.regenerateBtn.disabled = false;
  elements.regenerateBtn.textContent = "Regenerate Bootstrap";
  if (!response.ok) {
    showToast("Regenerate failed", true);
    return;
  }
  showToast("Bootstrap regenerated");
  await reloadData();
}

async function refreshSelectedRaceResults() {
  const race = state.selectedRace;
  if (!race) {
    showToast("Select a race first", true);
    return;
  }
  elements.refreshResultsBtn.disabled = true;
  elements.refreshResultsBtn.textContent = "Refreshing Results...";
  const response = await fetch("/api/results/refresh-race", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      raceId: race.raceId ?? race.race_id,
    }),
  });
  elements.refreshResultsBtn.disabled = false;
  elements.refreshResultsBtn.textContent = "Refresh Results";
  if (!response.ok) {
    const err = await response.json().catch(() => ({}));
    showToast(err.error || "Failed to refresh results", true);
    return;
  }
  const data = await response.json();
  await reloadData();
  const selectedId = race.raceId ?? race.race_id;
  const updatedRace = state.races.find((item) => (item.raceId ?? item.race_id) === selectedId);
  if (updatedRace) {
    selectRace(updatedRace.__index);
  }
  showToast(
    `Results refreshed (race: ${data.report?.raceResultsAdded ?? 0}, stages: ${data.report?.stageResultsAdded ?? 0})`
  );
}

async function reloadData() {
  await fetchBootstrap();
  applyFilters();
  await loadHealth();
}

function bindEvents() {
  bindInput(elements.searchInput, applyFilters);
  bindInput(elements.seriesInput, applyFilters);
  bindInput(elements.disciplineInput, applyFilters);
  elements.healthBtn.addEventListener("click", loadHealth);
  elements.previewPodcastsBtn.addEventListener("click", previewPodcasts);
  elements.commitPodcastsBtn.addEventListener("click", commitPodcasts);
  elements.themesBtn.addEventListener("click", () => {
    window.location.href = "/themes";
  });
  elements.refreshResultsBtn.addEventListener("click", refreshSelectedRaceResults);
  elements.regenerateBtn.addEventListener("click", regenerateBootstrap);
  elements.refreshBtn.addEventListener("click", reloadData);
}

async function init() {
  try {
    await reloadData();
    bindEvents();
  } catch (error) {
    showToast(error.message, true);
  }
}

init();
