#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Loupe Technologies
# SPDX-License-Identifier: CC0-1.0
"""Slopsquatting IBA helper — edit-distance check using Python stdlib difflib only.

Invoked by supply-chain-audit IBA driver (Step 1) when class has `helper:` field.
Reads config/security/slopsquatting-seed.json + .claude/allowlists/slopsquatting-exceptions.json.

Usage:
    slopsquat-check.py --package <name> [--seed <path>] [--allowlist <path>]

Exit codes:
    0 — completed (check output for verdict)
    1 — missing seed or allowlist file
    2 — invalid arguments
"""
import argparse
import difflib
import json
import re
import sys
from pathlib import Path


# Path depth: helpers(0)/patterns(1)/supply-chain-audit(2)/skills(3)/.claude(4)/REPO_ROOT(5)
REPO_ROOT = Path(__file__).resolve().parents[5]
DEFAULT_SEED = REPO_ROOT / "config" / "security" / "slopsquatting-seed.json"
DEFAULT_ALLOWLIST = REPO_ROOT / ".claude" / "allowlists" / "slopsquatting-exceptions.json"
MAX_DISTANCE = 2


def levenshtein(a: str, b: str) -> int:
    """Compute Levenshtein distance using stdlib difflib-adjacent math.

    difflib.SequenceMatcher ratio is 2*M/T where M is matches, T is total.
    For exact edit distance we implement the classic DP (stdlib-only, ~15 lines).
    """
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            ins = current[j - 1] + 1
            dele = previous[j] + 1
            sub = previous[j - 1] + (ca != cb)
            current.append(min(ins, dele, sub))
        previous = current
    return previous[-1]


def normalize(name: str) -> str:
    """PEP 503 package-name normalization: lowercase, collapse runs of -_. to a single -.

    Per PyPI, `charset_normalizer`, `charset-normalizer` and `Charset.Normalizer` are
    the same project. Comparing raw forms makes legitimate separator/case variants
    score edit-distance >= 1 and produce false `high` slopsquat verdicts.
    """
    return re.sub(r"[-_.]+", "-", name.strip()).lower()


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"ERROR: missing file {path}", file=sys.stderr)
        sys.exit(1)
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def check(package: str, seed: dict, allowlist: dict) -> dict:
    """Return verdict: {'package', 'distance', 'nearest', 'verdict'} with verdict in {skip, high}."""
    candidates = seed.get("packages", [])
    if not candidates:
        return {"package": package, "verdict": "skip", "reason": "empty seed"}

    norm_pkg = normalize(package)

    # Nearest seed candidate by edit distance on PEP 503-normalized names.
    nearest = None
    nearest_distance = None
    for c in candidates:
        d = levenshtein(norm_pkg, normalize(c))
        if nearest_distance is None or d < nearest_distance:
            nearest = c
            nearest_distance = d

    # Exact match to a seed package (post-normalization) — legitimate. Evaluated
    # before the allowlist so a seed package is never reported as an allowlisted typo.
    if nearest_distance == 0:
        return {"package": package, "distance": 0, "nearest": nearest, "verdict": "skip", "reason": "exact match to seed (legitimate)"}

    # Allowlist check — normalized exact match on the typo name.
    for entry in allowlist.get("allowed", []):
        if normalize(entry.get("typo", "")) == norm_pkg:
            return {
                "package": package,
                "verdict": "skip",
                "reason": f"allowlist entry (typo of {entry.get('canonical')})",
            }

    if nearest_distance <= MAX_DISTANCE:
        return {"package": package, "distance": nearest_distance, "nearest": nearest, "verdict": "high", "reason": f"slopsquat — distance {nearest_distance} to {nearest}"}
    return {"package": package, "distance": nearest_distance, "nearest": nearest, "verdict": "skip", "reason": f"distance > {MAX_DISTANCE}"}


def main():
    ap = argparse.ArgumentParser(description="Slopsquatting IBA helper")
    ap.add_argument("--package", required=True, help="Package name to check")
    ap.add_argument("--seed", default=str(DEFAULT_SEED), help="Seed JSON path")
    ap.add_argument("--allowlist", default=str(DEFAULT_ALLOWLIST), help="Allowlist JSON path")
    args = ap.parse_args()

    seed = load_json(Path(args.seed))
    allowlist = load_json(Path(args.allowlist))
    result = check(args.package, seed, allowlist)
    print(json.dumps(result, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()
