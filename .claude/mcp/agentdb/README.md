# agentdb MCP client

Local-first semantic memory MCP server for Claude Code.

## Setup

```bash
cd .claude/mcp/agentdb
npm install
```

## Configuration

Copy the template and fill in your project details:

```bash
cp .agentdb/config.json.template .agentdb/config.json
# Edit .agentdb/config.json
```

Set the API key as an environment variable (never in config):

```bash
export AGENTDB_API_KEY=your-key-from-vps-env
```

## Register in Claude Code

Add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "agentdb": {
      "command": "node",
      "args": [".claude/mcp/agentdb/index.js"],
      "env": {
        "AGENTDB_API_KEY": "${AGENTDB_API_KEY}"
      }
    }
  }
}
```

## Tools

| Tool | Description |
|------|-------------|
| `agentdb_store` | Write a pattern locally + sync to VPS |
| `agentdb_search` | Semantic search (falls back to keyword if VPS down) |
| `agentdb_list` | List entries in the project namespace |
| `agentdb_delete` | Delete an entry |
| `agentdb_debug` | Raw similarity scores — diagnose search quality |

## Local-first contract

`agentdb_store` always writes to `.agentdb/entries/{slug}.md` first. The file is the source of truth.
VPS sync happens in the same call (10s timeout). If it fails:
- Entry is preserved locally (git-trackable)
- Error appended to `.agentdb/sync-errors.log`
- Run `scripts/agentdb-reindex.sh` to catch up when VPS is back

`agentdb_search` falls back to keyword search on local files if VPS is unreachable.

## Project root detection

The server finds the project root by:
1. `AGENTDB_PROJECT_ROOT` env var (if set)
2. Walking up from `cwd` until finding a `.agentdb/` directory
3. Fallback: `cwd`
