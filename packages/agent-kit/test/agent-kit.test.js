import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createConnection, findConnectionByToken, hashToken } from '../src/auth.js';
import { AgentGateway } from '../src/gateway.js';
import { createAgentHttpServer } from '../src/http.js';
import { createMcpServer } from '../src/mcp.js';
import { AgentError, allScopes, toolsForScopes } from '../src/protocol.js';
import { FileStore, emptyLibrary } from '../src/store.js';

function tempStore(library = emptyLibrary()) {
  const dir = mkdtempSync(join(tmpdir(), 'min-agent-'));
  const store = new FileStore(dir);
  store.state.library = { ...emptyLibrary(), ...library };
  const { connection, token } = createConnection({ name: 'Test agent' });
  store.state.connections.push(connection);
  store.persist();
  return { store, token, connection, dir, gateway: new AgentGateway(store) };
}

test('tokens are hashed and never stored in the clear', () => {
  const { connection, token } = createConnection({ name: 'Hash check' });
  assert.ok(token.startsWith('minagt_'));
  assert.equal(connection.tokenHash, hashToken(token));
  assert.ok(!JSON.stringify(connection).includes(token.slice(10)));
  assert.equal(findConnectionByToken([connection], token).id, connection.id);
  assert.equal(findConnectionByToken([connection], 'minagt_nope'), null);
});

test('read-only scopes hide write tools', () => {
  const readOnly = allScopes({ write: false });
  const names = toolsForScopes(readOnly).map((tool) => tool.name);
  assert.ok(names.includes('list_movies'));
  assert.ok(names.includes('list_podcasts'));
  assert.ok(names.includes('list_timers'));
  assert.ok(!names.includes('set_movie_saved'));
  assert.ok(!names.includes('follow_podcast'));
  assert.ok(!names.includes('create_timer'));
});

test('agent can list and save movies, then undo', async () => {
  const { gateway, token } = tempStore({
    movies: [
      { id: 'tmdb-123', title: 'Heat', year: 1995, tmdbId: 123, isSaved: false, isRewatched: true, isListened: false },
      { id: 'tmdb-9', title: 'The Matrix', year: 1999, tmdbId: 9, isSaved: true, isRewatched: false, isListened: false },
    ],
  });

  const listed = await gateway.call(token, 'list_movies', {});
  assert.equal(listed.total, 2);
  assert.ok(listed.movies.some((movie) => movie.title === 'Heat'));

  const saved = await gateway.call(token, 'set_movie_saved', { title: 'Heat', saved: true });
  assert.equal(saved.movie.isSaved, true);
  assert.ok(saved.undoId);

  const after = await gateway.call(token, 'list_movies', { saved: true });
  assert.ok(after.movies.some((movie) => movie.title === 'Heat'));

  const undone = await gateway.call(token, 'undo', { undoId: saved.undoId });
  assert.equal(undone.undone.id, saved.undoId);

  const restored = await gateway.call(token, 'get_movie', { title: 'Heat' });
  assert.equal(restored.movie.isSaved, false);
});

test('upsert adds a missing movie and marks it saved', async () => {
  const { gateway, token } = tempStore();
  const created = await gateway.call(token, 'upsert_movie', { title: 'Arrival', year: 2016, saved: true });
  assert.equal(created.created, true);
  assert.equal(created.movie.isSaved, true);
  const found = await gateway.call(token, 'search_movies', { query: 'arrival' });
  assert.equal(found.total, 1);
});

test('podcast follow, listen, and unfollow are reversible', async () => {
  const { gateway, token } = tempStore();
  const followed = await gateway.call(token, 'follow_podcast', {
    title: 'The Rewatchables',
    feedURL: 'https://example.com/rewatchables.xml',
    author: 'The Ringer',
  });
  assert.equal(followed.podcast.isFollowed, true);

  await gateway.call(token, 'record_podcast_listen', {
    episodeTitle: 'Heat',
    podcastTitle: 'The Rewatchables',
    isPlayed: true,
  });
  const history = await gateway.call(token, 'list_listening_history', {});
  assert.equal(history.total, 1);

  const unfollowed = await gateway.call(token, 'unfollow_podcast', { title: 'Rewatchables' });
  assert.equal(unfollowed.podcast.isFollowed, false);
  await gateway.call(token, 'undo', { undoId: unfollowed.undoId });
  const library = await gateway.call(token, 'list_podcasts', {});
  assert.equal(library.podcasts[0].isFollowed, true);
});

test('timer create, start, and confirmed delete undo back', async () => {
  const { gateway, token } = tempStore();
  const created = await gateway.call(token, 'create_timer', {
    title: 'Tabata',
    reps: 8,
    workSeconds: 20,
    restSeconds: 10,
  });
  assert.equal(created.timer.title, 'Tabata');

  const started = await gateway.call(token, 'start_timer', { title: 'Tabata' });
  assert.equal(started.started, true);

  await assert.rejects(
    () => gateway.call(token, 'delete_timer', { title: 'Tabata', confirm: false }),
    (error) => error instanceof AgentError && error.code === 'confirmation_required'
  );

  const deleted = await gateway.call(token, 'delete_timer', { title: 'Tabata', confirm: true });
  assert.equal(deleted.deleted.title, 'Tabata');
  await gateway.call(token, 'undo', { undoId: deleted.undoId });
  const listed = await gateway.call(token, 'list_timers', {});
  assert.equal(listed.timers.length, 1);
});

test('write is rejected without write scope', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'min-agent-'));
  const store = new FileStore(dir);
  const { connection, token } = createConnection({
    name: 'Reader',
    scopes: allScopes({ write: false }),
  });
  store.state.connections.push(connection);
  store.persist();
  const gateway = new AgentGateway(store);
  await assert.rejects(
    () => gateway.call(token, 'set_movie_saved', { title: 'Heat', saved: true }),
    (error) => error instanceof AgentError && error.code === 'forbidden'
  );
  const who = await gateway.call(token, 'whoami', {});
  assert.ok(who.scopes.includes('mov.read'));
  assert.ok(!who.scopes.includes('mov.write'));
});

test('revoked tokens cannot call tools', async () => {
  const { gateway, token, connection, store } = tempStore();
  connection.revokedAt = new Date().toISOString();
  store.persist();
  await assert.rejects(
    () => gateway.call(token, 'whoami', {}),
    (error) => error instanceof AgentError && error.code === 'revoked'
  );
});

test('audit log redacts secrets and records undo ids', async () => {
  const { gateway, token } = tempStore({
    movies: [{ id: '1', title: 'Heat', year: 1995, isSaved: false, isRewatched: false, isListened: false }],
  });
  const saved = await gateway.call(token, 'set_movie_saved', { title: 'Heat', saved: true, token: 'should-hide' });
  const log = await gateway.call(token, 'list_audit_log', {});
  const write = log.audit.find((entry) => entry.tool === 'set_movie_saved');
  assert.equal(write.ok, true);
  assert.equal(write.undoId, saved.undoId);
  assert.equal(write.input.token, '[redacted]');
  assert.ok(!JSON.stringify(log).includes('should-hide'));
});

test('HTTP gateway requires a bearer token and executes tools', async () => {
  const { gateway, token } = tempStore({
    movies: [{ id: '1', title: 'Heat', year: 1995, isSaved: false, isRewatched: true, isListened: false }],
  });
  const http = createAgentHttpServer(gateway, { host: '127.0.0.1', port: 0 });
  await new Promise((resolve) => http.server.listen(0, '127.0.0.1', resolve));
  const { port } = http.server.address();
  after(async () => {
    await http.close();
  });

  const consolePage = await fetch(`http://127.0.0.1:${port}/`);
  assert.equal(consolePage.status, 200);
  assert.match(await consolePage.text(), /Min Apps Agent/);

  const denied = await fetch(`http://127.0.0.1:${port}/v1/whoami`);
  assert.equal(denied.status, 401);

  const ok = await fetch(`http://127.0.0.1:${port}/v1/tools/set_movie_saved`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Heat', saved: true }),
  });
  assert.equal(ok.status, 200);
  const body = await ok.json();
  assert.equal(body.movie.isSaved, true);
  assert.ok(body.undoId);
});

test('MCP tools/list and tools/call honor the connection token', async () => {
  const { gateway, token } = tempStore({
    movies: [{ id: '1', title: 'Heat', year: 1995, isSaved: false, isRewatched: false, isListened: false }],
  });
  const messages = [];
  const fakeOut = { write: (chunk) => messages.push(Buffer.from(chunk).toString('utf8')) };
  const mcp = createMcpServer({
    gateway,
    token,
    stdin: { on() {} },
    stdout: fakeOut,
  });

  await mcp.handle({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} });
  await mcp.handle({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
  await mcp.handle({
    jsonrpc: '2.0',
    id: 3,
    method: 'tools/call',
    params: { name: 'set_movie_saved', arguments: { title: 'Heat', saved: true } },
  });

  const parsed = messages.map((line) => JSON.parse(line.trim()));
  const list = parsed.find((message) => message.id === 2);
  assert.ok(list.result.tools.some((tool) => tool.name === 'set_movie_saved'));
  const call = parsed.find((message) => message.id === 3);
  assert.equal(JSON.parse(call.result.content[0].text).movie.isSaved, true);
});

test('ambiguous movie titles ask for disambiguation instead of writing', async () => {
  const { gateway, token } = tempStore({
    movies: [
      { id: 'a', title: 'Dune', year: 1984, isSaved: false, isRewatched: false, isListened: false },
      { id: 'b', title: 'Dune', year: 2021, isSaved: false, isRewatched: false, isListened: false },
    ],
  });
  await assert.rejects(
    () => gateway.call(token, 'set_movie_saved', { title: 'Dune', saved: true }),
    (error) => error instanceof AgentError && error.code === 'ambiguous'
  );
  const saved = await gateway.call(token, 'set_movie_saved', { title: 'Dune', year: 2021, saved: true });
  assert.equal(saved.movie.year, 2021);
});

test('library import persists across store reload', () => {
  const dir = mkdtempSync(join(tmpdir(), 'min-agent-'));
  const path = join(dir, 'library.json');
  writeFileSync(path, JSON.stringify({
    movies: [{ id: '1', title: 'Heat', year: 1995, isSaved: true, isRewatched: true, isListened: false }],
  }));
  const first = new FileStore(dir);
  first.replaceLibrary(JSON.parse(readFileSync(path, 'utf8')));
  const second = new FileStore(dir);
  assert.equal(second.state.library.movies[0].title, 'Heat');
});
