import { mkdirSync, readFileSync, renameSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { randomBytes } from 'node:crypto';

const STORE_VERSION = 1;

export function emptyLibrary() {
  return {
    movies: [],
    podcasts: [],
    listeningHistory: [],
    channels: [],
    watchState: [],
    races: [],
    bikes: [],
    rides: [],
    timers: [],
    activeTimerId: null,
  };
}

export function emptyState() {
  return {
    version: STORE_VERSION,
    connections: [],
    undo: [],
    audit: [],
    library: emptyLibrary(),
  };
}

export function defaultHomeDir(env = process.env) {
  if (env.MIN_AGENT_HOME) return env.MIN_AGENT_HOME;
  const home = env.HOME || env.USERPROFILE || '.';
  return join(home, '.min-apps', 'agent');
}

export function storePath(homeDir) {
  return join(homeDir, 'state.json');
}

function atomicWrite(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${randomBytes(4).toString('hex')}.tmp`;
  writeFileSync(tmp, data, { encoding: 'utf8', mode: 0o600 });
  renameSync(tmp, filePath);
}

export class FileStore {
  constructor(homeDir = defaultHomeDir()) {
    this.homeDir = homeDir;
    this.filePath = storePath(homeDir);
    this.state = this.#load();
  }

  #load() {
    if (!existsSync(this.filePath)) return emptyState();
    try {
      const parsed = JSON.parse(readFileSync(this.filePath, 'utf8'));
      return {
        ...emptyState(),
        ...parsed,
        connections: parsed.connections ?? [],
        undo: parsed.undo ?? [],
        audit: parsed.audit ?? [],
        library: { ...emptyLibrary(), ...(parsed.library ?? {}) },
      };
    } catch {
      return emptyState();
    }
  }

  persist() {
    atomicWrite(this.filePath, `${JSON.stringify(this.state, null, 2)}\n`);
  }

  snapshot() {
    return structuredClone(this.state);
  }

  replaceLibrary(library) {
    this.state.library = { ...emptyLibrary(), ...library };
    this.persist();
  }

  mutate(mutator) {
    mutator(this.state);
    this.persist();
    return this.state;
  }
}
