---
name: min-apps-agent
description: Call min apps (mov/pod) through the public Min Cloud agent HTTP API. Use when listing or changing watched movies or followed podcasts from a VM or remote agent.
---

# Min apps agent HTTP

Base URL (reachable from a VM):

`https://min-cloud-production.up.railway.app`

Same hashed `minagt_…` bearer token as the local MCP kit.

## List tools

```
GET /tools
Authorization: Bearer <token>
```

## Invoke a tool

```
POST /invoke
Authorization: Bearer <token>
Content-Type: application/json

{ "name": "list_movies", "arguments": { "query": "Heat" } }
```

`tool` aliases `name`. `args` / `input` alias `arguments`. Writes return `undoId`.

Mint a token (once) as the signed-in user:

```
POST /v1/agent/connections
Authorization: Bearer <min-cloud session>
{ "name": "VM agent" }
```

Or as admin: `POST /v1/admin/agent/connections` with `x-admin-token` and `{ "email": "you@…" }`.

Local loopback (`http://127.0.0.1:4732`) still works if you run `packages/agent-kit` `serve` on the same machine.
