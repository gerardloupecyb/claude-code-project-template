#!/usr/bin/env node
/**
 * AgentDB Reindex Script
 *
 * Reads all .md files in .agentdb/entries/ and pushes them to the VPS.
 * Use after VPS was down or when bootstrapping a fresh VPS with existing entries.
 *
 * Usage:
 *   node scripts/agentdb-reindex.sh [--namespace <ns>] [--dry-run] [--reset]
 *
 * Options:
 *   --namespace <ns>  Override project namespace from config.json
 *   --dry-run         Parse and log entries without pushing to VPS
 *   --reset           Drop + recreate namespace on VPS before pushing (POST /reindex)
 *
 * Requirements:
 *   - Node.js 18+ (uses built-in fetch)
 *   - AGENTDB_API_KEY env var
 *   - .agentdb/config.json in project root (or AGENTDB_PROJECT_ROOT env var)
 */

'use strict';

import { readFileSync, readdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createHash } from 'crypto';

// ─── Args ─────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const doReset = args.includes('--reset');
const nsOverride = (() => {
  const i = args.indexOf('--namespace');
  return i !== -1 ? args[i + 1] : null;
})();

// ─── Project root ─────────────────────────────────────────────────────────────

function findProjectRoot() {
  const envRoot = process.env.AGENTDB_PROJECT_ROOT;
  if (envRoot) return envRoot;
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  let dir = dirname(scriptDir); // one level up from scripts/
  for (let i = 0; i < 8; i++) {
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

// ─── Config ───────────────────────────────────────────────────────────────────

if (!existsSync(CONFIG_PATH)) {
  console.error(`Error: config.json not found at ${CONFIG_PATH}`);
  console.error('Copy .agentdb/config.json.template to .agentdb/config.json and fill in vps_url.');
  process.exit(1);
}

const config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
const VPS_URL = config.vps_url;
const NAMESPACE = nsOverride || config.project_namespace || 'default';
const API_KEY = process.env.AGENTDB_API_KEY || '';

if (!VPS_URL) {
  console.error('Error: vps_url not set in .agentdb/config.json');
  process.exit(1);
}
if (!API_KEY && !isDryRun) {
  console.error('Error: AGENTDB_API_KEY env var not set');
  process.exit(1);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return { frontmatter: {}, body: content };
  const fm = {};
  for (const line of match[1].split('\n')) {
    const m = line.match(/^([\w-]+):\s*(.+)$/);
    if (!m) continue;
    let v = m[2].trim();
    if (v.startsWith('[') && v.endsWith(']')) {
      v = v.slice(1, -1).split(',').map((s) => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
    } else {
      v = v.replace(/^['"]|['"]$/g, '');
    }
    fm[m[1].trim()] = v;
  }
  const body = content.slice(match[0].length).trimStart();
  return { frontmatter: fm, body };
}

function slugToUUID(slug) {
  const hash = createHash('sha1').update('agentdb:' + slug).digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const h = hash.toString('hex');
  return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20,32)}`;
}

async function apiCall(method, path, body) {
  const res = await fetch(`${VPS_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-AgentDB-Key': API_KEY,
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${method} ${path} → ${res.status}: ${text}`);
  }
  return res.json();
}

// ─── Main ─────────────────────────────────────────────────────────────────────

if (!existsSync(ENTRIES_DIR)) {
  console.log(`No entries directory found at ${ENTRIES_DIR}. Nothing to reindex.`);
  process.exit(0);
}

const files = readdirSync(ENTRIES_DIR).filter((f) => f.endsWith('.md'));
console.log(`Found ${files.length} entries in ${ENTRIES_DIR}`);
console.log(`Target: ${VPS_URL}  namespace: ${NAMESPACE}`);
if (isDryRun) console.log('DRY RUN — no VPS calls');
if (doReset && !isDryRun) console.log('--reset: will drop + recreate namespace collection');

if (doReset && !isDryRun) {
  process.stdout.write(`Resetting namespace "${NAMESPACE}"... `);
  await apiCall('POST', '/reindex', { namespace: NAMESPACE });
  console.log('done');
}

let ok = 0;
let failed = 0;

for (const file of files) {
  const slug = file.replace('.md', '');
  const content = readFileSync(join(ENTRIES_DIR, file), 'utf8');
  const { frontmatter: fm, body } = parseFrontmatter(content);

  if (!fm.title) {
    console.warn(`  SKIP ${file} — no title in frontmatter`);
    continue;
  }

  const id = fm._id || slugToUUID(slug);
  const entry = {
    id,
    title: fm.title,
    content: body,
    domain: fm.domain || 'general',
    classification: fm.classification || 'project',
    date: fm.date || '',
    author: fm.author || '',
    tags: Array.isArray(fm.tags) ? fm.tags : [],
    namespace: NAMESPACE,
  };

  if (isDryRun) {
    console.log(`  DRY ${slug}  id=${id}  domain=${entry.domain}`);
    ok++;
    continue;
  }

  try {
    process.stdout.write(`  PUSH ${slug}... `);
    await apiCall('POST', '/entries', entry);
    console.log('ok');

    // Also push to global namespace if cross-project
    const cls = String(fm.classification || '');
    if (cls === 'cross-project' || cls === 'cross-projet') {
      process.stdout.write(`       → global... `);
      await apiCall('POST', '/entries', { ...entry, namespace: 'global' });
      console.log('ok');
    }

    ok++;
  } catch (err) {
    console.log(`FAILED: ${err.message}`);
    failed++;
  }
}

console.log(`\nDone: ${ok} pushed, ${failed} failed`);
if (failed > 0) process.exit(1);
