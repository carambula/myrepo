#!/usr/bin/env node
/**
 * Import PodLink DefaultPodcasts.json into Min Cloud (resolves iTunes feed URLs).
 *   ADMIN_TOKEN=... node scripts/import-podcasts.mjs [path-to-DefaultPodcasts.json]
 */
import fs from "node:fs/promises";
import path from "node:path";

const baseURL = (process.env.MIN_CLOUD_URL || "https://min-cloud-production.up.railway.app").replace(/\/$/, "");
const token = process.env.ADMIN_TOKEN || "";
const file = path.resolve(
  process.argv[2] || "../../apps/PodLink/PodLink/Resources/DefaultPodcasts.json"
);

if (!token) {
  console.error("ADMIN_TOKEN is required");
  process.exit(1);
}

const payload = JSON.parse(await fs.readFile(file, "utf8"));
const response = await fetch(`${baseURL}/v1/admin/pod/import`, {
  method: "POST",
  headers: {
    "content-type": "application/json",
    "x-admin-token": token
  },
  body: JSON.stringify(payload)
});
const text = await response.text();
if (!response.ok) {
  throw new Error(`import failed ${response.status}: ${text.slice(0, 400)}`);
}
console.log(text);
