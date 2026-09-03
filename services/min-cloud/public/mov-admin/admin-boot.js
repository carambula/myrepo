(() => {
  const tokenKey = "mincloud.adminToken";

  const token = () => localStorage.getItem(tokenKey) || "";

  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init = {}) => {
    const headers = new Headers(init.headers || (input instanceof Request ? input.headers : undefined));
    if (token()) {
      headers.set("x-admin-token", token());
    }
    return originalFetch(input, { ...init, headers });
  };

  const originalEventSource = window.EventSource;
  window.EventSource = function EventSourceWithToken(url, config) {
    try {
      const parsed = new URL(url, window.location.origin);
      if (token() && !parsed.searchParams.get("adminToken")) {
        parsed.searchParams.set("adminToken", token());
      }
      return new originalEventSource(parsed.toString(), config);
    } catch {
      return new originalEventSource(url, config);
    }
  };
  window.EventSource.prototype = originalEventSource.prototype;

  const ensureGate = () => {
    if (document.getElementById("adminTokenGate")) {
      return;
    }
    const gate = document.createElement("div");
    gate.id = "adminTokenGate";
    gate.innerHTML = `
      <div class="admin-token-card">
        <h2>Min Cloud Admin</h2>
        <p>Paste the admin token to manage the live mov min catalog. This is the WatchedIt database editor, pointed at Postgres.</p>
        <label>Admin token<input id="adminTokenInput" type="password" autocomplete="off" /></label>
        <button id="adminTokenSave" class="primary" type="button">Open catalog</button>
        <div id="adminTokenError" class="status-text"></div>
      </div>
    `;
    document.body.prepend(gate);
    const input = document.getElementById("adminTokenInput");
    input.value = token();
    document.getElementById("adminTokenSave").addEventListener("click", async () => {
      const value = input.value.trim();
      localStorage.setItem(tokenKey, value);
      const error = document.getElementById("adminTokenError");
      error.textContent = "Checking…";
      try {
        const response = await originalFetch("/v1/admin/health", {
          headers: { "x-admin-token": value, Accept: "application/json" }
        });
        if (!response.ok) {
          throw new Error("Token rejected");
        }
        gate.classList.add("is-open");
        window.location.reload();
      } catch (err) {
        error.textContent = err instanceof Error ? err.message : "Could not sign in.";
      }
    });
  };

  const bindCloudJobs = () => {
    const status = document.getElementById("cloudJobStatus");
    const healthEl = document.getElementById("cloudHealth");
    const body = document.getElementById("cloudJobsBody");
    const renderHealth = async () => {
      if (!healthEl || !body) {
        return;
      }
      const data = await (await fetch("/v1/admin/health")).json();
      healthEl.textContent = [
        `${data.movies} movies`,
        `${data.physicalMedia || 0} with physical media`,
        `${data.staleStreaming} stale streaming`,
        `${data.podcasts} podcasts`,
        `${data.episodes} episodes`
      ].join("   ");
      body.innerHTML = (data.jobs || [])
        .map(
          (job) =>
            `<tr><td>${job.name}</td><td>${job.status}</td><td>${job.started_at ? new Date(job.started_at).toLocaleString() : ""}</td></tr>`
        )
        .join("");
    };
    document.querySelectorAll("[data-cloud-job]").forEach((button) => {
      button.addEventListener("click", async () => {
        if (status) {
          status.textContent = `Running ${button.getAttribute("data-cloud-job")}…`;
        }
        try {
          const result = await (await fetch(`/v1/admin/jobs/${button.getAttribute("data-cloud-job")}`, { method: "POST" })).json();
          if (status) {
            status.textContent = result.status === "ok" ? "Job finished." : result.error || "Job ran.";
          }
          await renderHealth();
        } catch (error) {
          if (status) {
            status.textContent = error instanceof Error ? error.message : "Job failed.";
          }
        }
      });
    });
    if (token()) {
      renderHealth().catch(() => {});
    }
  };

  const boot = () => {
    ensureGate();
    const gate = document.getElementById("adminTokenGate");
    if (!token()) {
      return;
    }
    gate?.classList.add("is-open");
    bindCloudJobs();
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
