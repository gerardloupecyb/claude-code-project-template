---
name: commit-push
description: >
  Commit session changes and push to main. Solo-developer workflow — no feature
  branches, no PR. Stages only session-relevant files, writes a conventional
  commit message, pushes to origin/main.
  Triggers on: commit, commit et push, push, ship it, envoie ça.
---

# Commit & Push — Session Commit to Main

Stage, commit, and push the current session's work to main in one command.
Designed for solo-developer workflow on main branch — no feature branch warning,
no PR creation.

---

## Usage

```
/commit-push
```

Or simply say: "commit", "commit et push", "push", "ship it", "envoie ça".

---

## Workflow

### Step 1 — Gather Context

Run in parallel:

```bash
git status
```

```bash
git diff HEAD
```

```bash
git log --oneline -5
```

If working tree is clean (no staged, modified, or untracked files): report "Nothing to commit" and stop.

### Step 2 — Identify Session Files

Review the diff and status output. Separate:

- **Session files**: files modified or created as part of the current conversation's work
- **Pre-existing dirty files**: files that were already modified before this session started (visible in the initial `gitStatus` context at conversation start)

**Rule**: Only stage session files. If pre-existing dirty files exist, list them separately:

```
⚠ Pre-existing changes not included in this commit:
  - .planning/STATE.md (modified before session)
  - ...
```

If unsure whether a file is session work or pre-existing, ask the user.

### Step 3 — Determine Commit Convention

Follow the project's existing commit pattern from recent history. Default: conventional commits (`type(scope): description`).

Common types for this project:
- `feat` — new capability
- `fix` — bug fix or correction
- `docs` — documentation only
- `refactor` — rename, restructure, no behavior change
- `chore` — maintenance, memory updates, planning artifacts

### Step 4 — Consider Logical Splits

If changed files cover clearly distinct concerns, split into separate commits. Keep it lightweight:

- Group at **file level only** — no hunk splitting
- 2-3 commits max. If ambiguous, one commit is fine
- `.planning/` artifacts can be bundled together

### Step 5 — Stage and Commit

For each commit group:

```bash
git add file1 file2 file3 && git commit -m "$(cat <<'EOF'
type(scope): subject line — why not what

Optional body for non-trivial changes.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rules:**
- Stage specific files by name — never `git add -A` or `git add .`
- Never commit `.env`, credentials, or secrets
- Imperative mood, focused on *why*
- Co-Authored-By trailer always included

### Step 6 — Branch Context Check + Auto-Merge

Before pushing, detect the current branch:

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

**If on a `gsd/phase-*` branch — deletion guard then auto-merge:**

```bash
# 1. Push phase branch
git push -u origin "$CURRENT_BRANCH"

# 2. Deletion guard: count files deleted vs main
DELETIONS=$(git diff main..HEAD --name-only --diff-filter=D 2>/dev/null)
DEL_COUNT=$(echo "$DELETIONS" | grep -c . 2>/dev/null || echo 0)
[ -z "$DELETIONS" ] && DEL_COUNT=0
```

**If `DEL_COUNT > 5` → BLOCK, inspect automatically, then recommend:**

Do not merge yet. Inspect each deleted file to classify it:

```bash
# Check which commit on the phase branch introduced each deletion
git log main..HEAD --diff-filter=D --name-only --oneline
```

For each deleted file, determine:
- **Worktree artifact** (path contains `.planning/phases/`, `memory/`, `docs/solutions/`, etc. from a *different* phase) → almost certainly a bug (stale fork divergence)
- **Code/config file** with a commit message like "remove", "delete", "cleanup", "refactor" → likely intentional
- **Code/config file** with no matching commit intent → suspicious, flag it

Produce a classified report:

```
⛔ Merge blocked — {DEL_COUNT} deletions detected vs main.

Likely bugs (restore these):
  - .planning/phases/03-auth/SUMMARY.md  [worktree artifact — wrong base]
  - docs/standards/loi25.md              [no delete intent in commits]

Likely intentional (safe to keep):
  - scripts/old-migration.sh             [commit: "remove deprecated script"]

Recommendation: [A or B, with reasoning]

  A) All intentional → force merge:
       git checkout main && git merge --no-ff {branch_name} && git push && git branch -d {branch_name}

  B) Restore bugs, then re-run commit:
       git checkout main -- path/to/file
       git add path/to/file && git commit -m "restore: accidentally deleted by worktree divergence"
```

After presenting the report and recommendation, stop and wait for confirmation before taking any action.

**If `DEL_COUNT <= 5` → auto-merge to main:**

```bash
git checkout main
git merge --no-ff "$CURRENT_BRANCH" -m "merge(phase): {branch_name} → main"
git push
git branch -d "$CURRENT_BRANCH" 2>/dev/null || true
```

Report:
```
✓ Phase branch merged to main
✓ {DEL_COUNT} deletion(s) verified (within threshold)
```

If there are legitimate deletions (≤ 5), list them so the user can confirm they are expected.

**If on `main`:** Push normally:

```bash
git push
```

### Step 7 — Confirm

Run `git status` to verify clean state. Report:

```
✓ {hash} {subject line}
✓ Pushed to origin/main
```

---

## Behavior Rules

- **No feature branch warning** — this project works on main directly (or phase branches via GSD)
- **No PR creation** — use `/gsd-ship` if a PR is needed for a specific case
- **Never force push** — if rejected, diagnose and report
- **Never skip pre-commit hooks** — if hook fails, fix the issue and retry
- **Session-scoped only** — do not stage files that were dirty before the session
- **Ask before committing secrets** — warn if .env, credentials, or key files are staged
- **Phase branch auto-merge** — on `gsd/phase-*`, deletion guard runs automatically; > 5 deletions blocks merge, ≤ 5 auto-merges to main
