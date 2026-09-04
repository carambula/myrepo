const toastEl = document.getElementById("toast");
const tokenKey = "mincloud.token";
const deviceKey = "mincloud.deviceId";
const metadataSeparator = "   ";

const escapeHtml = (value) =>
  String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

const toast = (message) => {
  toastEl.textContent = message;
  toastEl.classList.remove("hidden");
  setTimeout(() => toastEl.classList.add("hidden"), 2400);
};

const token = () => localStorage.getItem(tokenKey);

const deviceId = () => {
  const existing = localStorage.getItem(deviceKey);
  if (existing) {
    return existing;
  }
  const created =
    typeof crypto !== "undefined" && crypto.randomUUID
      ? crypto.randomUUID()
      : `web-${Date.now()}`;
  localStorage.setItem(deviceKey, created);
  return created;
};

const api = async (path, options = {}) => {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (token()) {
    headers.Authorization = `Bearer ${token()}`;
  }
  const response = await fetch(path, { ...options, headers });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || "Request failed");
  }
  return data;
};

const statusTitle = (status) =>
  ({
    open: "Open",
    planned: "Planned",
    in_progress: "In progress",
    shipped: "Shipped",
    closed: "Closed",
    hidden: "Hidden"
  })[status] || status;

const state = {
  app: "mov",
  kind: "idea"
};

const params = new URLSearchParams(window.location.search);
if (["mov", "pod", "vid", "cyc", "spin", "fit"].includes(params.get("app"))) {
  state.app = params.get("app");
}
if (["idea", "bug"].includes(params.get("kind"))) {
  state.kind = params.get("kind");
}

const appFilter = document.getElementById("appFilter");
appFilter.value = state.app;

const render = (items) => {
  const root = document.getElementById("board");
  if (!items.length) {
    root.innerHTML = `<p class="meta">${state.kind === "idea" ? "No ideas yet. Add the first one." : "No bugs reported yet."}</p>`;
    return;
  }
  root.innerHTML = items
    .map((item) => {
      const votes = item.voteCount === 1 ? "1 vote" : `${item.voteCount} votes`;
      const meta = [statusTitle(item.status), votes, item.authorHandle ? `@${item.authorHandle}` : ""]
        .filter(Boolean)
        .join(metadataSeparator);
      return `
        <article class="card feedback-item">
          <button class="vote-button ${item.voted ? "is-voted" : ""}" data-vote="${item.id}" aria-label="${item.voted ? "Remove vote" : "Vote"}">
            <span>▲</span>
            <strong>${item.voteCount}</strong>
          </button>
          <div>
            <h3>${escapeHtml(item.title)}</h3>
            <div class="meta">${escapeHtml(meta)}</div>
          </div>
        </article>
      `;
    })
    .join("");
};

const load = async () => {
  const query = new URLSearchParams({
    app: state.app,
    kind: state.kind,
    deviceId: deviceId()
  });
  const data = await api(`/v1/feedback?${query}`);
  render(data.items || []);
};

document.querySelectorAll("[data-kind]").forEach((button) => {
  button.classList.toggle("is-active", button.getAttribute("data-kind") === state.kind);
  button.addEventListener("click", () => {
    state.kind = button.getAttribute("data-kind");
    document.querySelectorAll("[data-kind]").forEach((other) => {
      other.classList.toggle("is-active", other === button);
    });
    document.getElementById("composeTitle").textContent = state.kind === "idea" ? "New idea" : "New bug";
    document.getElementById("title").placeholder =
      state.kind === "idea" ? "What should we add?" : "What went wrong?";
    load().catch((error) => toast(error.message));
  });
});

appFilter.addEventListener("change", () => {
  state.app = appFilter.value;
  const url = new URL(window.location.href);
  url.searchParams.set("app", state.app);
  window.history.replaceState({}, "", url);
  load().catch((error) => toast(error.message));
});

document.getElementById("board").addEventListener("click", async (event) => {
  const button = event.target.closest("[data-vote]");
  if (!button) {
    return;
  }
  try {
    await api(`/v1/feedback/${button.getAttribute("data-vote")}/vote`, {
      method: "POST",
      body: JSON.stringify({ deviceId: deviceId() })
    });
    await load();
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("composeForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/v1/feedback", {
      method: "POST",
      body: JSON.stringify({
        app: state.app,
        kind: state.kind,
        title: document.getElementById("title").value,
        body: document.getElementById("body").value,
        deviceId: deviceId(),
        context: { platform: "web" }
      })
    });
    document.getElementById("title").value = "";
    document.getElementById("body").value = "";
    toast("Submitted");
    await load();
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("composeTitle").textContent = state.kind === "idea" ? "New idea" : "New bug";
load().catch((error) => toast(error.message));
