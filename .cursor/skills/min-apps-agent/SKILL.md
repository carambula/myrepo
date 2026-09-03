---
name: min-apps-agent
description: Call min apps (mov/pod/vid/cyc/spin/fit) through the local agent HTTP API. Use when listing or changing watched movies, podcasts, videos, races, bikes, or timers.
---

# Min apps agent HTTP

The MCP server is wrapped as JSON over HTTP. Same `minagt_…` bearer token as MCP.

Base URL (loopback): `http://127.0.0.1:4732`

Start it:

```bash
MIN_AGENT_TOKEN=minagt_… node packages/agent-kit/src/cli.js serve --port 4732
```

## List tools

```
GET /tools
Authorization: Bearer <token>
```

Response: `{ "ok": true, "tools": [{ "name", "description", "kind", "app", "inputSchema" }], "names": ["…"] }`

## Invoke a tool

```
POST /invoke
Authorization: Bearer <token>
Content-Type: application/json

{ "name": "list_movies", "arguments": { "query": "Heat" } }
```

`tool` is an alias for `name`. `args` / `input` are aliases for `arguments`.

Writes return `undoId`. Reverse with `{ "name": "undo", "arguments": { "undoId": "…" } }` or omit `undoId` to undo the latest write.

## Health

`GET /health` — no auth. `{ "ok": true, "service": "min-apps-agent" }`
