/**
 * AgentDB MCP Thin Client
 *
 * Local-first semantic memory for Claude Code projects.
 * Writes entries as markdown files locally (git-tracked), then syncs to VPS.
 * If VPS is unavailable: entry is preserved locally, error logged, fallback keyword search used.
 *
 * Config: .agentdb/config.json (project root)
 * API key: AGENTDB_API_KEY env var
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { readFileSync, writeFileSync, mkdirSync, readdirSync, appendFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { createHash } from 'crypto';
import yaml from 'js-yaml';

// ─── Config ─────────────────────────────────────────────────────────────────

function findProjectRoot() {
  const envRoot = process.env.AGENTDB_PROJECT_ROOT;
  if (envRoot) return envRoot;
  let dir = process.cwd();
  for (let i = 0; i < 10; i++) {
    if (existsSync(join(dir, '.agentdb'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return process.cwd();
}

const PROJECT_ROOT = findProjectRoot();
const CONFIG_PATH = join(PROJECT_ROOT, '.agentdb', 'config.json');
const ENTRIES_DIR = join(PROJECT_ROOT, '.agentdb', 'entries');
const SYNC_ERROR_LOG = join(PROJECT_ROOT, '.agentdb', 'sync-errors.log');

function loadConfig() {
  if (!existsSync(CONFIG_PATH)) return {};
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    return {};
  }
}

const API_KEY = process.env.AGENTDB_API_KEY || '';

// ─── Slug + ID helpers ───────────────────────────────────────────────────────

function toSlug(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

// Deterministic UUID from slug — allows idempotent upsert on VPS
function slugToUUID(slug) {
  const hash = createHash('sha1').update('agentdb:' + slug).digest();
  hash[6] = (hash[6] & 0x0f) | 0x50; // version 5
  hash[8] = (hash[8] & 0x3f) | 0x80; // variant
  const h = hash.toString('hex');
  return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20,32)}`;
}

function entryId(domain, title) {
  const slug = `${toSlug(domain)}-${toSlug(title)}`;
  return { slug, uuid: slugToUUID(slug) };
}

// ─── Local file I/O ──────────────────────────────────────────────────────────

function ensureEntriesDir() {
  mkdirSync(ENTRIES_DIR, { recursive: true });
}

function writeEntryFile(slug, frontmatter, body) {
  ensureEntriesDir();
  const yamlBlock = yaml.dump(frontmatter, { lineWidth: 120 }).trim();
  const content = `---\n${yamlBlock}\n---\n\n${body.trim()}\n`;
  writeFileSync(join(ENTRIES_DIR, `${slug}.md`), content, 'utf8');
}

function readEntryFile(slug) {
  const path = join(ENTRIES_DIR, `${slug}.md`);
  if (!existsSync(path)) return null;
  return readFileSync(path, 'utf8');
}

function logSyncError(slug, error) {
  const line = `${new Date().toISOString()} [${slug}] ${error}\n`;
  try {
    appendFileSync(SYNC_ERROR_LOG, line);
  } catch {
    // best-effort
  }
}

// ─── VPS API calls ───────────────────────────────────────────────────────────

async function vpsPost(path, body, config) {
  const url = `${config.vps_url}${path}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-AgentDB-Key': API_KEY,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`VPS ${path} returned ${res.status}: ${text}`);
  }
  return res.json();
}

async function vpsGet(path, config) {
  const url = `${config.vps_url}${path}`;
  const res = await fetch(url, {
    headers: { 'X-AgentDB-Key': API_KEY },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`VPS GET ${path} returned ${res.status}`);
  return res.json();
}

async function vpsDelete(path, config) {
  const url = `${config.vps_url}${path}`;
  const res = await fetch(url, {
    method: 'DELETE',
    headers: { 'X-AgentDB-Key': API_KEY },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`VPS DELETE ${path} returned ${res.status}`);
  return res.json();
}

// ─── Keyword fallback search ─────────────────────────────────────────────────

function keywordSearch(query, domain, limit = 10) {
  if (!existsSync(ENTRIES_DIR)) return [];
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  const results = [];

  for (const file of readdirSync(ENTRIES_DIR)) {
    if (!file.endsWith('.md')) continue;
    try {
      const content = readFileSync(join(ENTRIES_DIR, file), 'utf8');
      const lower = content.toLowerCase();
      const matchCount = terms.filter((t) => lower.includes(t)).length;
      if (matchCount === 0) continue;

      // Extract frontmatter title and domain
      const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
      if (!match) continue;
      const fm = {};
      for (const line of match[1].split('\n')) {
        const m = line.match(/^(\w[\w-]*):\s*(.+)$/);
        if (m) fm[m[1].trim()] = m[2].trim().replace(/^['"]|['"]$/g, '');
      }
      if (domain && fm.domain !== domain) continue;

      results.push({
        id: file.replace('.md', ''),
        title: fm.title || file,
        domain: fm.domain || '',
        score: matchCount / terms.length,
        fallback: true,
      });
    } catch {
      // skip unreadable files
    }
  }

  return results.sort((a, b) => b.score - a.score).slice(0, limit);
}

// ─── Tool handlers ───────────────────────────────────────────────────────────

async function handleStore(args) {
  const { title, content, domain, classification, author, tags, date } = args;
  const config = loadConfig();
  const namespace = config.project_namespace || 'default';

  const { slug, uuid } = entryId(domain, title);
  const today = new Date().toISOString().slice(0, 10);

  const frontmatter = {
    title,
    domain,
    classification,
    date: date || today,
    author: author || '',
    tags: tags || [],
    _id: uuid,
  };

  // Step 1: Write locally (must succeed — source of truth)
  writeEntryFile(slug, frontmatter, content);

  // Step 2: Sync to VPS (best-effort, 10s timeout)
  let synced = false;
  let syncError = null;

  if (config.vps_url) {
    const namespaces = [namespace];
    if (classification === 'cross-project' || classification === 'cross-projet') {
      namespaces.push('global');
    }

    for (const ns of namespaces) {
      try {
        await vpsPost('/entries', {
          id: uuid,
          title,
          content,
          domain,
          classification,
          date: frontmatter.date,
          author: frontmatter.author,
          tags: frontmatter.tags,
          namespace: ns,
        }, config);
        synced = true;
      } catch (err) {
        syncError = err.message;
        logSyncError(slug, `namespace=${ns} ${err.message}`);
      }
    }
  } else {
    syncError = 'No VPS configured — local only';
  }

  return {
    id: slug,
    namespace,
    file: `.agentdb/entries/${slug}.md`,
    synced,
    ...(syncError && !synced ? { sync_error: syncError } : {}),
  };
}

async function handleSearch(args) {
  const { query, domain, scope, min_score, limit } = args;
  const config = loadConfig();

  // Try VPS semantic search first
  if (config.vps_url) {
    try {
      const results = await vpsPost('/search', {
        query,
        namespace: config.project_namespace || 'default',
        scope: scope || config.default_scope || 'project',
        min_score: min_score ?? config.default_min_score ?? 0.6,
        limit: limit || 10,
        ...(domain ? { domain } : {}),
      }, config);
      return results;
    } catch (err) {
      logSyncError('search', err.message);
      // Fall through to keyword fallback
    }
  }

  // Fallback: keyword search on local files
  const results = keywordSearch(query, domain, limit || 10);
  return results.length > 0
    ? results
    : [{ _note: 'VPS unavailable and no local keyword matches found.' }];
}

async function handleList(args) {
  const { domain, limit } = args;
  const config = loadConfig();

  if (config.vps_url) {
    try {
      const ns = config.project_namespace || 'default';
      const qs = new URLSearchParams({ namespace: ns, limit: String(limit || 50) });
      if (domain) qs.set('domain', domain);
      return await vpsGet(`/entries?${qs}`, config);
    } catch {
      // Fall through to local
    }
  }

  // Local fallback
  if (!existsSync(ENTRIES_DIR)) return [];
  const files = readdirSync(ENTRIES_DIR).filter((f) => f.endsWith('.md'));
  return files.map((f) => ({ id: f.replace('.md', ''), local: true }));
}

async function handleDelete(args) {
  const { id } = args;
  const config = loadConfig();
  const ns = config.project_namespace || 'default';

  if (config.vps_url) {
    await vpsDelete(`/entries/${id}?namespace=${ns}`, config);
  }

  return { deleted: id };
}

async function handleDebug(args) {
  const { query } = args;
  const config = loadConfig();
  if (!config.vps_url) return { error: 'No VPS configured' };

  const ns = config.project_namespace || 'default';
  return vpsPost('/debug', { query, namespace: ns }, config);
}

// ─── MCP Server ──────────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: 'agentdb_store',
    description:
      'Store a lesson or pattern in AgentDB. Writes locally (git-tracked) and syncs to VPS. ' +
      'classification: "project" | "reusable" | "cross-project".',
    inputSchema: {
      type: 'object',
      required: ['title', 'content', 'domain', 'classification'],
      properties: {
        title: { type: 'string', description: 'Short descriptive title' },
        content: { type: 'string', description: 'Full markdown content (problem, solution, anti-patterns)' },
        domain: { type: 'string', description: 'Domain: performance, security, architecture, etc.' },
        classification: { type: 'string', enum: ['project', 'reusable', 'cross-project'] },
        author: { type: 'string' },
        tags: { type: 'array', items: { type: 'string' } },
        date: { type: 'string', description: 'ISO date (defaults to today)' },
      },
    },
  },
  {
    name: 'agentdb_search',
    description: 'Semantic search over stored patterns. Falls back to keyword search if VPS is unavailable.',
    inputSchema: {
      type: 'object',
      required: ['query'],
      properties: {
        query: { type: 'string' },
        domain: { type: 'string', description: 'Filter by domain' },
        scope: { type: 'string', enum: ['project', 'global', 'all'], default: 'project' },
        min_score: { type: 'number', default: 0.6 },
        limit: { type: 'integer', default: 10 },
      },
    },
  },
  {
    name: 'agentdb_list',
    description: 'List entries in the project namespace.',
    inputSchema: {
      type: 'object',
      properties: {
        domain: { type: 'string' },
        limit: { type: 'integer', default: 50 },
      },
    },
  },
  {
    name: 'agentdb_delete',
    description: 'Delete an entry by ID (slug or UUID).',
    inputSchema: {
      type: 'object',
      required: ['id'],
      properties: {
        id: { type: 'string' },
      },
    },
  },
  {
    name: 'agentdb_debug',
    description: 'Return raw similarity scores for a query (diagnostic tool). Useful to verify embedding quality.',
    inputSchema: {
      type: 'object',
      required: ['query'],
      properties: {
        query: { type: 'string' },
      },
    },
  },
];

const server = new Server(
  { name: 'agentdb', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  try {
    let result;
    if (name === 'agentdb_store') result = await handleStore(args);
    else if (name === 'agentdb_search') result = await handleSearch(args);
    else if (name === 'agentdb_list') result = await handleList(args);
    else if (name === 'agentdb_delete') result = await handleDelete(args);
    else if (name === 'agentdb_debug') result = await handleDebug(args);
    else throw new Error(`Unknown tool: ${name}`);

    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    return {
      content: [{ type: 'text', text: `Error: ${err.message}` }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
