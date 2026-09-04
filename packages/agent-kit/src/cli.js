#!/usr/bin/env node
import { pathToFileURL } from 'node:url';
import { createConnection, mcpConfigSnippet, redactConnection } from './auth.js';
import { AgentGateway } from './gateway.js';
import { createAgentHttpServer } from './http.js';
import { createMcpServer } from './mcp.js';
import { APP_IDS, allScopes, expandScopes } from './protocol.js';
import { FileStore, defaultHomeDir } from './store.js';

function printHelp() {
  console.log(`min-agent — connect an agent to the min apps suite

Usage:
  min-agent init [--name NAME] [--read-only] [--apps mov,pod,fit]
  min-agent connections
  min-agent revoke <connection-id>
  min-agent mcp
  min-agent serve [--host 127.0.0.1] [--port 4732]
  min-agent call <tool> [--json '{...}']
  min-agent import-library <file.json>
  min-agent export-library

Environment:
  MIN_AGENT_TOKEN   Bearer token for mcp / serve / call
  MIN_AGENT_HOME    State directory (default ~/.min-apps/agent)
`);
}

function argValue(args, flag, fallback) {
  const index = args.indexOf(flag);
  if (index === -1) return fallback;
  return args[index + 1];
}

function parseApps(args) {
  const raw = argValue(args, '--apps', '');
  if (!raw) return APP_IDS;
  return raw.split(',').map((item) => item.trim()).filter(Boolean);
}

function scopesFor(args) {
  const apps = parseApps(args);
  const readOnly = args.includes('--read-only');
  const scopes = ['undo', 'audit'];
  for (const app of apps) {
    scopes.push(`${app}.read`);
    if (!readOnly) scopes.push(`${app}.write`);
  }
  return expandScopes(scopes);
}

function store() {
  return new FileStore(defaultHomeDir());
}

function requireToken() {
  const token = process.env.MIN_AGENT_TOKEN;
  if (!token) {
    console.error('MIN_AGENT_TOKEN is required.');
    process.exit(1);
  }
  return token;
}

async function main(argv = process.argv.slice(2)) {
  const [command, ...args] = argv;
  if (!command || command === 'help' || command === '--help') {
    printHelp();
    return;
  }

  if (command === 'init') {
    const file = store();
    const { connection, token } = createConnection({
      name: argValue(args, '--name', 'Local agent'),
      scopes: scopesFor(args),
    });
    file.state.connections.push(connection);
    file.persist();
    console.log(JSON.stringify({
      connection: redactConnection(connection),
      token,
      warning: 'Copy this token now. It is stored as a hash and cannot be shown again.',
      mcp: mcpConfigSnippet({
        token,
        command: 'node',
        args: [new URL('./cli.js', import.meta.url).pathname, 'mcp'],
      }),
    }, null, 2));
    return;
  }

  if (command === 'connections') {
    const file = store();
    console.log(JSON.stringify(file.state.connections.map(redactConnection), null, 2));
    return;
  }

  if (command === 'revoke') {
    const id = args[0];
    const file = store();
    const connection = file.state.connections.find((item) => item.id === id);
    if (!connection) {
      console.error('Connection not found.');
      process.exit(1);
    }
    connection.revokedAt = new Date().toISOString();
    file.persist();
    console.log(JSON.stringify({ revoked: redactConnection(connection) }, null, 2));
    return;
  }

  if (command === 'mcp') {
    const gateway = new AgentGateway(store());
    createMcpServer({ gateway, token: requireToken() });
    return;
  }

  if (command === 'serve') {
    const gateway = new AgentGateway(store());
    const host = argValue(args, '--host', '127.0.0.1');
    const port = Number(argValue(args, '--port', '4732'));
    const http = createAgentHttpServer(gateway, { host, port });
    const info = await http.listen();
    console.log(JSON.stringify({ ok: true, ...info }, null, 2));
    return;
  }

  if (command === 'call') {
    const name = args[0];
    const json = argValue(args, '--json', '{}');
    const gateway = new AgentGateway(store());
    const result = await gateway.call(requireToken(), name, JSON.parse(json));
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  if (command === 'import-library') {
    const filePath = args[0];
    const { readFileSync } = await import('node:fs');
    const library = JSON.parse(readFileSync(filePath, 'utf8'));
    const file = store();
    file.replaceLibrary(library.library || library);
    console.log(JSON.stringify({ ok: true, imported: Object.keys(file.state.library) }, null, 2));
    return;
  }

  if (command === 'export-library') {
    const file = store();
    console.log(JSON.stringify(file.state.library, null, 2));
    return;
  }

  console.error(`Unknown command: ${command}`);
  printHelp();
  process.exit(1);
}

const invoked = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (invoked) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

export { main, allScopes };
