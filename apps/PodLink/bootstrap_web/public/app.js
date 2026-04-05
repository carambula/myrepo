const state = {
  catalog: null,
  selectedPodcast: null,
  selectedCategory: null,
  themes: [],
};

const el = {
  searchInput: document.getElementById("searchInput"),
  categoryFilter: document.getElementById("categoryFilter"),
  catalogBody: document.getElementById("catalogBody"),
  podcastCount: document.getElementById("podcastCount"),
  detailEmpty: document.getElementById("detailEmpty"),
  detailCard: document.getElementById("detailCard"),
  enrichBtn: document.getElementById("enrichBtn"),
  themesBtn: document.getElementById("themesBtn"),
  healthBtn: document.getElementById("healthBtn"),
  refreshBtn: document.getElementById("refreshBtn"),
  addCategoryBtn: document.getElementById("addCategoryBtn"),
  addPodcastBtn: document.getElementById("addPodcastBtn"),
  modalOverlay: document.getElementById("modalOverlay"),
  modalContent: document.getElementById("modalContent"),
  toast: document.getElementById("toast"),
};

function showToast(msg, isError = false) {
  el.toast.textContent = msg;
  el.toast.classList.toggle("error", isError);
  el.toast.classList.remove("hidden");
  setTimeout(() => el.toast.classList.add("hidden"), 2800);
}

function closeModal() { el.modalOverlay.classList.add("hidden"); }
function openModal(html) { el.modalContent.innerHTML = html; el.modalOverlay.classList.remove("hidden"); }

el.modalOverlay.addEventListener("click", (e) => { if (e.target === el.modalOverlay) closeModal(); });

async function api(path, opts = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  return res.json();
}

// ---- Data Loading ----

async function loadCatalog() {
  state.catalog = await api("/api/bootstrap");
  renderCatalog();
  updateCategoryFilter();
}

function updateCategoryFilter() {
  const categories = (state.catalog?.categories || []).map((c) => c.name);
  el.categoryFilter.innerHTML = '<option value="all">All Categories</option>' +
    categories.map((c) => `<option value="${c}">${c}</option>`).join("");
}

function getFilteredCategories() {
  const search = (el.searchInput.value || "").toLowerCase();
  const catFilter = el.categoryFilter.value;
  return (state.catalog?.categories || [])
    .filter((c) => catFilter === "all" || c.name === catFilter)
    .map((c) => ({
      ...c,
      podcasts: (c.podcasts || []).filter((p) =>
        !search || p.name.toLowerCase().includes(search) || (p.artist || "").toLowerCase().includes(search)
      ),
    }))
    .filter((c) => !search || c.podcasts.length > 0);
}

// ---- Rendering ----

function renderCatalog() {
  const categories = getFilteredCategories();
  const total = categories.reduce((sum, c) => sum + c.podcasts.length, 0);
  el.podcastCount.textContent = `(${total})`;

  if (categories.length === 0) {
    el.catalogBody.innerHTML = '<div class="empty-state">No podcasts found</div>';
    return;
  }

  el.catalogBody.innerHTML = categories.map((cat) => `
    <div class="category-group">
      <div class="category-header" data-category="${cat.name}">
        <span class="category-name">${cat.name}</span>
        <span class="category-count">${cat.podcasts.length} podcasts</span>
      </div>
      ${cat.podcasts.map((p) => `
        <div class="podcast-row${state.selectedPodcast?.itunesID === p.itunesID && state.selectedCategory === cat.name ? " selected" : ""}"
             data-itunes-id="${p.itunesID || ""}" data-category="${cat.name}">
          ${p.artworkUrl ? `<img class="podcast-art" src="${p.artworkUrl}" alt="" />` : '<div class="podcast-art"></div>'}
          <div class="podcast-info">
            <div class="podcast-name">${p.name}</div>
            ${p.artist ? `<div class="podcast-artist">${p.artist}</div>` : ""}
          </div>
          <div class="podcast-id">${p.itunesID || "—"}</div>
        </div>
      `).join("")}
    </div>
  `).join("");

  el.catalogBody.querySelectorAll(".podcast-row").forEach((row) => {
    row.addEventListener("click", () => selectPodcast(row.dataset.category, row.dataset.itunesId));
  });
}

async function selectPodcast(categoryName, itunesID) {
  const cat = (state.catalog?.categories || []).find((c) => c.name === categoryName);
  if (!cat) return;
  const podcast = (cat.podcasts || []).find((p) => p.itunesID === itunesID);
  if (!podcast) return;
  state.selectedPodcast = podcast;
  state.selectedCategory = categoryName;
  renderCatalog();
  renderDetail(podcast, categoryName);
}

async function renderDetail(podcast, categoryName) {
  el.detailEmpty.style.display = "none";
  el.detailCard.classList.add("visible");

  let feedHtml = "";
  try {
    if (podcast.itunesID) {
      const feed = await api("/api/feeds/preview", { method: "POST", body: { itunesID: podcast.itunesID } });
      if (feed.episodes?.length) {
        feedHtml = `
          <div class="episode-list">
            <h3>Recent Episodes (${feed.episodes.length})</h3>
            ${feed.episodes.map((ep) => `
              <div class="episode-row">
                <div class="episode-title">${ep.title}</div>
                <div class="episode-date">${ep.pubDate || "—"}${ep.duration ? ` · ${ep.duration}` : ""}</div>
              </div>
            `).join("")}
          </div>
        `;
      }
    }
  } catch {}

  el.detailCard.innerHTML = `
    <div class="detail-hero">
      ${podcast.artworkUrl ? `<img class="detail-artwork" src="${podcast.artworkUrl}" alt="" />` : '<div class="detail-artwork"></div>'}
      <div class="detail-meta">
        <div class="detail-title">${podcast.name}</div>
        <div class="detail-artist">${podcast.artist || "Unknown artist"}</div>
        <div style="font-size:12px;color:#6b7280;margin-top:4px">Category: ${categoryName}</div>
        <div style="font-size:12px;color:#6b7280">iTunes ID: ${podcast.itunesID || "—"}</div>
        ${podcast.feedUrl ? `<div style="font-size:11px;color:#4b5563;margin-top:4px;word-break:break-all">Feed: ${podcast.feedUrl}</div>` : ""}
      </div>
    </div>
    <div class="detail-actions">
      <button onclick="removePodcast('${categoryName}', '${podcast.itunesID}')" class="danger">Remove</button>
      ${podcast.itunesID ? `<button onclick="lookupPodcast('${podcast.itunesID}')">Refresh from iTunes</button>` : ""}
      ${podcast.itunesID ? `<button onclick="previewFeed('${podcast.itunesID}')">Preview Feed</button>` : ""}
    </div>
    ${feedHtml}
  `;
}

// ---- Actions ----

async function removePodcast(category, itunesID) {
  if (!confirm(`Remove this podcast from "${category}"?`)) return;
  const result = await api("/api/podcasts", { method: "DELETE", body: { category, itunesID } });
  if (result.success) { showToast("Podcast removed"); state.selectedPodcast = null; el.detailCard.classList.remove("visible"); el.detailEmpty.style.display = ""; await loadCatalog(); }
  else showToast(result.error || "Failed", true);
}
window.removePodcast = removePodcast;

async function lookupPodcast(itunesID) {
  const info = await api(`/api/itunes/lookup?id=${itunesID}`);
  if (info.error) { showToast(info.error, true); return; }
  openModal(`
    <h2>iTunes Lookup: ${info.name}</h2>
    <div style="display:flex;gap:12px;margin-bottom:16px">
      ${info.artworkUrl ? `<img src="${info.artworkUrl}" style="width:80px;height:80px;border-radius:8px" />` : ""}
      <div>
        <div style="font-weight:600">${info.name}</div>
        <div style="font-size:13px;color:#9aa0ab">${info.artist || ""}</div>
        <div style="font-size:11px;color:#6b7280;margin-top:4px">${(info.genres || []).join(", ")}</div>
      </div>
    </div>
    <div class="modal-actions">
      <button onclick="closeModal()">Close</button>
    </div>
  `);
}
window.lookupPodcast = lookupPodcast;
window.closeModal = closeModal;

async function previewFeed(itunesID) {
  showToast("Loading feed...");
  const feed = await api("/api/feeds/preview", { method: "POST", body: { itunesID } });
  if (feed.error) { showToast(feed.error, true); return; }
  openModal(`
    <h2>${feed.meta?.title || "Feed Preview"}</h2>
    ${feed.meta?.artworkUrl ? `<img src="${feed.meta.artworkUrl}" style="width:60px;height:60px;border-radius:8px;margin-bottom:12px" />` : ""}
    <p style="font-size:13px;color:#9aa0ab;margin-bottom:16px">${feed.meta?.description || ""}</p>
    <div style="font-size:11px;color:#6b7280;margin-bottom:12px">${feed.episodes?.length || 0} episodes loaded</div>
    ${(feed.episodes || []).map((ep) => `
      <div style="padding:6px 0;border-bottom:1px solid #222631">
        <div style="font-size:13px;font-weight:500">${ep.title}</div>
        <div style="font-size:11px;color:#6b7280">${ep.pubDate || "—"}${ep.duration ? ` · ${ep.duration}` : ""}</div>
      </div>
    `).join("")}
    <div class="modal-actions"><button onclick="closeModal()">Close</button></div>
  `);
}
window.previewFeed = previewFeed;

// ---- Add Category ----

el.addCategoryBtn.addEventListener("click", () => {
  openModal(`
    <h2>Add Category</h2>
    <div class="detail-field"><label>Name<input id="newCategoryName" type="text" placeholder="e.g. History" /></label></div>
    <div class="modal-actions">
      <button onclick="closeModal()">Cancel</button>
      <button class="primary" onclick="submitNewCategory()">Add</button>
    </div>
  `);
});

window.submitNewCategory = async function () {
  const name = document.getElementById("newCategoryName")?.value?.trim();
  if (!name) return;
  const result = await api("/api/categories", { method: "POST", body: { name } });
  if (result.success) { showToast("Category added"); closeModal(); await loadCatalog(); }
  else showToast(result.error || "Failed", true);
};

// ---- Add Podcast (iTunes Search) ----

el.addPodcastBtn.addEventListener("click", () => {
  openModal(`
    <h2>Add Podcast</h2>
    <div class="detail-field">
      <label>Search iTunes<input id="itunesSearchInput" type="search" placeholder="Search for a podcast..." /></label>
    </div>
    <div class="detail-field">
      <label>Add to Category
        <select id="addToCategorySelect">
          ${(state.catalog?.categories || []).map((c) => `<option value="${c.name}">${c.name}</option>`).join("")}
        </select>
      </label>
    </div>
    <button onclick="runItunesSearch()" class="primary" style="margin-bottom:16px">Search</button>
    <div id="itunesResults"></div>
    <div class="modal-actions"><button onclick="closeModal()">Cancel</button></div>
  `);
});

window.runItunesSearch = async function () {
  const term = document.getElementById("itunesSearchInput")?.value?.trim();
  if (!term) return;
  const data = await api(`/api/itunes/search?term=${encodeURIComponent(term)}`);
  const container = document.getElementById("itunesResults");
  if (!data.results?.length) { container.innerHTML = '<div style="color:#6b7280;padding:12px">No results found</div>'; return; }
  container.innerHTML = data.results.map((r) => `
    <div class="search-result" onclick="addFromSearch('${r.itunesID}', ${JSON.stringify(r.name).replace(/'/g, "\\'")})">
      ${r.artworkUrl ? `<img class="search-result-art" src="${r.artworkUrl}" />` : '<div class="search-result-art"></div>'}
      <div class="search-result-info">
        <div class="search-result-name">${r.name}</div>
        <div class="search-result-artist">${r.artist || ""}</div>
      </div>
    </div>
  `).join("");
};

window.addFromSearch = async function (itunesID, name) {
  const category = document.getElementById("addToCategorySelect")?.value;
  if (!category) { showToast("Select a category", true); return; }
  const result = await api("/api/podcasts", { method: "POST", body: { category, itunesID, name } });
  if (result.success) { showToast(`Added "${name}" to ${category}`); closeModal(); await loadCatalog(); }
  else showToast(result.error || "Failed", true);
};

// ---- Health ----

el.healthBtn.addEventListener("click", async () => {
  const health = await api("/api/health");
  openModal(`
    <h2>Data Health</h2>
    <div class="health-grid">
      <div class="health-card"><div class="health-value">${health.totalCategories}</div><div class="health-label">Categories</div></div>
      <div class="health-card"><div class="health-value">${health.totalPodcasts}</div><div class="health-label">Total Podcasts</div></div>
      <div class="health-card"><div class="health-value">${health.podcastsWithItunesId}</div><div class="health-label">With iTunes ID</div></div>
      <div class="health-card"><div class="health-value">${health.podcastsMissingId}</div><div class="health-label">Missing ID</div></div>
      <div class="health-card"><div class="health-value">${health.emptyCategories}</div><div class="health-label">Empty Categories</div></div>
      <div class="health-card"><div class="health-value">${health.mediaPatternTypes}</div><div class="health-label">Media Pattern Types</div></div>
    </div>
    <div class="modal-actions"><button onclick="closeModal()">Close</button></div>
  `);
});

// ---- Enrich ----

el.enrichBtn.addEventListener("click", async () => {
  if (!confirm("Enrich all podcasts with iTunes metadata? This may take a moment.")) return;
  showToast("Enriching...");
  const result = await api("/api/podcasts/enrich", { method: "POST" });
  if (result.success) { showToast(`Enriched ${result.enriched} podcasts (${result.failed} failed)`); await loadCatalog(); }
  else showToast(result.error || "Failed", true);
});

// ---- Themes ----

el.themesBtn.addEventListener("click", async () => {
  const data = await api("/api/themes");
  const themes = data.themes || [];
  openModal(`
    <h2>Theme Presets (${themes.length})</h2>
    ${themes.length === 0 ? '<div style="color:#6b7280;padding:12px">No theme presets yet</div>' :
      themes.map((t) => `
        <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #222631">
          <div>
            <div style="font-weight:500">${t.name}</div>
            <div style="font-size:11px;color:#6b7280">${t.headlineFontStyle} · ${t.supportsLightMode ? "Light+Dark" : "Dark only"}</div>
          </div>
          <button onclick="deleteTheme('${t.id}')" style="font-size:11px" class="danger">Delete</button>
        </div>
      `).join("")}
    <div class="modal-actions"><button onclick="closeModal()">Close</button></div>
  `);
});

window.deleteTheme = async function (id) {
  if (!confirm("Delete this theme?")) return;
  await api(`/api/themes/${id}`, { method: "DELETE" });
  showToast("Theme deleted");
  el.themesBtn.click();
};

// ---- Refresh ----

el.refreshBtn.addEventListener("click", loadCatalog);

// ---- Filter listeners ----

el.searchInput.addEventListener("input", renderCatalog);
el.categoryFilter.addEventListener("change", renderCatalog);

// ---- SSE ----

function connectSSE() {
  const evtSource = new EventSource("/api/live/changes");
  evtSource.addEventListener("file-change", (e) => {
    const data = JSON.parse(e.data);
    showToast(`${data.file} changed — reloading`);
    setTimeout(loadCatalog, 500);
  });
  evtSource.onerror = () => { evtSource.close(); setTimeout(connectSSE, 5000); };
}
connectSSE();

// ---- Init ----

loadCatalog();
