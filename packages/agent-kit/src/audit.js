import { randomBytes } from 'node:crypto';

const SENSITIVE_KEYS = new Set(['token', 'authorization', 'MIN_AGENT_TOKEN', 'secret', 'password']);

export function redactValue(value) {
  if (value && typeof value === 'object') {
    if (Array.isArray(value)) return value.map(redactValue);
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      out[key] = SENSITIVE_KEYS.has(key) ? '[redacted]' : redactValue(item);
    }
    return out;
  }
  return value;
}

export function createAuditEntry({
  connectionId,
  connectionName,
  tool,
  app,
  input,
  ok,
  error,
  undoId,
  now = new Date(),
}) {
  return {
    id: `aud_${randomBytes(6).toString('hex')}`,
    at: now.toISOString(),
    connectionId,
    connectionName,
    tool,
    app,
    input: redactValue(input ?? {}),
    ok,
    error: error ?? null,
    undoId: undoId ?? null,
  };
}
