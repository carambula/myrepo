const toastEl = document.getElementById("toast");
const tokenKey = "mincloud.adminToken";

const toast = (message) => {
  toastEl.textContent = message;
  toastEl.classList.remove("hidden");
  setTimeout(() => toastEl.classList.add("hidden"), 2400);
};

const token = () => localStorage.getItem(tokenKey) || "";

const api = async (path, options = {}) => {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (token()) {
    headers["x-admin-token"] = token();
  }
  const response = await fetch(path, { ...options, headers });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || "Request failed");
  }
  return data;
};

const renderHealth = (data) => {
  document.getElementById("health").innerHTML = [
    `${data.movies} movies`,
    `${data.staleStreaming} stale streaming rows`,
    `${data.podcasts} podcasts`,
    `${data.episodes} episodes`,
    `${data.users} users`
  ].join("   ");
  document.getElementById("jobsBody").innerHTML = (data.jobs || [])
    .map(
      (job) =>
        `<tr><td>${job.name}</td><td>${job.status}</td><td>${new Date(job.started_at).toLocaleString()}</td></tr>`
    )
    .join("");
};

const loadHealth = async () => {
  const data = await api("/v1/admin/health");
  renderHealth(data);
};

document.getElementById("adminToken").value = token();
document.getElementById("saveToken").addEventListener("click", () => {
  localStorage.setItem(tokenKey, document.getElementById("adminToken").value);
  toast("Admin token saved on this device");
  loadHealth().catch((error) => toast(error.message));
});

document.getElementById("refreshHealth").addEventListener("click", () => {
  loadHealth().catch((error) => toast(error.message));
});

document.querySelectorAll("[data-job]").forEach((button) => {
  button.addEventListener("click", async () => {
    try {
      const result = await api(`/v1/admin/jobs/${button.getAttribute("data-job")}`, { method: "POST" });
      toast(result.status === "ok" ? "Job finished" : result.error || "Job ran");
      loadHealth();
    } catch (error) {
      toast(error.message);
    }
  });
});

document.getElementById("movieForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/v1/admin/mov/movies", {
      method: "POST",
      body: JSON.stringify({
        tmdbId: document.getElementById("tmdbId").value,
        title: document.getElementById("movieTitle").value
      })
    });
    toast("Movie saved");
    loadHealth();
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("podcastForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/v1/admin/pod/podcasts", {
      method: "POST",
      body: JSON.stringify({
        itunesId: document.getElementById("itunesId").value,
        feedUrl: document.getElementById("feedUrl").value,
        title: document.getElementById("podcastTitle").value
      })
    });
    toast("Podcast saved");
    loadHealth();
  } catch (error) {
    toast(error.message);
  }
});

if (token()) {
  loadHealth().catch((error) => toast(error.message));
}
