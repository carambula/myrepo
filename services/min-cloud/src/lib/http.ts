import http from "node:http";
import https from "node:https";

const USER_AGENT = "MinCloud/0.1 (+https://min.cloud)";

export type FetchOptions = {
  timeoutMs?: number;
};

const safeUrlForError = (url: string) => {
  try {
    const parsed = new URL(url);
    return `${parsed.origin}${parsed.pathname}`;
  } catch {
    return "request";
  }
};

export const fetchText = (url: string, headers: Record<string, string> = {}, options: FetchOptions = {}) =>
  new Promise<string>((resolve, reject) => {
    const transport = url.startsWith("http://") ? http : https;
    const request = transport.get(
      url,
      {
        headers: {
          "User-Agent": USER_AGENT,
          Accept: "application/json, application/xml, text/xml, */*",
          ...headers
        }
      },
      (response) => {
        if (response.statusCode && response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          const next = new URL(response.headers.location, url).toString();
          fetchText(next, headers, options).then(resolve, reject);
          return;
        }
        const chunks: Buffer[] = [];
        response.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
        response.on("end", () => {
          const body = Buffer.concat(chunks).toString("utf8");
          if (response.statusCode && response.statusCode >= 400) {
            reject(new Error(`Request failed (${response.statusCode}): ${body.slice(0, 200)}`));
            return;
          }
          resolve(body);
        });
      }
    );
    request.on("error", reject);
    request.setTimeout(options.timeoutMs ?? 20000, () => {
      request.destroy(new Error(`Request timed out: ${safeUrlForError(url)}`));
    });
  });

export const fetchJson = async <T>(
  url: string,
  headers: Record<string, string> = {},
  options: FetchOptions = {}
): Promise<T> => {
  const body = await fetchText(url, headers, options);
  return JSON.parse(body) as T;
};

export const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));
