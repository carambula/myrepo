# Min Apps Agent Kit

Shared protocol so an agent can connect to every min app with **read** and/or **write** access.

| App | Tools |
|-----|--------|
| **mov min** (WatchedIt) | List / search movies, save, mark rewatched, mark listened |
| **pod min** (PodLink) | List follows and listening history, follow / unfollow |
| **vid min** (YourTube) | List subscriptions, subscribe, watch state |
| **cyc min** (Cyclismo) | List races, set saved / watched / listened |
| **spin min** (SpinMin) | List bikes and rides, log a ride, calculate pressure |
| **fit min** | List / create / start / delete timers |

Writes are reversible for **7 days** (`undo`, `list_undo_history`). Tokens are stored as SHA-256 hashes and can be revoked. Destructive deletes require `confirm=true`.

## Connect an agent

```bash
node packages/agent-kit/src/cli.js init --name "My agent"
```

Copy the `minagt_…` token (it is shown once) into your MCP config:

```json
{
  "mcpServers": {
    "min-apps": {
      "command": "node",
      "args": ["packages/agent-kit/src/cli.js", "mcp"],
      "env": {
        "MIN_AGENT_TOKEN": "minagt_…"
      }
    }
  }
}
```

Or run the local HTTP gateway and console (loopback only):

```bash
MIN_AGENT_TOKEN=minagt_… node packages/agent-kit/src/cli.js serve --port 4732
```

Open `http://127.0.0.1:4732`, paste the token, and call tools. Undo is one click.

Read-only connection:

```bash
node packages/agent-kit/src/cli.js init --name "Reader" --read-only
```

Limit apps:

```bash
node packages/agent-kit/src/cli.js init --name "Movies" --apps mov,pod
```

## Library import

On-device apps can copy a library snapshot from **Account → Agents**. Import it into the Mac gateway:

```bash
node packages/agent-kit/src/cli.js import-library ~/Downloads/mov-min-library.json
```

## Security

- Tokens are hashed at rest. Revoke from the CLI (`min-agent revoke <id>`) or the in-app Agents screen.
- The HTTP server binds to `127.0.0.1` by default.
- Audit logs never store tokens.
- Every write emits an undo record owned by that connection.

## Tests

```bash
npm test --workspace=@min-apps/agent-kit
```
