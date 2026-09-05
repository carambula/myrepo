import { query } from "../db.js";
import {
  mapFeedbackItem,
  parseFeedbackListQuery,
  type FeedbackRow
} from "./feedback.js";

export const listFeedbackItems = async (input: {
  app?: unknown;
  kind?: unknown;
  status?: unknown;
  q?: unknown;
  voterKey?: string | null;
  includeHidden?: boolean;
  includeBody?: boolean;
}) => {
  const filters = parseFeedbackListQuery({
    app: input.app,
    kind: input.kind,
    status: input.status,
    q: input.q,
    includeHidden: input.includeHidden
  });
  const params: unknown[] = [];
  const where: string[] = [];
  if (!input.includeHidden) {
    where.push(`status <> 'hidden'`);
  }
  if (filters.app) {
    params.push(filters.app);
    where.push(`app = $${params.length}`);
  }
  if (filters.kind) {
    params.push(filters.kind);
    where.push(`kind = $${params.length}`);
  }
  if (filters.status) {
    params.push(filters.status);
    where.push(`status = $${params.length}`);
  }
  if (filters.q) {
    params.push(`%${filters.q}%`);
    where.push(`(title ILIKE $${params.length} OR body ILIKE $${params.length})`);
  }
  const votedSelect = input.voterKey
    ? `, EXISTS (
         SELECT 1 FROM feedback_votes v
         WHERE v.item_id = feedback_items.id AND v.voter_key = $${params.length + 1}
       ) AS voted`
    : ", FALSE AS voted";
  if (input.voterKey) {
    params.push(input.voterKey);
  }
  const result = await query(
    `
    SELECT id, app, kind, status, title, body, context, vote_count, author_handle, created_at, updated_at
           ${votedSelect}
    FROM feedback_items
    ${where.length ? `WHERE ${where.join(" AND ")}` : ""}
    ORDER BY vote_count DESC, created_at DESC
    LIMIT 200
    `,
    params
  );
  return result.rows.map((row) =>
    mapFeedbackItem(row as FeedbackRow, { includeBody: input.includeBody === true })
  );
};
