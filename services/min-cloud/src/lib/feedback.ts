export const FEEDBACK_APPS = ["mov", "pod", "vid", "cyc", "spin", "fit"] as const;
export const FEEDBACK_KINDS = ["idea", "bug"] as const;
export const FEEDBACK_STATUSES = ["open", "planned", "in_progress", "shipped", "closed", "hidden"] as const;
export const PUBLIC_FEEDBACK_STATUSES = ["open", "planned", "in_progress", "shipped", "closed"] as const;

export type FeedbackApp = (typeof FEEDBACK_APPS)[number];
export type FeedbackKind = (typeof FEEDBACK_KINDS)[number];
export type FeedbackStatus = (typeof FEEDBACK_STATUSES)[number];

const TITLE_MIN = 3;
const TITLE_MAX = 120;
const BODY_MAX = 4000;
const DEVICE_ID_MAX = 128;

export class FeedbackInputError extends Error {
  status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = "FeedbackInputError";
    this.status = status;
  }
}

export const isFeedbackApp = (value: unknown): value is FeedbackApp =>
  typeof value === "string" && (FEEDBACK_APPS as readonly string[]).includes(value);

export const isFeedbackKind = (value: unknown): value is FeedbackKind =>
  typeof value === "string" && (FEEDBACK_KINDS as readonly string[]).includes(value);

export const isFeedbackStatus = (value: unknown): value is FeedbackStatus =>
  typeof value === "string" && (FEEDBACK_STATUSES as readonly string[]).includes(value);

export const isPublicFeedbackStatus = (value: unknown): value is Exclude<FeedbackStatus, "hidden"> =>
  typeof value === "string" && (PUBLIC_FEEDBACK_STATUSES as readonly string[]).includes(value);

export const normalizeTitle = (value: unknown) => {
  const title = typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
  if (title.length < TITLE_MIN) {
    throw new FeedbackInputError("Title needs at least 3 characters.");
  }
  if (title.length > TITLE_MAX) {
    throw new FeedbackInputError("Title is too long.");
  }
  return title;
};

export const normalizeBody = (value: unknown) => {
  const body = typeof value === "string" ? value.trim() : "";
  if (body.length > BODY_MAX) {
    throw new FeedbackInputError("Details are too long.");
  }
  return body;
};

export const normalizeDeviceId = (value: unknown) => {
  const deviceId = typeof value === "string" ? value.trim() : "";
  if (!deviceId || deviceId.length > DEVICE_ID_MAX) {
    throw new FeedbackInputError("A device id is required.");
  }
  if (!/^[A-Za-z0-9._:-]+$/.test(deviceId)) {
    throw new FeedbackInputError("Device id is invalid.");
  }
  return deviceId;
};

export const normalizeContext = (value: unknown) => {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const input = value as Record<string, unknown>;
  const context: Record<string, string> = {};
  for (const key of ["appVersion", "build", "platform", "systemVersion"]) {
    const raw = input[key];
    if (typeof raw === "string" && raw.trim()) {
      context[key] = raw.trim().slice(0, 80);
    }
  }
  return context;
};

export const voterKeyFor = (input: { userId?: string | null; deviceId: string }) => {
  if (input.userId) {
    return `user:${input.userId}`;
  }
  return `device:${input.deviceId}`;
};

export const parseFeedbackListQuery = (input: {
  app?: unknown;
  kind?: unknown;
  status?: unknown;
  q?: unknown;
  includeHidden?: boolean;
}) => {
  const app = input.app == null || input.app === "" || input.app === "all" ? null : input.app;
  if (app && !isFeedbackApp(app)) {
    throw new FeedbackInputError("Unknown app.");
  }
  const kind = input.kind == null || input.kind === "" || input.kind === "all" ? null : input.kind;
  if (kind && !isFeedbackKind(kind)) {
    throw new FeedbackInputError("Unknown kind. Use idea or bug.");
  }
  const status = input.status == null || input.status === "" || input.status === "all" ? null : input.status;
  if (status && !isFeedbackStatus(status)) {
    throw new FeedbackInputError("Unknown status.");
  }
  if (status === "hidden" && !input.includeHidden) {
    throw new FeedbackInputError("Unknown status.");
  }
  const q = typeof input.q === "string" ? input.q.trim().slice(0, 80) : "";
  return {
    app: app as FeedbackApp | null,
    kind: kind as FeedbackKind | null,
    status: status as FeedbackStatus | null,
    q
  };
};

export type FeedbackRow = {
  id: string;
  app: string;
  kind: string;
  status: string;
  title: string;
  body: string;
  context?: unknown;
  vote_count: number | string;
  author_handle?: string | null;
  created_at: Date | string;
  updated_at: Date | string;
  voted?: boolean | string | number | null;
};

export const mapFeedbackItem = (row: FeedbackRow, options: { includeBody?: boolean } = {}) => {
  const includeBody = options.includeBody !== false;
  return {
    id: String(row.id),
    app: String(row.app),
    kind: String(row.kind),
    status: String(row.status),
    title: String(row.title),
    body: includeBody ? String(row.body ?? "") : undefined,
    context: row.context && typeof row.context === "object" ? row.context : {},
    voteCount: Number(row.vote_count) || 0,
    authorHandle: row.author_handle ? String(row.author_handle) : null,
    createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : String(row.created_at),
    updatedAt: row.updated_at instanceof Date ? row.updated_at.toISOString() : String(row.updated_at),
    voted: Boolean(row.voted)
  };
};

export const feedbackAppLabel = (app: string) => {
  switch (app) {
    case "mov":
      return "mov min";
    case "pod":
      return "pod min";
    case "vid":
      return "vid min";
    case "cyc":
      return "cyc min";
    case "spin":
      return "spin min";
    case "fit":
      return "fit min";
    default:
      return app;
  }
};
