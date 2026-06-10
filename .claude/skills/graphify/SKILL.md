---
name: graphify
description: any input (code, docs, papers, images) → knowledge graph → clustered communities → HTML + JSON + audit report
trigger: /graphify
---

# /graphify

Turn any folder of files into a navigable knowledge graph with community detection, an honest audit trail, and three outputs: interactive HTML, GraphRAG-ready JSON, and a plain-language GRAPH_REPORT.md.

## References

Load the file for the active subcommand or step — do not load all files upfront.

| File | Load when |
|------|-----------|
| `references/step3-extraction.md` | Full pipeline run — load at Step 3 |
| `references/step6-outputs.md` | Full pipeline run — load at Step 6 |
| `references/exports-optional.md` | If `--neo4j`, `--neo4j-push`, `--svg`, `--graphml`, `--mcp`, `--watch`, or user asks about git hook / CLAUDE.md integration |
| `references/subcommand-update.md` | If `--update` flag |
| `references/subcommand-cluster-only.md` | If `--cluster-only` flag |
| `references/subcommand-query.md` | If `query`, `path`, `explain`, or `add` subcommand |

## Usage

```
/graphify                                             # full pipeline on current directory
/graphify <path>                                      # full pipeline on specific path
/graphify <path> --mode deep                          # thorough extraction, richer INFERRED edges
/graphify <path> --update                             # incremental - re-extract only new/changed files
/graphify <path> --directed                           # build directed graph (preserves edge direction)
/graphify <path> --whisper-model medium               # use a larger Whisper model
/graphify <path> --cluster-only                       # rerun clustering on existing graph
/graphify <path> --no-viz                             # skip visualization, just report + JSON
/graphify <path> --svg                                # also export graph.svg
/graphify <path> --graphml                            # export graph.graphml (Gephi, yEd)
/graphify <path> --neo4j                              # generate graphify-out/cypher.txt for Neo4j
/graphify <path> --neo4j-push bolt://localhost:7687   # push directly to Neo4j
/graphify <path> --mcp                                # start MCP stdio server for agent access
/graphify <path> --watch                              # watch folder, auto-rebuild on code changes
/graphify <path> --obsidian --obsidian-dir ~/vaults/  # write Obsidian vault to custom path
/graphify add <url>                                   # fetch URL, save to ./raw, update graph
/graphify add <url> --author "Name"                   # tag who wrote it
/graphify query "<question>"                          # BFS traversal - broad context
/graphify query "<question>" --dfs                    # DFS - trace a specific path
/graphify query "<question>" --budget 1500            # cap answer at N tokens
/graphify path "AuthModule" "Database"                # shortest path between two concepts
/graphify explain "SwinTransformer"                   # plain-language explanation of a node
```

## What graphify is for

graphify is built around Andrej Karpathy's /raw folder workflow: drop anything into a folder — papers, tweets, screenshots, code, notes — and get a structured knowledge graph that shows you what you didn't know was connected.

Three things it does that Claude alone cannot:
1. **Persistent graph** — relationships are stored in `graphify-out/graph.json` and survive across sessions. Ask questions weeks later without re-reading everything.
2. **Honest audit trail** — every edge is tagged EXTRACTED, INFERRED, or AMBIGUOUS. You know what was found vs invented.
3. **Cross-document surprise** — community detection finds connections between concepts in different files that you would never think to ask about directly.

Use it for:
- A codebase you're new to (understand architecture before touching anything)
- A reading list (papers + tweets + notes → one navigable graph)
- A research corpus (citation graph + concept graph in one)
- Your personal /raw folder (drop everything in, let it grow, query it)

---

## What You Must Do When Invoked

If no path was given, use `.` (current directory). Do not ask the user for a path.

**Subcommand routing:** If the invocation matches a subcommand flag or verb (`--update`, `--cluster-only`, `query`, `path`, `explain`, `add`), load the corresponding reference file and follow its instructions instead of the pipeline below. Do not run the full pipeline for subcommands.

Follow the full pipeline steps in order. Do not skip steps.

### Step 1 — Ensure graphify is installed

```bash
# Detect the correct Python interpreter (handles pipx, venv, system installs)
GRAPHIFY_BIN=$(which graphify 2>/dev/null)
if [ -n "$GRAPHIFY_BIN" ]; then
    PYTHON=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
    case "$PYTHON" in
        *[!a-zA-Z0-9/_.-]*) PYTHON="python3" ;;
    esac
else
    PYTHON="python3"
fi
"$PYTHON" -c "import graphify" 2>/dev/null || "$PYTHON" -m pip install graphifyy -q 2>/dev/null || "$PYTHON" -m pip install graphifyy -q --break-system-packages 2>&1 | tail -3
# Write interpreter path for all subsequent steps (persists across invocations)
mkdir -p graphify-out
"$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w').write(sys.executable)"
```

If the import succeeds, print nothing and move straight to Step 2.

**In every subsequent bash block, replace `python3` with `$(cat graphify-out/.graphify_python)` to use the correct interpreter.**

### Step 2 — Detect files

```bash
$(cat graphify-out/.graphify_python) -c "
import json
from graphify.detect import detect
from pathlib import Path
result = detect(Path('INPUT_PATH'))
print(json.dumps(result))
" > graphify-out/.graphify_detect.json
```

Replace INPUT_PATH with the actual path the user provided. Do NOT cat or print the JSON — read it silently and present a clean summary instead:

```
Corpus: X files · ~Y words
  code:     N files (.py .ts .go ...)
  docs:     N files (.md .txt ...)
  papers:   N files (.pdf ...)
  images:   N files
  video:    N files (.mp4 .mp3 ...)
```

Omit any category with 0 files from the summary.

Then act on it:
- If `total_files` is 0: stop with "No supported files found in [path]."
- If `skipped_sensitive` is non-empty: mention file count skipped, not the file names.
- If `total_words` > 2,000,000 OR `total_files` > 200: show the warning and the top 5 subdirectories by file count, then ask which subfolder to run on. Wait for the user's answer before proceeding.
- Otherwise: proceed directly to Step 2.5 if video files were detected, or Step 3 if not.

### Step 2.5 — Transcribe video / audio files (only if video files detected)

Skip this step entirely if `detect` returned zero `video` files.

Video and audio files cannot be read directly. Transcribe them to text first, then treat the transcripts as doc files in Step 3.

**Strategy:** Read the god nodes from `graphify-out/.graphify_detect.json`. You are already a language model — write a one-sentence domain hint yourself from those labels. Then pass it to Whisper as the initial prompt. No separate API call needed.

If the corpus has *only* video files and no other docs/code, use the generic fallback prompt: `"Use proper punctuation and paragraph breaks."`

**Step 1 — Write the Whisper prompt yourself.**

Read the top god node labels from detect output or analysis, then compose a short domain hint sentence, for example:

- Labels: `transformer, attention, encoder, decoder` → `"Machine learning research on transformer architectures and attention mechanisms. Use proper punctuation and paragraph breaks."`
- Labels: `kubernetes, deployment, pod, helm` → `"DevOps discussion about Kubernetes deployments and Helm charts. Use proper punctuation and paragraph breaks."`

Set it as `WHISPER_PROMPT` to use in the next command.

**Step 2 — Transcribe:**

```bash
GRAPHIFY_WHISPER_MODEL=base  # or whatever --whisper-model the user passed
$(cat graphify-out/.graphify_python) -c "
import json, os
from pathlib import Path
from graphify.transcribe import transcribe_all

detect = json.loads(Path('graphify-out/.graphify_detect.json').read_text())
video_files = detect.get('files', {}).get('video', [])
prompt = os.environ.get('GRAPHIFY_WHISPER_PROMPT', 'Use proper punctuation and paragraph breaks.')

transcript_paths = transcribe_all(video_files, initial_prompt=prompt)
print(json.dumps(transcript_paths))
" > graphify-out/.graphify_transcripts.json
```

After transcription:
- Read the transcript paths from `graphify-out/.graphify_transcripts.json`
- Add them to the docs list before dispatching semantic subagents in Step 3B
- Print how many transcripts were created: `Transcribed N video file(s) -> treating as docs`
- If transcription fails for a file, print a warning and continue with the rest

**Whisper model:** Default is `base`. If the user passed `--whisper-model <name>`, set `GRAPHIFY_WHISPER_MODEL=<name>` in the environment before running the command above.

### Step 3 — Extract entities and relationships

Load `references/step3-extraction.md` and follow its instructions exactly.

Key rule carried here for visibility: **always use `subagent_type="general-purpose"`** when dispatching extraction subagents. Never use `Explore` — it is read-only and silently drops chunk files to disk.

### Step 4 — Build graph, cluster, analyze, generate outputs

**Before starting:** note whether `--directed` was given. If so, pass `directed=True` to `build_from_json()`. This builds a `DiGraph` that preserves edge direction (source→target) instead of the default undirected `Graph`.

```bash
mkdir -p graphify-out
$(cat graphify-out/.graphify_python) -c "
import sys, json
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json
from pathlib import Path

extraction = json.loads(Path('graphify-out/.graphify_extract.json').read_text())
detection  = json.loads(Path('graphify-out/.graphify_detect.json').read_text())

G = build_from_json(extraction)
communities = cluster(G)
cohesion = score_all(G, communities)
tokens = {'input': extraction.get('input_tokens', 0), 'output': extraction.get('output_tokens', 0)}
gods = god_nodes(G)
surprises = surprising_connections(G, communities)
labels = {cid: 'Community ' + str(cid) for cid in communities}
# Placeholder questions - regenerated with real labels in Step 5
questions = suggest_questions(G, communities, labels)

report = generate(G, communities, cohesion, labels, gods, surprises, detection, tokens, 'INPUT_PATH', suggested_questions=questions)
Path('graphify-out/GRAPH_REPORT.md').write_text(report)
to_json(G, communities, 'graphify-out/graph.json')

analysis = {
    'communities': {str(k): v for k, v in communities.items()},
    'cohesion': {str(k): v for k, v in cohesion.items()},
    'gods': gods,
    'surprises': surprises,
    'questions': questions,
}
Path('graphify-out/.graphify_analysis.json').write_text(json.dumps(analysis, indent=2))
if G.number_of_nodes() == 0:
    print('ERROR: Graph is empty - extraction produced no nodes.')
    print('Possible causes: all files were skipped, binary-only corpus, or extraction failed.')
    raise SystemExit(1)
print(f'Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities')
"
```

If this step prints `ERROR: Graph is empty`, stop and tell the user what happened — do not proceed.

Replace INPUT_PATH with the actual path.

### Step 5 — Label communities

Read `graphify-out/.graphify_analysis.json`. For each community key, look at its node labels and write a 2-5 word plain-language name (e.g. "Attention Mechanism", "Training Pipeline", "Data Loading").

Then regenerate the report and save the labels for the visualizer:

```bash
$(cat graphify-out/.graphify_python) -c "
import sys, json
from graphify.build import build_from_json
from graphify.cluster import score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from pathlib import Path

extraction = json.loads(Path('graphify-out/.graphify_extract.json').read_text())
detection  = json.loads(Path('graphify-out/.graphify_detect.json').read_text())
analysis   = json.loads(Path('graphify-out/.graphify_analysis.json').read_text())

G = build_from_json(extraction)
communities = {int(k): v for k, v in analysis['communities'].items()}
cohesion = {int(k): v for k, v in analysis['cohesion'].items()}
tokens = {'input': extraction.get('input_tokens', 0), 'output': extraction.get('output_tokens', 0)}

# LABELS - replace these with the names you chose above
labels = LABELS_DICT

# Regenerate questions with real community labels (labels affect question phrasing)
questions = suggest_questions(G, communities, labels)

report = generate(G, communities, cohesion, labels, analysis['gods'], analysis['surprises'], detection, tokens, 'INPUT_PATH', suggested_questions=questions)
Path('graphify-out/GRAPH_REPORT.md').write_text(report)
Path('graphify-out/.graphify_labels.json').write_text(json.dumps({str(k): v for k, v in labels.items()}))
print('Report updated with community labels')
"
```

Replace `LABELS_DICT` with the actual dict you constructed (e.g. `{0: "Attention Mechanism", 1: "Training Pipeline"}`).
Replace INPUT_PATH with the actual path.

### Step 6 — Generate outputs (Obsidian vault + HTML)

Load `references/step6-outputs.md` and follow its instructions exactly.

### Step 7 — Optional exports

If the invocation includes `--neo4j`, `--neo4j-push`, `--svg`, `--graphml`, or `--mcp`: load `references/exports-optional.md` and follow the relevant section. Otherwise skip this step.

### Step 8 — Token reduction benchmark (only if total_words > 5000)

If `total_words` from `graphify-out/.graphify_detect.json` is greater than 5,000, run:

```bash
$(cat graphify-out/.graphify_python) -c "
import json
from graphify.benchmark import run_benchmark, print_benchmark
from pathlib import Path

detection = json.loads(Path('graphify-out/.graphify_detect.json').read_text())
result = run_benchmark('graphify-out/graph.json', corpus_words=detection['total_words'])
print_benchmark(result)
"
```

Print the output directly in chat. If `total_words <= 5000`, skip silently.

### Step 9 — Save manifest, update cost tracker, clean up, and report

```bash
$(cat graphify-out/.graphify_python) -c "
import json
from pathlib import Path
from datetime import datetime, timezone
from graphify.detect import save_manifest

# Save manifest for --update
detect = json.loads(Path('graphify-out/.graphify_detect.json').read_text())
save_manifest(detect['files'])

# Update cumulative cost tracker
extract = json.loads(Path('graphify-out/.graphify_extract.json').read_text())
input_tok = extract.get('input_tokens', 0)
output_tok = extract.get('output_tokens', 0)

cost_path = Path('graphify-out/cost.json')
if cost_path.exists():
    cost = json.loads(cost_path.read_text())
else:
    cost = {'runs': [], 'total_input_tokens': 0, 'total_output_tokens': 0}

cost['runs'].append({
    'date': datetime.now(timezone.utc).isoformat(),
    'input_tokens': input_tok,
    'output_tokens': output_tok,
    'files': detect.get('total_files', 0),
})
cost['total_input_tokens'] += input_tok
cost['total_output_tokens'] += output_tok
cost_path.write_text(json.dumps(cost, indent=2))

print(f'This run: {input_tok:,} input tokens, {output_tok:,} output tokens')
print(f'All time: {cost[\"total_input_tokens\"]:,} input, {cost[\"total_output_tokens\"]:,} output ({len(cost[\"runs\"])} runs)')
"
rm -f graphify-out/.graphify_detect.json graphify-out/.graphify_extract.json graphify-out/.graphify_ast.json graphify-out/.graphify_semantic.json graphify-out/.graphify_analysis.json graphify-out/.graphify_labels.json
rm -f graphify-out/.needs_update 2>/dev/null || true
```

Tell the user (omit the obsidian line unless `--obsidian` was given):
```
Graph complete. Outputs in PATH_TO_DIR/graphify-out/

  graph.html            - interactive graph, open in browser
  GRAPH_REPORT.md       - audit report
  graph.json            - raw graph data
  obsidian/             - Obsidian vault (only if --obsidian was given)
```

If graphify saved you time, consider supporting it: https://github.com/sponsors/safishamsi

Replace PATH_TO_DIR with the actual absolute path of the directory that was processed.

Then paste these sections from GRAPH_REPORT.md directly into the chat:
- God Nodes
- Surprising Connections
- Suggested Questions

Do NOT paste the full report — just those three sections. Keep it concise.

Then immediately offer to explore. Pick the single most interesting suggested question from the report — the one that crosses the most community boundaries or has the most surprising bridge node — and ask:

> "The most interesting question this graph can answer: **[question]**. Want me to trace it?"

If the user says yes, run `/graphify query "[question]"` on the graph and walk them through the answer using the graph structure. Keep going as long as they want to explore. Each answer should end with a natural follow-up ("this connects to X — want to go deeper?").

The graph is the map. Your job after the pipeline is to be the guide.

---

## Interpreter guard for subcommands

Before running any subcommand (`--update`, `--cluster-only`, `query`, `path`, `explain`, `add`), check that `.graphify_python` exists. If it's missing (e.g. user deleted `graphify-out/`), re-resolve the interpreter first:

```bash
if [ ! -f graphify-out/.graphify_python ]; then
    GRAPHIFY_BIN=$(which graphify 2>/dev/null)
    if [ -n "$GRAPHIFY_BIN" ]; then
        PYTHON=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
        case "$PYTHON" in *[!a-zA-Z0-9/_.-]*) PYTHON="python3" ;; esac
    else
        PYTHON="python3"
    fi
    mkdir -p graphify-out
    "$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w').write(sys.executable)"
fi
```

Then check the graph exists (all subcommands except `add` require it):
```bash
$(cat graphify-out/.graphify_python) -c "
from pathlib import Path
if not Path('graphify-out/graph.json').exists():
    print('ERROR: No graph found. Run /graphify <path> first to build the graph.')
    raise SystemExit(1)
"
```
If it fails, stop and tell the user to run `/graphify <path>` first.

---

## Honesty Rules

- Never invent an edge. If unsure, use AMBIGUOUS.
- Never skip the corpus check warning.
- Always show token cost in the report.
- Never hide cohesion scores behind symbols — show the raw number.
- Never run HTML viz on a graph with more than 5,000 nodes without warning the user.
