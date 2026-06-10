---
name: knowledge-sync
triggers: ["/knowledge-sync"]
description: >
  Bulk sync project documents to {{RAG_BACKEND}} collections.
  Incremental by default (MD5 hash comparison); full rebuild with --full;
  single collection with --collection <name>. Phase-change detection rebuilds
  the planning collection automatically.
---

# knowledge-sync — {{RAG_BACKEND}} Bulk Sync Skill

This skill is the on-demand reliable sync path. Most routine syncs are now
automatic via two deterministic checkpoints (see "Auto-sync architecture" below).
This skill is still the path for recovery (`--full`), single-collection
rebuilds, and any manual trigger.

Per D-B21: **PostToolUse nudges are best-effort**, not deterministic.
Per D-B11b (2026-04-10): **startup and post-commit auto-sync are deterministic.**

---

## Usage

- `/knowledge-sync` — incremental sync: scan watched paths, compare MD5 hashes, index only changed files
- `/knowledge-sync --full` — full re-index: wipe all 4 collections and re-index everything from scratch (use for recovery or initial setup)
- `/knowledge-sync --collection <name>` — sync a single collection only (reference | knowledge | planning | governance-ops)

---

## Sync Algorithm (incremental)

1. Read `config/{{rag_backend}}-registry.json` for current sync state (hashes, last_indexed timestamps)
2. For each collection, scan its watched paths (from `_meta.watched_paths` in the registry)
3. For each file found, compute MD5 hash:
   - macOS: `md5 -q <file>`
   - Linux: `md5sum <file>` (then extract the hex portion)
4. Compare hash with registry `collections.<name>.documents.<path>.hash`
5. If hash differs OR file not in registry:
   a. Read file content
   b. **Chunk** using markdown-header-aware strategy:
      - Split on `## ` (H2 headers) as primary boundaries
      - If a section exceeds 1000 chars, further split on `### ` (H3 headers)
      - If still exceeds 1000 chars, split on double-newlines (`\n\n`)
      - Target: ~1000 chars (~250 tokens) per chunk
      - Prepend header hierarchy as context prefix to each chunk (e.g., `[H2 title > H3 title]`)
   c. Delete existing chunks for that path: `chroma_delete_documents(collection_name, where={"path": "<relative_path>"})`
      (delete-then-add pattern prevents stale chunk accumulation — per Pitfall 6)
   d. Add new chunks: `chroma_add_documents(collection_name, documents=[chunks], ids=["<relative_path>::chunk-0", "<relative_path>::chunk-1", ...], metadatas=[{kind, path, section, chunk_index, last_modified}])`
   e. Update registry entry:
      ```json
      { "hash": "<new_md5>", "chunks": <count>, "last_indexed": "<ISO8601_UTC>" }
      ```
6. If a file is present in the registry but no longer on disk:
   - Delete from {{RAG_BACKEND}}: `chroma_delete_documents(collection_name, where={"path": "<relative_path>"})`
   - Remove from registry
7. Write updated `config/{{rag_backend}}-registry.json`
8. Report: `N files scanned, N changed, N indexed, N skipped, N deleted`

---

## Full Rebuild Algorithm

Use `/knowledge-sync --full` for recovery or when hashes are unreliable.

1. For each of the 4 collections:
   ```
   chroma_delete_collection(collection_name)
   chroma_create_collection(collection_name)
   ```
2. Reset all registry hashes and timestamps (clear the `documents` dict for each collection)
3. Run the incremental algorithm on the fresh empty state (all files will appear as "new")

---

## Phase-Change Detection (D-B8)

Run this check at the start of any sync when the planning collection is included.

1. Read `.planning/STATE.md` — extract the current phase number (look for `Current Phase:` or `Phase:` field)
2. Compare with `active_phase` in `config/{{rag_backend}}-registry.json`
3. If different (phase has changed):
   - Wipe the `planning` collection: `chroma_delete_collection("planning")` then `chroma_create_collection("planning")`
   - Re-index from the new phase's watched paths: `.planning/phases/{new-phase}/` + `memory/MEMORY.md`
   - Update `active_phase` in the registry to the new phase number
4. Other collections (reference, knowledge, governance-ops) are NOT affected by phase change
5. Log: `Phase changed: {old} → {new}. Planning collection rebuilt.`

---

## SUMMARY Indexing (D-B5)

Files matching `*SUMMARY*.md` under `.planning/phases/` are indexed to the `knowledge` collection
immediately on creation — not deferred to phase completion. This allows mid-phase plans to
reference earlier summaries via semantic search.

- Metadata `kind`: `"summary"`
- Collection: `knowledge`

This routing is enforced in the path matching logic and in the PostToolUse hook.

---

## Metadata Schemas (D-B10)

Each chunk is indexed with typed metadata for filtered queries. Always include an explicit
`kind` filter in `where` clauses — do not rely on semantic similarity to disambiguate types
(per D-B7).

### reference collection
```json
{
  "kind": "architecture|patterns|services|auth|brand|contract",
  "path": "relative/path.md",
  "last_modified": "ISO8601"
}
```

### knowledge collection
```json
{
  "kind": "lesson|decision|solution|summary",
  "path": "relative/path.md",
  "phase": "N",
  "last_modified": "ISO8601"
}
```

### planning collection
```json
{
  "kind": "plan|context|research|verification|memory",
  "path": "relative/path.md",
  "phase": "N",
  "wave": "N",
  "last_modified": "ISO8601"
}
```

### governance-ops collection
```json
{
  "kind": "standard|guide|procedure|register|risk|runbook",
  "path": "relative/path.md",
  "last_modified": "ISO8601"
}
```

---

## MCP Routing

- **Preferred:** `chroma-mcp`
- **Tools used:**
  - `chroma_add_documents` — index chunks
  - `chroma_delete_documents` — remove stale chunks (delete-then-add pattern)
  - `chroma_delete_collection` — full rebuild / phase-change wipe
  - `chroma_create_collection` — recreate after wipe
  - `chroma_count_documents` — verify indexing results
- **Fallback:** None — if chroma-mcp is unavailable, stop and report error
- **Reference:** `.claude/rules/tool-routing.md`

---

## Auto-sync Architecture (D-B11b, 2026-04-10)

Two deterministic checkpoints run `scripts/knowledge-sync.py` automatically, plus one best-effort nudge:

| Checkpoint | Mechanism | Scope | Blocks? |
|---|---|---|---|
| **Session startup** | `.claude/hooks/session-start.sh` after {{RAG_BACKEND}} healthcheck (source=startup only, not compact) | Incremental sync of anything changed since last sync | No — 20s soft cap, silent if clean |
| **Post-commit** | `.githooks/post-commit` detached background | Incremental sync after every `git commit` | No — hook returns <10ms |
| **PostToolUse** | `.claude/hooks/post-knowledge-sync.sh` queue + 10s idle flush | Nudge only — no sync mutation | Never — pure reminder (D-B21) |

**Concurrence :** All three share `/tmp/{{project}}-knowledge-sync.lock` (stale >60s = cleared). Only one sync runs at a time.

**When to invoke this skill manually :**
- `/knowledge-sync --full` — recovery after collection wipe, schema change, or registry corruption
- `/knowledge-sync --collection <name>` — rebuild a single collection (e.g., after deletion of stale chunks)
- `/knowledge-sync` incremental — on-demand when user explicitly asks, or when the startup/post-commit hooks are unavailable (fresh clone without `setup-hooks.sh`, {{RAG_BACKEND}} down, Python env missing)

## Honest Framing

- **PostToolUse is not sync** (D-B21 still valid) — it is a nudge/reminder queue. Never claim PostToolUse synced anything.
- **Startup and post-commit ARE deterministic** (D-B11b) — they actually call `scripts/knowledge-sync.py` and write to {{RAG_BACKEND}}.
- **"I just edited a file, is it in {{RAG_BACKEND}} yet?"** — No, unless you committed. The next `git commit` will sync it in the background. The next session-start will also catch it.
- **Never claim an auto-sync happened when the hook was skipped** ({{RAG_BACKEND}} down, lock held, chroma-mcp Python env missing) — check `.claude/workspace/knowledge-sync.log` for evidence.

---

## Error Handling

| Condition | Response |
|-----------|----------|
| {{RAG_BACKEND}} not reachable | Warn: "{{RAG_BACKEND}} not reachable at localhost:8000. Start with: `docker compose -f docker-compose.{{rag_backend}}.yml up -d`" |
| Empty collection after sync | Warn: "Collection `<name>` is empty after sync — check path configuration in `config/{{rag_backend}}-registry.json`" |
| Registry JSON missing | Offer to create from template using `config/{{rag_backend}}-registry.json` structure |
| File not readable | Skip with warning: "Skipped `<path>`: permission denied or read error" |
| jq not installed | Warn and fall back to Python3 for JSON parsing |
