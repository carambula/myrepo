import { randomBytes } from 'node:crypto';
import { AgentError, UNDO_TTL_MS } from './protocol.js';

export function createUndoRecord({
  connectionId,
  tool,
  app,
  before,
  after,
  summary,
  now = new Date(),
}) {
  return {
    id: `undo_${randomBytes(8).toString('hex')}`,
    connectionId,
    tool,
    app,
    before: structuredClone(before ?? null),
    after: structuredClone(after ?? null),
    summary,
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + UNDO_TTL_MS).toISOString(),
    undoneAt: null,
  };
}

export function usableUndoRecords(records, { now = new Date(), connectionId } = {}) {
  return records.filter((record) => {
    if (record.undoneAt) return false;
    if (new Date(record.expiresAt).getTime() <= now.getTime()) return false;
    if (connectionId && record.connectionId !== connectionId) return false;
    return true;
  });
}

export function pickUndoRecord(records, { undoId, connectionId, now = new Date() } = {}) {
  const usable = usableUndoRecords(records, { now, connectionId });
  if (undoId) {
    const record = records.find((item) => item.id === undoId);
    if (!record) {
      throw new AgentError('undo_not_found', `No undo record "${undoId}".`, 404);
    }
    if (connectionId && record.connectionId !== connectionId) {
      throw new AgentError('forbidden', 'That undo record belongs to a different agent connection.', 403);
    }
    if (record.undoneAt) {
      throw new AgentError('already_undone', 'That change was already undone.');
    }
    if (new Date(record.expiresAt).getTime() <= now.getTime()) {
      throw new AgentError('undo_expired', 'That undo window has expired (records last 7 days).');
    }
    return record;
  }
  if (!usable.length) {
    throw new AgentError('nothing_to_undo', 'There is nothing left to undo.');
  }
  return usable[usable.length - 1];
}

export function markUndone(record, now = new Date()) {
  return { ...record, undoneAt: now.toISOString() };
}
