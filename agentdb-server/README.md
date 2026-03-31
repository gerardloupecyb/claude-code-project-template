# agentdb-server

VPS-side stack for AgentDB: Qdrant vector DB + HuggingFace embedding service + REST API.

## Architecture

```
agentdb-api (Node.js, port 3100)  ←  Traefik HTTPS routing
    ↓  POST /embed
embedding (HuggingFace TEI, CPU)  — nomic-embed-text-v1.5 (768 dims)
    ↓  upsert/search
qdrant (v1.9.0)                   — vector store, one collection per namespace
```

## VPS Deployment

```bash
# 1. Copy to VPS
scp -r agentdb-server/ root@srv1235849.hstgr.cloud:/docker/agentdb/

# 2. On VPS
cd /docker/agentdb
cp .env.template .env
# Edit .env — set AGENTDB_API_KEY (openssl rand -hex 32)

# 3. Verify Traefik network exists
docker network ls | grep n8n_default

# 4. Start
docker compose up -d

# 5. Verify
curl https://agentdb.srv1235849.hstgr.cloud/health
```

## API Endpoints

All endpoints (except `/health`) require `X-AgentDB-Key: <key>` header.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/entries` | Embed + store an entry |
| `POST` | `/search` | Semantic search |
| `GET` | `/entries?namespace=` | List entries |
| `DELETE` | `/entries/:id?namespace=` | Delete entry |
| `POST` | `/reindex` | Drop + recreate a namespace collection |
| `POST` | `/debug` | Raw similarity scores for diagnostics |
| `GET` | `/health` | Liveness check |

### POST /entries

```json
{
  "title": "N+1 query on invoices",
  "content": "## Problème\n...\n## Solution\n...",
  "domain": "performance",
  "classification": "reusable",
  "namespace": "project-alpha",
  "date": "2026-03-31",
  "author": "gerard",
  "tags": ["n+1", "activerecord"],
  "id": "optional-uuid-for-idempotent-upsert"
}
```

### POST /search

```json
{
  "query": "N+1 query eager loading",
  "namespace": "project-alpha",
  "scope": "project",
  "min_score": 0.6,
  "limit": 10,
  "domain": "performance"
}
```

`scope` values: `"project"` (default), `"global"`, `"all"` (both).

### POST /reindex

```json
{ "namespace": "project-alpha" }
```

Drops and recreates the Qdrant collection. Run `scripts/agentdb-reindex.sh` afterward to re-push all local entries.

### POST /debug

```json
{ "query": "retry pattern", "namespace": "project-alpha" }
```

Returns raw scores for all matching entries (no threshold). Use to diagnose search quality.

## Traefik Integration

The `agentdb-api` container joins the `n8n_default` external network (where Traefik lives).
Set `TRAEFIK_NETWORK` in `.env` if your Traefik network has a different name.

The cert resolver `letsencrypt` and entrypoint `websecure` match the existing n8n stack config.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AGENTDB_API_KEY` | Yes | Shared secret for all MCP clients |
| `AGENTDB_HOST` | Yes | Public hostname (e.g. `agentdb.srv1235849.hstgr.cloud`) |
| `TRAEFIK_NETWORK` | No | Default: `n8n_default` |
| `TRAEFIK_ENTRYPOINT` | No | Default: `websecure` |
| `TRAEFIK_CERT_RESOLVER` | No | Default: `letsencrypt` |

## Notes

- First startup downloads the embedding model (~270MB). Subsequent starts are fast (cached in Docker volume).
- Qdrant data persists in the `qdrant_data` Docker volume. Do not use `docker compose down -v`.
- Each project gets its own Qdrant collection (namespace). Cross-project entries go in the `global` collection.
