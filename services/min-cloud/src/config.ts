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
  nodeEnv: process.env.NODE_ENV || "development"
};

export const isProduction = config.nodeEnv === "production";
