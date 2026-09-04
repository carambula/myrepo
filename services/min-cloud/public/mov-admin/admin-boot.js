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
    const REMATCH_JOB = "mov.closet.rematch";
    const status = document.getElementById("cloudJobStatus");
    const healthEl = document.getElementById("cloudHealth");
    const body = document.getElementById("cloudJobsBody");
    const rematchButton = document.querySelector(`[data-cloud-job="${REMATCH_JOB}"]`);
    let rematchPoll = null;
    const escapeHtml = (value) =>
      String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
    const latestJob = (jobs, name) => (jobs || []).find((job) => job.name === name);
    const isRematchRunning = (jobs) => latestJob(jobs, REMATCH_JOB)?.status === "running";
    const renderHealth = async () => {
      if (!healthEl || !body) {
        return [];
      }
      const data = await (await fetch("/v1/admin/health")).json();
      healthEl.textContent = [
        `${data.movies} movies`,
        `${data.physicalMedia || 0} with discs`,
        `${data.theaterStays || 0} theater stays`,
        `${data.staleStreaming} stale streaming`,
        `${data.podcasts} podcasts`,
        `${data.episodes} episodes`
      ].join("   ");
      const jobs = data.jobs || [];
      body.innerHTML = jobs
        .map(
          (job) =>
            `<tr><td>${escapeHtml(job.name)}</td><td>${escapeHtml(job.status)}</td><td>${escapeHtml(job.progressLabel || job.error || "")}</td><td>${job.started_at ? new Date(job.started_at).toLocaleString() : ""}</td></tr>`
        )
        .join("");
      if (rematchButton) {
        rematchButton.disabled = isRematchRunning(jobs);
      }
      const rematch = latestJob(jobs, REMATCH_JOB);
      if (status && rematch) {
        if (rematch.status === "running" || status.dataset.watchRematch === "1") {
          status.textContent = rematch.progressLabel || `Rematch ${rematch.status}…`;
          if (rematch.status !== "running") {
            delete status.dataset.watchRematch;
          }
        }
      }
      return jobs;
    };
    const stopRematchPoll = () => {
      if (rematchPoll) {
        clearInterval(rematchPoll);
        rematchPoll = null;
      }
    };
    const watchRematch = async () => {
      if (status) {
        status.dataset.watchRematch = "1";
      }
      const jobs = await renderHealth();
      if (!isRematchRunning(jobs)) {
        stopRematchPoll();
        return jobs;
      }
      if (!rematchPoll) {
        rematchPoll = setInterval(async () => {
          try {
            const next = await renderHealth();
            if (!isRematchRunning(next)) {
              stopRematchPoll();
            }
          } catch {
            // keep polling through transient errors
          }
        }, 2000);
      }
      return jobs;
    };
    document.querySelectorAll("[data-cloud-job]").forEach((button) => {
      button.addEventListener("click", async () => {
        const name = button.getAttribute("data-cloud-job");
        if (status) {
          status.textContent = name === REMATCH_JOB ? "Starting rematch…" : `Running ${name}…`;
        }
        try {
          const result = await (await fetch(`/v1/admin/jobs/${name}`, { method: "POST" })).json();
          if (name === REMATCH_JOB) {
            if (status) {
              status.dataset.watchRematch = "1";
              if (result.status === "already_running") {
                status.textContent = "Rematch already running — showing live progress.";
              } else if (result.status === "running") {
                status.textContent = "Rematch started…";
              } else {
                status.textContent = result.error || result.progressLabel || "Rematch ran.";
              }
            }
            await watchRematch();
            return;
          }
          if (status) {
            status.textContent = result.status === "ok" ? "Job finished." : result.error || "Job ran.";
          }
          await renderHealth();
        } catch (error) {
          const message = error instanceof Error ? error.message : "Job failed.";
          if (name === REMATCH_JOB && /load failed|failed to fetch|networkerror|aborted/i.test(message)) {
            if (status) {
              status.dataset.watchRematch = "1";
              status.textContent = "Browser dropped the wait — checking whether rematch is still running…";
            }
            await watchRematch();
            return;
          }
          if (status) {
            status.textContent = message;
          }
        }
      });
    });
    if (token()) {
      watchRematch().catch(() => {});
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
