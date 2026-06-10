---
name: skill-refresh
description: "Automatically refresh skills when platform updates are detected. Fetches latest docs, compares claims against current skill content, applies fixes, and asks only for commit approval. Trigger on 'skill refresh', 'refresh skill', 'update skill docs', 'skill outdated', or when a todo from the release monitor workflows ({{WORKFLOW_ENGINE}}/{{CRM_PLATFORM}}/{{CLOUD_PROVIDER}}) is detected."
---

# Skill Refresh

Automatically update skills when platform breaking changes are detected. Fully autonomous — fetches docs, identifies gaps, applies fixes, then asks only for commit approval.

## When to Use

- A release monitor todo is detected (`todos/*-{{WORKFLOW_ENGINE}}-release-review.md`, `*-{{crm_platform}}-update-review.md`, `*-{{cloud_provider}}-update-review.md`)
- User says "refresh skills", "update skill for X", "skill outdated"
- Periodic quarterly validation (manual trigger)

## Platform → Skill Mapping

| Platform | Skills to check | Doc source |
|----------|----------------|------------|
| {{WORKFLOW_ENGINE}} | {{WORKFLOW_ENGINE}}-workflow-architect, {{WORKFLOW_ENGINE}}-node-expert, {{WORKFLOW_ENGINE}}-code-nodes | Context7 `/{{WORKFLOW_ENGINE}}-io/{{WORKFLOW_ENGINE}}-docs` or docs.{{WORKFLOW_ENGINE}}.io |
| {{CRM_PLATFORM}} | {{crm_platform}}-architect | marketplace.gohi{{crm_platform}}evel.com/docs/ |
| {{CLOUD_PROVIDER}}/{{IDENTITY_PLATFORM}} | {{cloud_provider}}-{{identity_platform}}-architect | {{cloud_provider}}.microsoft.com/updates, learn.microsoft.com |

## Process (fully autonomous)

### Step 1: Detect context

If argument is a platform name ({{WORKFLOW_ENGINE}}, {{crm_platform}}, {{cloud_provider}}), use it directly.
If no argument, scan `todos/` for pending release monitor todos and auto-detect platform.
If a todo exists, read it for: version, matched keywords, release notes link.

### Step 2: Fetch latest docs

**{{WORKFLOW_ENGINE}}:** Try Context7 first (`/{{WORKFLOW_ENGINE}}-io/{{WORKFLOW_ENGINE}}-docs`), fall back to web search on docs.{{WORKFLOW_ENGINE}}.io.
**{{CRM_PLATFORM}}:** Web search on marketplace.gohi{{crm_platform}}evel.com/docs/ for the matched keywords.
**{{CLOUD_PROVIDER}}:** Web search on learn.microsoft.com + {{cloud_provider}}.microsoft.com/updates for matched keywords.

Focus queries on the keywords from the todo (e.g., "breaking", "deprecated", "task runner"). If no todo, query the 3 key validation areas per platform:

| Platform | Validation areas |
|----------|-----------------|
| {{WORKFLOW_ENGINE}} | Task runners/sandbox, Python imports, Save/Publish, expressions |
| {{CRM_PLATFORM}} | API version header, webhook signature, OAuth scopes, rate limits |
| {{CLOUD_PROVIDER}} | Bicep API versions, Graph SDK version, {{IDENTITY_PROVIDER}} CA changes, {{SCRIPTING_LANG}} modules |

### Step 3: Extract claims from skills

Read each target skill's SKILL.md + all reference files.
Extract testable claims (version numbers, API endpoints, auth patterns, syntax rules, behavioral statements).
Build a checklist: `claim → source line → current value → doc value → match?`

### Step 4: Identify gaps

Compare extracted claims against fetched docs.
Categorize each gap:
- **CRITICAL**: Wrong information that would cause errors (wrong API, wrong auth method, wrong syntax)
- **IMPORTANT**: Missing new feature or deprecated feature not flagged
- **MINOR**: Outdated version number that still works but isn't latest

### Step 5: Apply fixes (autonomous)

For each gap found:
1. Read the file containing the stale claim
2. Edit with the corrected information
3. Add source URL as a comment or reference where applicable

Do NOT ask for approval at this stage. Apply all fixes.

### Step 6: Present summary and ask for commit

Present a single summary table:

```
## Skill Refresh Summary — [platform] [date]

### Changes applied:

| File | Line | Before | After | Severity | Source |
|------|------|--------|-------|----------|--------|
| ... | ... | ... | ... | CRITICAL | [url] |

### Files modified: [count]
### Claims verified: [total] — [pass] OK, [fail] corrected, [skip] unchanged

Commit these changes? (y/n)
```

Wait for user approval. If approved:
- `git add` only the modified skill files
- Commit with message: `fix(<platform>): skill refresh — [count] claims corrected`
- If a todo triggered this, mark the todo as completed

### Step 7: Update todo (if applicable)

If triggered by a release monitor todo:
- Mark todo status as `completed`
- Add completion note with date and count of changes

## Key rules

- **Never ask questions during steps 1-5.** The skill is fully autonomous until the commit approval.
- **Never skip the summary.** Even if zero gaps found, show the verification count.
- **Always show before/after** for every change so the user can review.
- **Prefer Context7 over web search** — more structured, less noise.
- **Do not modify files outside the skill directories** — this skill only touches `.claude/skills/` and `todos/`.
- **If a claim cannot be verified** (doc source unavailable), mark it as `UNVERIFIED` in the summary, don't guess.
