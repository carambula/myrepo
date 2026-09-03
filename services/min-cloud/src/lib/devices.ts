import { query } from "../db.js";

export const upsertAnonymousDevice = async (
  deviceKey: string,
  app: "watchedit" | "podlink" = "podlink",
  platform = "ios"
) => {
  const existing = await query(`SELECT id FROM devices WHERE device_key = $1`, [deviceKey]);
  if (existing.rowCount) {
    await query(`UPDATE devices SET updated_at = NOW() WHERE id = $1`, [existing.rows[0].id]);
    return String(existing.rows[0].id);
  }
  const inserted = await query(
    `
    INSERT INTO devices (device_key, app, platform)
    VALUES ($1, $2, $3)
    RETURNING id
    `,
    [deviceKey, app, platform]
  );
  return String(inserted.rows[0].id);
};
