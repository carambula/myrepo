import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AgentError } from './protocol.js';
import { parseBearer } from './auth.js';

const consoleHTML = readFileSync(join(dirname(fileURLToPath(import.meta.url)), 'console.html'), 'utf8');

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
  });
  res.end(body);
}

export function createAgentHttpServer(gateway, { host = '127.0.0.1', port = 4732 } = {}) {
  const server = createServer(async (req, res) => {
    try {
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
      if (req.method === 'GET' && url.pathname === '/v1/whoami') {
        const result = await gateway.call(token, 'whoami', {});
        send(res, 200, result);
        return;
      }
      if (req.method === 'GET' && url.pathname === '/v1/tools') {
        const result = await gateway.call(token, 'list_capabilities', {});
        send(res, 200, result);
        return;
      }
      if (req.method === 'POST' && url.pathname === '/v1/tools/call') {
        const body = await readBody(req);
        const result = await gateway.call(token, body.name, body.arguments || body.input || {});
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
