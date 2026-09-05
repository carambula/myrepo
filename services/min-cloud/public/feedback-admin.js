const toastEl = document.getElementById("toast");
const tokenKey = "mincloud.adminToken";
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

const appLabel = {
  mov: "mov min",
  pod: "pod min",
  vid: "vid min",
  cyc: "cyc min",
  spin: "spin min",
  fit: "fit min"
};

const statuses = ["open", "planned", "in_progress", "shipped", "closed", "hidden"];

const filters = () => ({
  app: document.getElementById("appFilter").value,
  kind: document.getElementById("kindFilter").value,
  status: document.getElementById("statusFilter").value
});

const render = (items) => {
  document.getElementById("rows").innerHTML = (items || [])
    .map((item) => {
      const options = statuses
        .map(
          (status) =>
            `<option value="${status}" ${status === item.status ? "selected" : ""}>${status.replace("_", " ")}</option>`
        )
        .join("");
      const detail = [item.title, item.body].filter(Boolean).join(metadataSeparator);
      return `
        <tr>
          <td>${item.voteCount}</td>
          <td>${appLabel[item.app] || item.app}</td>
          <td>${item.kind}</td>
          <td>${escapeHtml(detail)}</td>
          <td>
            <select data-id="${item.id}">${options}</select>
          </td>
        </tr>
      `;
    })
    .join("");
};

const load = async () => {
  const query = new URLSearchParams();
  const current = filters();
  if (current.app !== "all") query.set("app", current.app);
  if (current.kind !== "all") query.set("kind", current.kind);
  if (current.status !== "all") query.set("status", current.status);
  const data = await api(`/v1/admin/feedback?${query}`);
  render(data.items);
};

document.getElementById("adminToken").value = token();
document.getElementById("saveToken").addEventListener("click", () => {
  localStorage.setItem(tokenKey, document.getElementById("adminToken").value);
  toast("Admin token saved on this device");
  load().catch((error) => toast(error.message));
});

["appFilter", "kindFilter", "statusFilter"].forEach((id) => {
  document.getElementById(id).addEventListener("change", () => {
    load().catch((error) => toast(error.message));
  });
});

document.getElementById("rows").addEventListener("change", async (event) => {
  const select = event.target.closest("select[data-id]");
  if (!select) {
    return;
  }
  try {
    await api(`/v1/admin/feedback/${select.getAttribute("data-id")}`, {
      method: "PATCH",
      body: JSON.stringify({ status: select.value })
    });
    toast("Updated");
    await load();
  } catch (error) {
    toast(error.message);
  }
});

load().catch((error) => toast(error.message));
