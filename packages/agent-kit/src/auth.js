import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { AGENT_TOKEN_PREFIX, AgentError, allScopes, expandScopes } from './protocol.js';

export function hashToken(token) {
  return createHash('sha256').update(String(token), 'utf8').digest('hex');
}

export function generateToken() {
  return `${AGENT_TOKEN_PREFIX}${randomBytes(32).toString('base64url')}`;
}

export function tokensEqual(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

export function hashesEqual(a, b) {
  return tokensEqual(a, b);
}

export function createConnection({
  name,
  scopes,
  now = new Date(),
} = {}) {
  const token = generateToken();
  const id = randomBytes(8).toString('hex');
  const resolvedScopes = expandScopes(scopes?.length ? scopes : allScopes());
  return {
    connection: {
      id,
      name: (name || 'Agent').trim() || 'Agent',
      tokenHash: hashToken(token),
      scopes: resolvedScopes,
      createdAt: now.toISOString(),
      lastUsedAt: null,
      revokedAt: null,
    },
    token,
  };
}

export function redactConnection(connection) {
  const { tokenHash, ...rest } = connection;
  return {
    ...rest,
    tokenFingerprint: tokenHash.slice(0, 8),
  };
}

export function findConnectionByToken(connections, token) {
  if (!token || typeof token !== 'string') return null;
  const incoming = hashToken(token.trim());
  return connections.find((connection) => hashesEqual(connection.tokenHash, incoming)) ?? null;
}

export function assertActiveConnection(connection) {
  if (!connection) {
    throw new AgentError('unauthorized', 'Missing or invalid agent token.', 401);
  }
  if (connection.revokedAt) {
    throw new AgentError('revoked', 'This agent connection has been revoked.', 403);
  }
  return connection;
}

export function assertScopes(connection, requiredScopes) {
  const granted = new Set(expandScopes(connection.scopes || []));
  const missing = requiredScopes.filter((scope) => !granted.has(scope));
  if (missing.length) {
    throw new AgentError(
      'forbidden',
      `This connection is missing required permission${missing.length === 1 ? '' : 's'}: ${missing.join(', ')}.`,
      403,
      { missingScopes: missing }
    );
  }
}

export function parseBearer(header) {
  if (!header || typeof header !== 'string') return null;
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

export function mcpConfigSnippet({ token, command = 'npx', args = ['@min-apps/agent-kit', 'mcp'] } = {}) {
  return {
    mcpServers: {
      'min-apps': {
        command,
        args,
        env: {
          MIN_AGENT_TOKEN: token,
        },
      },
    },
  };
}
