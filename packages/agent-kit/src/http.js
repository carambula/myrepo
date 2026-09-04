import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AgentError, toolsForScopes } from './protocol.js';
import { parseBearer } from './auth.js';

const consoleHTML = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'console.html'), 'utf8');

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 1_000_000) {
        reject(new AgentError('payload_too_large', 'Request body is too large.', 413));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (!chunks.length) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new AgentError('invalid_json', 'Request body must be JSON.'));
      }
    });
    req.on('error', reject);
  });
}

function send(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    ...CORS,
  });
  res.end(body);
}

function describeTools(connection) {
  return toolsForScopes(connection.scopes).map((tool) => ({
    name: tool.name,
    description: tool.description,
    kind: tool.kind,
    app: tool.app,
    inputSchema: tool.inputSchema,
  }));
}

function invokeName(body) {
  return body.name || body.tool;
}

function invokeArguments(body) {
  if (body.arguments && typeof body.arguments === 'object') return body.arguments;
  if (body.input && typeof body.input === 'object') return body.input;
  if (body.args && typeof body.args === 'object') return body.args;
  return {};
}

export function createAgentHttpServer(gateway, { host = '127.0.0.1', port = 4732 } = {}) {
  const server = createServer(async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { ...CORS, 'Content-Length': 0 });
        res.end();
        return;
      }

      const url = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
      if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
        });
        res.end(consoleHTML);
        return;
      }
      if (req.method === 'GET' && url.pathname === '/health') {
        send(res, 200, { ok: true, service: 'min-apps-agent' });
        return;
      }

      const token = parseBearer(req.headers.authorization) || url.searchParams.get('token');

      if (req.method === 'GET' && (url.pathname === '/tools' || url.pathname === '/v1/tools')) {
        const connection = gateway.authenticate(token);
        const tools = describeTools(connection);
        send(res, 200, {
          ok: true,
          tools,
          names: tools.map((tool) => tool.name),
        });
        return;
      }

      if (req.method === 'POST' && (url.pathname === '/invoke' || url.pathname === '/v1/tools/call')) {
        const body = await readBody(req);
        const name = invokeName(body);
        if (!name) {
          throw new AgentError('invalid_input', 'Provide name (or tool) and optional arguments.');
        }
        const result = await gateway.call(token, name, invokeArguments(body));
        send(res, 200, result);
        return;
      }

      if (req.method === 'GET' && url.pathname === '/v1/whoami') {
        const result = await gateway.call(token, 'whoami', {});
        send(res, 200, result);
        return;
      }

      if (req.method === 'POST' && url.pathname.startsWith('/v1/tools/')) {
        const name = decodeURIComponent(url.pathname.slice('/v1/tools/'.length));
        const body = await readBody(req);
        const result = await gateway.call(token, name, body);
        send(res, 200, result);
        return;
      }

      send(res, 404, { error: 'not_found', message: 'Unknown endpoint.' });
    } catch (error) {
      const status = error instanceof AgentError ? error.status : 500;
      send(res, status, error instanceof AgentError ? error.toJSON() : { error: 'error', message: error.message });
    }
  });

  return {
    server,
    listen() {
      return new Promise((resolve) => {
        server.listen(port, host, () => resolve({ host, port }));
      });
    },
    close() {
      return new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    },
  };
}
