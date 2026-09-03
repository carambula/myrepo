const toastEl = document.getElementById("toast");
const tokenKey = "mincloud.token";

const toast = (message) => {
  toastEl.textContent = message;
  toastEl.classList.remove("hidden");
  setTimeout(() => toastEl.classList.add("hidden"), 2400);
};

const token = () => localStorage.getItem(tokenKey);

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

const posterUrl = (path) =>
  path ? `https://image.tmdb.org/t/p/w342${path}` : "";

const renderMovies = (movies) => {
  const root = document.getElementById("browse-movies");
  root.innerHTML = movies
    .map((movie) => {
      const services = (movie.streamingServices || [])
        .slice(0, 3)
        .map((service) => service.name)
        .join("   ");
      return `
        <article class="card">
          ${movie.posterPath ? `<img class="poster" src="${posterUrl(movie.posterPath)}" alt="" />` : ""}
          <h3>${movie.title}</h3>
          <div class="meta">${[movie.year, (movie.genres || [])[0]].filter(Boolean).join("   ")}</div>
          <p class="meta">${services}</p>
        </article>
      `;
    })
    .join("");
};

const renderPodcasts = (podcasts) => {
  const root = document.getElementById("browse-podcasts");
  root.innerHTML = podcasts
    .map(
      (podcast) => `
        <article class="card">
          ${podcast.artworkUrl600 || podcast.artworkUrl ? `<img class="art" src="${podcast.artworkUrl600 || podcast.artworkUrl}" alt="" />` : ""}
          <h3>${podcast.title}</h3>
          <div class="meta">${[podcast.author, (podcast.categories || [])[0]].filter(Boolean).join("   ")}</div>
        </article>
      `
    )
    .join("");
};

const refreshAuth = async () => {
  const signedOut = document.getElementById("signedOut");
  const signedIn = document.getElementById("signedIn");
  if (!token()) {
    signedOut.classList.remove("hidden");
    signedIn.classList.add("hidden");
    return;
  }
  try {
    const { user } = await api("/v1/me");
    signedOut.classList.add("hidden");
    signedIn.classList.remove("hidden");
    document.getElementById("accountSummary").innerHTML = `
      <strong>${user.displayName}</strong>
      <div class="meta">@${user.handle}   ${user.email}</div>
    `;
    const feed = await api("/v1/social/feed");
    document.getElementById("socialFeed").innerHTML = (feed.items || [])
      .map(
        (item) =>
          `<div class="row"><div><strong>${item.display_name}</strong><div class="meta">${item.type}   ${item.app}</div></div><div class="meta">${new Date(item.created_at).toLocaleDateString()}</div></div>`
      )
      .join("") || `<p class="meta">No activity yet. Follow someone to fill this feed.</p>`;
  } catch {
    localStorage.removeItem(tokenKey);
    signedOut.classList.remove("hidden");
    signedIn.classList.add("hidden");
  }
};

document.querySelectorAll("[data-tab]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-tab]").forEach((el) => el.classList.remove("is-active"));
    button.classList.add("is-active");
    const tab = button.getAttribute("data-tab");
    document.getElementById("browse-movies").classList.toggle("hidden", tab !== "movies");
    document.getElementById("browse-podcasts").classList.toggle("hidden", tab !== "podcasts");
  });
});

document.getElementById("authForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const body = {
      email: document.getElementById("email").value,
      password: document.getElementById("password").value
    };
    const data = await api("/v1/auth/login", { method: "POST", body: JSON.stringify(body) });
    localStorage.setItem(tokenKey, data.session.token);
    toast("Signed in");
    refreshAuth();
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("registerBtn").addEventListener("click", async () => {
  try {
    const body = {
      email: document.getElementById("email").value,
      password: document.getElementById("password").value,
      displayName: document.getElementById("displayName").value
    };
    const data = await api("/v1/auth/register", { method: "POST", body: JSON.stringify(body) });
    localStorage.setItem(tokenKey, data.session.token);
    toast("Account created");
    refreshAuth();
  } catch (error) {
    toast(error.message);
  }
});

document.getElementById("logoutBtn").addEventListener("click", async () => {
  try {
    await api("/v1/auth/logout", { method: "POST" });
  } catch {
    // ignore
  }
  localStorage.removeItem(tokenKey);
  refreshAuth();
});

document.getElementById("followForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/v1/social/follow", {
      method: "POST",
      body: JSON.stringify({ handle: document.getElementById("followHandle").value })
    });
    toast("Followed");
    refreshAuth();
  } catch (error) {
    toast(error.message);
  }
});

const boot = async () => {
  try {
    const [movies, podcasts] = await Promise.all([api("/v1/mov/catalog?limit=12"), api("/v1/pod/catalog")]);
    renderMovies(movies.movies || []);
    renderPodcasts(podcasts.podcasts || []);
  } catch (error) {
    toast(error.message);
  }
  refreshAuth();
};

boot();
