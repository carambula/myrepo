import { createAuditEntry } from './audit.js';
import { assertActiveConnection, assertScopes, findConnectionByToken, redactConnection } from './auth.js';
import { APPS, AgentError, TOOLS, expandScopes, toolByName, toolsForScopes } from './protocol.js';
import { createUndoRecord, markUndone, pickUndoRecord, usableUndoRecords } from './undo.js';
import { revertWrite, toolHandlers } from './tools.js';

const MAX_AUDIT = 500;
const MAX_UNDO = 200;

export class AgentGateway {
  constructor(store) {
    this.store = store;
  }

  authenticate(token) {
    const connection = findConnectionByToken(this.store.state.connections, token);
    return assertActiveConnection(connection);
  }

  whoami(connection) {
    return {
      connection: redactConnection(connection),
      apps: Object.values(APPS),
      scopes: expandScopes(connection.scopes),
      tools: toolsForScopes(connection.scopes).map((tool) => tool.name),
    };
  }

  listCapabilities(connection) {
    const allowed = toolsForScopes(connection.scopes);
    const byApp = {};
    for (const tool of allowed) {
      const key = tool.app || 'meta';
      byApp[key] ??= [];
      byApp[key].push({
        name: tool.name,
        kind: tool.kind,
        description: tool.description,
        inputSchema: tool.inputSchema,
      });
    }
    return { tools: allowed.map((tool) => tool.name), byApp };
  }

  async call(token, name, input = {}) {
    const connection = this.authenticate(token);
    this.#touch(connection);
    const tool = toolByName(name);
    if (!tool) {
      this.#audit(connection, name, null, input, false, 'unknown_tool');
      throw new AgentError('unknown_tool', `Unknown tool "${name}".`, 404);
    }
    try {
      assertScopes(connection, tool.scopes);
      const output = this.#dispatch(connection, tool, input ?? {});
      this.#audit(connection, tool.name, tool.app, input, true, null, output.undoId);
      return output;
    } catch (error) {
      const code = error instanceof AgentError ? error.code : 'error';
      this.#audit(connection, tool.name, tool.app, input, false, error.message);
      throw error;
    }
  }

  #dispatch(connection, tool, input) {
    if (tool.name === 'whoami') {
      return { ok: true, ...this.whoami(connection) };
    }
    if (tool.name === 'list_capabilities') {
      return { ok: true, ...this.listCapabilities(connection) };
    }
    if (tool.name === 'list_undo_history') {
      const limit = input.limit ?? 20;
      const records = [...this.store.state.undo]
        .filter((record) => record.connectionId === connection.id)
        .slice(-limit)
        .reverse()
        .map((record) => ({
          id: record.id,
          tool: record.tool,
          app: record.app,
          summary: record.summary,
          createdAt: record.createdAt,
          expiresAt: record.expiresAt,
          undoneAt: record.undoneAt,
        }));
      return { ok: true, undo: records };
    }
    if (tool.name === 'list_audit_log') {
      const limit = input.limit ?? 25;
      let entries = this.store.state.audit.filter((entry) => entry.connectionId === connection.id);
      if (input.app) entries = entries.filter((entry) => entry.app === input.app);
      return { ok: true, audit: entries.slice(-limit).reverse() };
    }
    if (tool.name === 'undo') {
      return this.#undo(connection, input);
    }

    const handler = toolHandlers[tool.name];
    if (!handler) {
      throw new AgentError('not_implemented', `Tool "${tool.name}" is not implemented.`);
    }

    const library = this.store.state.library;
    const output = handler(library, input) ?? {};
    let undoId = null;
    if (tool.kind === 'write') {
      const record = createUndoRecord({
        connectionId: connection.id,
        tool: tool.name,
        app: tool.app,
        before: output.before,
        after: output.after,
        summary: output.summary || tool.name,
      });
      this.store.state.undo.push(record);
      if (this.store.state.undo.length > MAX_UNDO) {
        this.store.state.undo = this.store.state.undo.slice(-MAX_UNDO);
      }
      undoId = record.id;
    }
    this.store.persist();
    return {
      ok: true,
      ...(output.result ? output.result : output),
      ...(output.summary ? { summary: output.summary } : {}),
      ...(undoId ? { undoId } : {}),
    };
  }

  #undo(connection, input) {
    const record = pickUndoRecord(this.store.state.undo, {
      undoId: input.undoId,
      connectionId: connection.id,
    });
    revertWrite(this.store.state.library, record);
    const index = this.store.state.undo.findIndex((item) => item.id === record.id);
    this.store.state.undo[index] = markUndone(record);
    this.store.persist();
    return {
      ok: true,
      undone: {
        id: record.id,
        tool: record.tool,
        app: record.app,
        summary: record.summary,
      },
    };
  }

  #touch(connection) {
    connection.lastUsedAt = new Date().toISOString();
  }

  #audit(connection, tool, app, input, ok, error, undoId) {
    this.store.state.audit.push(createAuditEntry({
      connectionId: connection.id,
      connectionName: connection.name,
      tool,
      app,
      input,
      ok,
      error,
      undoId,
    }));
    if (this.store.state.audit.length > MAX_AUDIT) {
      this.store.state.audit = this.store.state.audit.slice(-MAX_AUDIT);
    }
    this.store.persist();
  }

  pendingUndoCount(connectionId) {
    return usableUndoRecords(this.store.state.undo, { connectionId }).length;
  }
}

export { TOOLS };
