const required = (name: string, fallback?: string) => {
  const value = process.env[name] ?? fallback;
  return value ?? "";
};

export const config = {
  port: Number(process.env.PORT || 4000),
  databaseUrl: required("DATABASE_URL", "postgres://postgres:postgres@localhost:5433/mincloud"),
  publicUrl: required("PUBLIC_URL", "http://localhost:4000"),
  sessionSecret: required("SESSION_SECRET", "dev-session-secret"),
  adminToken: required("ADMIN_TOKEN", ""),
  adminEmails: (process.env.ADMIN_EMAILS || "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean),
  tmdbApiKey: process.env.TMDB_API_KEY || "",
  tmdbRegion: process.env.TMDB_REGION || "US",
  omdbApiKey: process.env.OMDB_API_KEY || "",
  enableJobs: (process.env.ENABLE_JOBS || "true") === "true",
  cronSecret: process.env.CRON_SECRET || "",
  apnsKeyId: process.env.APNS_KEY_ID || "",
  apnsTeamId: process.env.APNS_TEAM_ID || "",
  apnsKey: process.env.APNS_KEY || "",
  apnsBundleId: process.env.APNS_BUNDLE_ID || "",
  apnsBundleIdMov:
    process.env.APNS_BUNDLE_ID_MOV ||
    (process.env.APNS_BUNDLE_ID?.includes("WatchedIt")
      ? process.env.APNS_BUNDLE_ID
      : "Carambula-Projects.WatchedIt"),
  apnsBundleIdPod:
    process.env.APNS_BUNDLE_ID_POD ||
    (process.env.APNS_BUNDLE_ID && !process.env.APNS_BUNDLE_ID.includes("WatchedIt")
      ? process.env.APNS_BUNDLE_ID
      : "Carambula-Projects.PodLink"),
  apnsProduction: (process.env.APNS_PRODUCTION ?? "true") !== "false",
  nodeEnv: process.env.NODE_ENV || "development",
  agentToken: process.env.MIN_CLOUD_AGENT_TOKEN || "",
  agentUserEmail: process.env.AGENT_USER_EMAIL || "",

  // Feedback / ideas loop (Cadence-style). GitHub issues are redacted;
  // full reports stay in Postgres. See docs/FEEDBACK.md.
  feedbackGithubToken: process.env.FEEDBACK_GITHUB_TOKEN || "",
  feedbackGithubRepo: process.env.FEEDBACK_GITHUB_REPO || "carambula/myrepo",
  feedbackGithubApiUrl: process.env.FEEDBACK_GITHUB_API_URL || "https://api.github.com",
  feedbackGithubNotifyUser: process.env.FEEDBACK_GITHUB_NOTIFY_USER || "carambula",
  feedbackCursorWebhookUrl: process.env.FEEDBACK_CURSOR_WEBHOOK_URL || "",
  feedbackCursorWebhookSecret: process.env.FEEDBACK_CURSOR_WEBHOOK_SECRET || "",
  feedbackCursorBuildWebhookUrl: process.env.FEEDBACK_CURSOR_BUILD_WEBHOOK_URL || "",
  feedbackCursorBuildWebhookSecret: process.env.FEEDBACK_CURSOR_BUILD_WEBHOOK_SECRET || "",
  feedbackCursorIterateWebhookUrl: process.env.FEEDBACK_CURSOR_ITERATE_WEBHOOK_URL || "",
  feedbackCursorIterateWebhookSecret: process.env.FEEDBACK_CURSOR_ITERATE_WEBHOOK_SECRET || "",
  feedbackCursorApiKey: process.env.FEEDBACK_CURSOR_API_KEY || "",
  feedbackCursorAgentsApiUrl:
    process.env.FEEDBACK_CURSOR_AGENTS_API_URL || "https://api.cursor.com/v1/agents",
  feedbackDailyLimit: Number(process.env.FEEDBACK_DAILY_LIMIT || 20),
  feedbackUnlimitedEmails: (process.env.FEEDBACK_UNLIMITED_EMAILS || "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean),
  /** Global token for /internal/feedback/* (also HMAC secret for per-idea agent tokens). */
  feedbackCronToken: process.env.FEEDBACK_CRON_TOKEN || process.env.CRON_SECRET || ""
};

export const isProduction = config.nodeEnv === "production";
