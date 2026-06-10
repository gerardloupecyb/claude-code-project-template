#!/bin/bash
# Enforce MEMORY.md retention: keep 5 "Ce qui a ete fait" entries live, archive the rest.
# Safe to run repeatedly.

trap 'exit 0' EXIT

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY_FILE="${PROJECT_ROOT}/memory/MEMORY.md"

[ -f "$MEMORY_FILE" ] || exit 0

python3 - "$PROJECT_ROOT" "$MEMORY_FILE" <<'PY'
import re
import sys
from datetime import date
from pathlib import Path

project_root = Path(sys.argv[1])
memory_file = Path(sys.argv[2])
text = memory_file.read_text()

match = re.search(r'(## Ce qui a ete fait\n)(.*?)(\n## |\Z)', text, re.S)
if not match:
    raise SystemExit(0)

section_header, body, section_end = match.groups()
entry_matches = list(re.finditer(r'^### .+?(?=^### |\Z)', body, re.M | re.S))

if len(entry_matches) <= 5:
    raise SystemExit(0)

entries = [m.group(0).rstrip() for m in entry_matches]
keep = entries[:5]
archive_entries = entries[5:]

today = date.today()
archive_file = project_root / "memory" / f"archive-{today:%Y-%m}.md"

if archive_file.exists():
    archive_text = archive_file.read_text()
else:
    archive_text = (
        f"# Archive — Ce qui a été fait ({today:%Y-%m})\n\n"
        f"> Archivé depuis MEMORY.md automatiquement le {today:%Y-%m-%d} (max 5 entrées actives).\n\n"
        "---\n"
    )

existing_titles = set(re.findall(r'^###\s+(.+)$', archive_text, re.M))
new_entries = []
for entry in archive_entries:
    title_match = re.search(r'^###\s+(.+)$', entry, re.M)
    title = title_match.group(1).strip() if title_match else entry.splitlines()[0]
    if title not in existing_titles:
        new_entries.append(entry)
        existing_titles.add(title)

if new_entries:
    archive_text = archive_text.rstrip() + "\n\n" + "\n\n".join(new_entries) + "\n"
    archive_file.write_text(archive_text)

new_body = "\n" + "\n\n".join(keep) + "\n"
new_section = section_header + new_body + section_end
new_text = text[:match.start()] + new_section + text[match.end():]

if new_text != text:
    memory_file.write_text(new_text)
PY
