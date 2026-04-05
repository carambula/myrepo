const state = {
  themes: [],
  selectedThemeId: null,
};

const elements = {
  themesList: document.getElementById("themesList"),
  themeForm: document.getElementById("themeForm"),
  themeStatus: document.getElementById("themeStatus"),
  newThemeBtn: document.getElementById("newThemeBtn"),
  deleteThemeBtn: document.getElementById("deleteThemeBtn"),
  saveThemeBtn: document.getElementById("saveThemeBtn"),
  toast: document.getElementById("toast"),
};

const fields = {
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

function showToast(message, isError = false) {
  elements.toast.textContent = message;
  elements.toast.classList.toggle("error", isError);
  elements.toast.classList.remove("hidden");
  setTimeout(() => elements.toast.classList.add("hidden"), 2800);
}

function componentToHex(value) {
  const channel = Math.max(0, Math.min(255, Math.round((Number(value) || 0) * 255)));
  return channel.toString(16).padStart(2, "0");
}

function colorToHex(color) {
  const source = color || {};
  return `#${componentToHex(source.red)}${componentToHex(source.green)}${componentToHex(source.blue)}`;
}

function parseHexColor(hex) {
  const normalized = String(hex || "").trim().replace(/^#/, "");
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

function blankTheme() {
  return {
    id: null,
    name: "",
    builtInThemeName: "",
    supportsLightMode: true,
    headlineFontStyle: "system-default",
    bodyFontStyle: "system-default",
    accent: { red: 0.27, green: 0.44, blue: 1, alpha: 1 },
    secondaryAccent: { red: 0.25, green: 0.35, blue: 0.72, alpha: 1 },
    darkModeHeadlineColor: { red: 0.81, green: 0.85, blue: 1, alpha: 1 },
    lightModeHeadlineColor: { red: 0.12, green: 0.17, blue: 0.34, alpha: 1 },
    darkModeBackground: { red: 0.06, green: 0.07, blue: 0.13, alpha: 1 },
    lightModeBackground: { red: 0.96, green: 0.97, blue: 1, alpha: 1 },
  };
}

async function loadThemes() {
  const response = await fetch("/api/themes");
  if (!response.ok) throw new Error("Failed to load themes");
  const data = await response.json();
  state.themes = Array.isArray(data.themes) ? data.themes : [];
}

function renderThemesList() {
  elements.themesList.innerHTML = "";
  for (const theme of [...state.themes].sort((a, b) => a.name.localeCompare(b.name))) {
    const row = document.createElement("div");
    row.className = "theme-list-item";
    if (String(theme.id) === String(state.selectedThemeId)) row.classList.add("selected");
    row.innerHTML = `<div class="theme-list-title">${theme.name}</div>
      <div class="theme-list-subtitle">${theme.builtInThemeName ? `Overrides ${theme.builtInThemeName}` : "Custom"}</div>`;
    row.addEventListener("click", () => {
      state.selectedThemeId = theme.id;
      fillThemeForm(theme);
      renderThemesList();
    });
    elements.themesList.append(row);
  }
}

function fillThemeForm(theme) {
  const value = theme || blankTheme();
  elements.themeForm.classList.remove("hidden");
  elements.themeStatus.textContent = value.id ? `Editing "${value.name}"` : "New theme (not saved yet)";
  fields.name.value = value.name || "";
  fields.builtInThemeName.value = value.builtInThemeName || "";
  fields.supportsLightMode.value = value.supportsLightMode ? "true" : "false";
  fields.headlineFontStyle.value = value.headlineFontStyle || "system-default";
  fields.bodyFontStyle.value = value.bodyFontStyle || "system-default";
  fields.accent.value = colorToHex(value.accent);
  fields.secondaryAccent.value = colorToHex(value.secondaryAccent);
  fields.darkModeHeadlineColor.value = colorToHex(value.darkModeHeadlineColor || value.headlineColor);
  fields.lightModeHeadlineColor.value = colorToHex(value.lightModeHeadlineColor || value.headlineColor);
  fields.darkModeBackground.value = colorToHex(value.darkModeBackground);
  fields.lightModeBackground.value = colorToHex(value.lightModeBackground);
}

function buildThemePayload() {
  const accent = parseHexColor(fields.accent.value);
  const secondaryAccent = parseHexColor(fields.secondaryAccent.value);
  const darkModeHeadlineColor = parseHexColor(fields.darkModeHeadlineColor.value);
  const lightModeHeadlineColor = parseHexColor(fields.lightModeHeadlineColor.value);
  const darkModeBackground = parseHexColor(fields.darkModeBackground.value);
  const lightModeBackground = parseHexColor(fields.lightModeBackground.value);
  if (
    !accent ||
    !secondaryAccent ||
    !darkModeHeadlineColor ||
    !lightModeHeadlineColor ||
    !darkModeBackground ||
    !lightModeBackground
  ) {
    return null;
  }
  return {
    id: state.selectedThemeId,
    name: fields.name.value.trim(),
    builtInThemeName: fields.builtInThemeName.value.trim() || null,
    supportsLightMode: fields.supportsLightMode.value === "true",
    headlineFontStyle: fields.headlineFontStyle.value || "system-default",
    bodyFontStyle: fields.bodyFontStyle.value || "system-default",
    accent,
    secondaryAccent,
    headlineColor: darkModeHeadlineColor,
    darkModeHeadlineColor,
    lightModeHeadlineColor,
    darkModeBackground,
    lightModeBackground,
  };
}

async function saveTheme() {
  const payload = buildThemePayload();
  if (!payload || !payload.name) {
    showToast("Theme name and colors are required", true);
    return;
  }
  const isUpdate = state.selectedThemeId && state.themes.some((t) => String(t.id) === String(state.selectedThemeId));
  const endpoint = isUpdate ? `/api/themes/${encodeURIComponent(state.selectedThemeId)}` : "/api/themes";
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
  const body = await response.json();
  state.selectedThemeId = body.theme?.id || null;
  await loadThemes();
  const selected = state.themes.find((theme) => String(theme.id) === String(state.selectedThemeId));
  fillThemeForm(selected || blankTheme());
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
  elements.themeStatus.textContent = "No theme selected.";
  showToast("Theme deleted");
}

function createThemeDraft() {
  state.selectedThemeId = null;
  fillThemeForm(blankTheme());
  renderThemesList();
}

async function init() {
  try {
    await loadThemes();
    if (state.themes.length) {
      state.selectedThemeId = state.themes[0].id;
      fillThemeForm(state.themes[0]);
    }
    renderThemesList();
    elements.newThemeBtn.addEventListener("click", createThemeDraft);
    elements.saveThemeBtn.addEventListener("click", (event) => {
      event.preventDefault();
      saveTheme();
    });
    elements.deleteThemeBtn.addEventListener("click", deleteTheme);
  } catch (error) {
    showToast(error.message || "Failed to load themes", true);
  }
}

init();
