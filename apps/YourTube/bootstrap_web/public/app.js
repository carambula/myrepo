const state = {
  bootstrap: null,
  channels: [],
  selectedChannelID: null,
};

const el = {
  searchInput: document.getElementById("searchInput"),
  categoryFilter: document.getElementById("categoryFilter"),
  channelListBody: document.getElementById("channelListBody"),
  channelCount: document.getElementById("channelCount"),
  detailEmpty: document.getElementById("detailEmpty"),
  detailCard: document.getElementById("detailCard"),
  enrichBtn: document.getElementById("enrichBtn"),
  themesBtn: document.getElementById("themesBtn"),
  healthBtn: document.getElementById("healthBtn"),
  refreshBtn: document.getElementById("refreshBtn"),
  addCategoryBtn: document.getElementById("addCategoryBtn"),
  addChannelBtn: document.getElementById("addChannelBtn"),
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
window.closeModal = closeModal;

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

async function loadBootstrap() {
  state.bootstrap = await api("/api/bootstrap");
  state.channels = state.bootstrap.channels || [];
  renderChannels();
  updateCategoryFilter();
}

function updateCategoryFilter() {
  const categories = (state.bootstrap?.categories || []).map((c) => c.name);
  el.categoryFilter.innerHTML = '<option value="all">All Categories</option>' +
    categories.map((c) => `<option value="${c}">${c}</option>`).join("");
}

function getFilteredChannels() {
  const search = (el.searchInput.value || "").toLowerCase();
  const catFilter = el.categoryFilter.value;
  return state.channels.filter((ch) => {
    if (catFilter !== "all" && ch.category !== catFilter) return false;
    if (search && !ch.title.toLowerCase().includes(search) && !(ch.description || "").toLowerCase().includes(search)) return false;
    return true;
  });
}

// ---- Rendering ----

function renderChannels() {
  const filtered = getFilteredChannels();
  el.channelCount.textContent = `(${filtered.length})`;

  if (filtered.length === 0) {
    el.channelListBody.innerHTML = '<div class="empty-state">No channels found. Add one with + Channel.</div>';
    return;
  }

  const grouped = new Map();
  for (const ch of filtered) {
    const cat = ch.category || "Uncategorized";
    if (!grouped.has(cat)) grouped.set(cat, []);
    grouped.get(cat).push(ch);
  }

  let html = "";
  for (const [cat, channels] of grouped) {
    html += `<div class="category-group-header">${cat}</div>`;
    for (const ch of channels) {
      html += `
        <div class="channel-row${state.selectedChannelID === ch.channelID ? " selected" : ""}" data-channel-id="${ch.channelID}">
          ${ch.thumbnailURL ? `<img class="channel-thumb" src="${ch.thumbnailURL}" alt="" />` : '<div class="channel-thumb"></div>'}
          <div class="channel-info">
            <div class="channel-title">${ch.title}</div>
            <div class="channel-desc">${ch.description || ""}</div>
          </div>
          ${ch.subscriberCount ? `<div class="channel-cat">${formatCount(ch.subscriberCount)} subs</div>` : ""}
        </div>
      `;
    }
  }

  el.channelListBody.innerHTML = html;
  el.channelListBody.querySelectorAll(".channel-row").forEach((row) => {
    row.addEventListener("click", () => selectChannel(row.dataset.channelId));
  });
}

function formatCount(n) {
  const num = Number(n);
  if (num >= 1e6) return (num / 1e6).toFixed(1) + "M";
  if (num >= 1e3) return (num / 1e3).toFixed(1) + "K";
  return String(num);
}

async function selectChannel(channelID) {
  state.selectedChannelID = channelID;
  renderChannels();
  const ch = state.channels.find((c) => c.channelID === channelID);
  if (!ch) return;
  renderDetail(ch);
}

async function renderDetail(ch) {
  el.detailEmpty.style.display = "none";
  el.detailCard.classList.add("visible");

  const categories = (state.bootstrap?.categories || []).map((c) => c.name);
  let videosHtml = "";
  try {
    const data = await api(`/api/youtube/videos?channelId=${ch.channelID}`);
    if (data.videos?.length) {
      videosHtml = `
        <div class="video-list">
          <h3>Recent Videos (${data.videos.length})</h3>
          ${data.videos.map((v) => `
            <div class="video-row">
              ${v.thumbnailURL ? `<img class="video-thumb" src="${v.thumbnailURL}" alt="" />` : '<div class="video-thumb"></div>'}
              <div class="video-info">
                <div class="video-title">${v.title}</div>
                <div class="video-date">${v.publishedAt ? new Date(v.publishedAt).toLocaleDateString() : "—"}</div>
              </div>
            </div>
          `).join("")}
        </div>
      `;
    }
  } catch {}

  el.detailCard.innerHTML = `
    <div class="detail-hero">
      ${ch.thumbnailURL ? `<img class="detail-thumb" src="${ch.thumbnailURL}" alt="" />` : '<div class="detail-thumb"></div>'}
      <div class="detail-meta">
        <div class="detail-title">${ch.title}</div>
        <div class="detail-desc">${ch.description || ""}</div>
        <div class="detail-stats">
          ${ch.subscriberCount ? `${formatCount(ch.subscriberCount)} subscribers · ` : ""}
          ${ch.videoCount ? `${formatCount(ch.videoCount)} videos` : ""}
        </div>
        <div style="font-size:11px;color:#4b5563;margin-top:4px">ID: ${ch.channelID}</div>
      </div>
    </div>
    <div class="detail-field">
      <label>Category
        <select id="channelCategorySelect">
          <option value="">Uncategorized</option>
          ${categories.map((c) => `<option value="${c}"${ch.category === c ? " selected" : ""}>${c}</option>`).join("")}
        </select>
      </label>
    </div>
    <div class="detail-actions">
      <button onclick="updateChannelCategory()" class="secondary">Save Category</button>
      <button onclick="refreshChannelFromYT('${ch.channelID}')">Refresh from YouTube</button>
      <button onclick="removeChannel('${ch.channelID}')" class="danger">Remove</button>
    </div>
    ${videosHtml}
  `;
}

// ---- Actions ----

window.updateChannelCategory = async function () {
  const category = document.getElementById("channelCategorySelect")?.value || null;
  const result = await api(`/api/channels/${state.selectedChannelID}`, { method: "PUT", body: { category } });
  if (result.success) { showToast("Category updated"); await loadBootstrap(); selectChannel(state.selectedChannelID); }
  else showToast(result.error || "Failed", true);
};

window.refreshChannelFromYT = async function (channelID) {
  showToast("Fetching from YouTube...");
  const details = await api(`/api/youtube/channel?id=${channelID}`);
  if (details.error) { showToast(details.error, true); return; }
  const result = await api(`/api/channels/${channelID}`, { method: "PUT", body: details });
  if (result.success) { showToast("Channel refreshed"); await loadBootstrap(); selectChannel(channelID); }
  else showToast(result.error || "Failed", true);
};

window.removeChannel = async function (channelID) {
  if (!confirm("Remove this channel?")) return;
  const result = await api(`/api/channels/${channelID}`, { method: "DELETE" });
  if (result.success) { showToast("Channel removed"); state.selectedChannelID = null; el.detailCard.classList.remove("visible"); el.detailEmpty.style.display = ""; await loadBootstrap(); }
  else showToast(result.error || "Failed", true);
};

// ---- Add Category ----

el.addCategoryBtn.addEventListener("click", () => {
  openModal(`
    <h2>Add Category</h2>
    <div class="detail-field"><label>Name<input id="newCategoryName" type="text" placeholder="e.g. Gaming" /></label></div>
    <div class="modal-actions">
      <button onclick="closeModal()">Cancel</button>
      <button class="secondary" onclick="submitNewCategory()">Add</button>
    </div>
  `);
});

window.submitNewCategory = async function () {
  const name = document.getElementById("newCategoryName")?.value?.trim();
  if (!name) return;
  const result = await api("/api/categories", { method: "POST", body: { name } });
  if (result.success) { showToast("Category added"); closeModal(); await loadBootstrap(); }
  else showToast(result.error || "Failed", true);
};

// ---- Add Channel (YouTube Search) ----

el.addChannelBtn.addEventListener("click", () => {
  openModal(`
    <h2>Add Channel</h2>
    <div class="detail-field">
      <label>Search YouTube<input id="ytSearchInput" type="search" placeholder="Search for a channel..." /></label>
    </div>
    <div class="detail-field">
      <label>Add to Category
        <select id="addToCategorySelect">
          <option value="">Uncategorized</option>
          ${(state.bootstrap?.categories || []).map((c) => `<option value="${c.name}">${c.name}</option>`).join("")}
        </select>
      </label>
    </div>
    <div style="display:flex;gap:8px;margin-bottom:12px">
      <button onclick="runYTSearch()" class="secondary">Search</button>
      <span style="font-size:11px;color:#6b7280;align-self:center">or paste Channel ID below</span>
    </div>
    <div class="detail-field">
      <label>Channel ID (manual)<input id="manualChannelID" type="text" placeholder="UCxxxxxxxx" /></label>
    </div>
    <button onclick="addManualChannel()" style="margin-bottom:16px">Add by ID</button>
    <div id="ytResults"></div>
    <div class="modal-actions"><button onclick="closeModal()">Cancel</button></div>
  `);
});

window.runYTSearch = async function () {
  const query = document.getElementById("ytSearchInput")?.value?.trim();
  if (!query) return;
  showToast("Searching YouTube...");
  const data = await api(`/api/youtube/search?q=${encodeURIComponent(query)}`);
  const container = document.getElementById("ytResults");
  if (data.error) { container.innerHTML = `<div style="color:#dc3545;padding:12px">${data.error}</div>`; return; }
  if (!data.results?.length) { container.innerHTML = '<div style="color:#6b7280;padding:12px">No results found</div>'; return; }
  container.innerHTML = data.results.map((r) => `
    <div class="search-result" onclick="addFromSearch('${r.channelID}', ${JSON.stringify(r.title).replace(/'/g, "\\'")})">
      ${r.thumbnailURL ? `<img class="search-result-thumb" src="${r.thumbnailURL}" />` : '<div class="search-result-thumb"></div>'}
      <div class="search-result-info">
        <div class="search-result-name">${r.title}</div>
        <div class="search-result-desc">${r.description || ""}</div>
      </div>
    </div>
  `).join("");
};

window.addFromSearch = async function (channelID, title) {
  const category = document.getElementById("addToCategorySelect")?.value || null;
  const result = await api("/api/channels", { method: "POST", body: { channelID, title, category } });
  if (result.success) { showToast(`Added "${title}"`); closeModal(); await loadBootstrap(); }
  else showToast(result.error || "Failed", true);
};

window.addManualChannel = async function () {
  const channelID = document.getElementById("manualChannelID")?.value?.trim();
  if (!channelID) return;
  const category = document.getElementById("addToCategorySelect")?.value || null;
  let title = channelID;
  try {
    const details = await api(`/api/youtube/channel?id=${channelID}`);
    if (details.title) title = details.title;
    const result = await api("/api/channels", { method: "POST", body: { ...details, category } });
    if (result.success) { showToast(`Added "${title}"`); closeModal(); await loadBootstrap(); }
    else showToast(result.error || "Failed", true);
  } catch {
    const result = await api("/api/channels", { method: "POST", body: { channelID, title, category } });
    if (result.success) { showToast(`Added "${channelID}"`); closeModal(); await loadBootstrap(); }
    else showToast(result.error || "Failed", true);
  }
};

// ---- Health ----

el.healthBtn.addEventListener("click", async () => {
  const health = await api("/api/health");
  openModal(`
    <h2>Data Health</h2>
    <div class="health-grid">
      <div class="health-card"><div class="health-value">${health.totalChannels}</div><div class="health-label">Total Channels</div></div>
      <div class="health-card"><div class="health-value">${health.totalCategories}</div><div class="health-label">Categories</div></div>
      <div class="health-card"><div class="health-value">${health.channelsWithThumbnail}</div><div class="health-label">With Thumbnail</div></div>
      <div class="health-card"><div class="health-value">${health.channelsWithDescription}</div><div class="health-label">With Description</div></div>
      <div class="health-card"><div class="health-value">${health.categorizedChannels}</div><div class="health-label">Categorized</div></div>
      <div class="health-card"><div class="health-value">${health.uncategorizedChannels}</div><div class="health-label">Uncategorized</div></div>
    </div>
    <div style="padding:16px;font-size:13px;color:${health.hasYouTubeApiKey ? "#22c55e" : "#dc3545"}">
      YouTube API Key: ${health.hasYouTubeApiKey ? "✓ Configured" : "✗ Not set (set YOUTUBE_API_KEY env var)"}
    </div>
    <div class="modal-actions"><button onclick="closeModal()">Close</button></div>
  `);
});

// ---- Enrich ----

el.enrichBtn.addEventListener("click", async () => {
  if (!confirm("Enrich all channels with YouTube API metadata? This may take a moment.")) return;
  showToast("Enriching...");
  const result = await api("/api/channels/enrich", { method: "POST" });
  if (result.success) { showToast(`Enriched ${result.enriched} channels (${result.failed} failed)`); await loadBootstrap(); }
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

el.refreshBtn.addEventListener("click", loadBootstrap);

// ---- Filter listeners ----

el.searchInput.addEventListener("input", renderChannels);
el.categoryFilter.addEventListener("change", renderChannels);

// ---- SSE ----

function connectSSE() {
  const evtSource = new EventSource("/api/live/changes");
  evtSource.addEventListener("file-change", (e) => {
    const data = JSON.parse(e.data);
    showToast(`${data.file} changed — reloading`);
    setTimeout(loadBootstrap, 500);
  });
  evtSource.onerror = () => { evtSource.close(); setTimeout(connectSSE, 5000); };
}
connectSSE();

// ---- Init ----

loadBootstrap();
