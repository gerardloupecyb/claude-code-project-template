---
name: code-xray
description: "Token-efficient codebase exploration via symbol-level precision lookups. Emulates jCodeMunch features (search symbols, get source, outline, importers, blast radius, class hierarchy) using native tools only — zero external dependencies."
trigger: "xray, code xray, symbol search, find symbol, file outline, blast radius, who imports, class hierarchy, find function, find method, code structure, show me the function, what calls this, what breaks if I change"
---

# Code X-Ray — Precision Codebase Explorer

Token-efficient codebase exploration. Instead of reading entire files, extract exactly what's needed.

## Core Principle

**Never Read a full file when you only need a symbol.** Every workflow below minimizes token usage by targeting exact line ranges.

---

## Workflows

### 1. Search Symbols — Find functions, classes, methods by name

```
Grep pattern: language-aware definition patterns
```

| Language | Pattern for `symbolName` |
|----------|------------------------|
| Ruby | `(def\|class\|module)\s+symbolName` |
| Python | `(def\|class)\s+symbolName` |
| JavaScript/TS | `(function\|class\|const\|let\|var)\s+symbolName\|symbolName\s*[=:]\s*(function\|async\|=>)` |
| Go | `func\s+(\(.*\)\s+)?symbolName` |
| Rust | `(fn\|struct\|enum\|trait\|impl)\s+symbolName` |
| Java/Kotlin | `(class\|interface\|void\|public\|private\|protected).*\s+symbolName` |
| C/C++ | `\w+[\s*]+symbolName\s*\(` |

**Workflow:**
1. `Grep` with language-aware pattern + `output_mode: "content"` + `head_limit: 20`
2. Return: file path, line number, signature preview

**Token cost:** ~200 tokens vs ~2000+ for Read + scan

---

### 2. Get Symbol Source — Extract exact implementation

**Workflow:**
1. `Grep` to find the definition line number
2. `Read` with `offset` = line number, `limit` = estimated function length (start with 50 lines)
3. If function continues beyond limit, extend with another Read

**Heuristic for function length:**
- One-liner / accessor: `limit: 5`
- Normal method: `limit: 30`
- Complex method / class: `limit: 80`
- Unknown: `limit: 50` then check if block closes

**Block-end detection by language:**
| Language | End marker |
|----------|-----------|
| Ruby | `end` at same indentation |
| Python | Next line at same/lesser indentation (or EOF) |
| JS/TS | `}` at same indentation as opening `{` |
| Go/Rust/Java | `}` matching the opening brace |

**Token cost:** ~500 tokens for a 30-line method vs ~3000 for full file

---

### 3. File Outline — Structure without content

**Workflow:**
1. `Grep` the file with pattern `^\s*(def |class |module |function |const |export |interface |type |struct |enum |trait |impl |fn )` + `output_mode: "content"`
2. Return: numbered list of symbols with line numbers

**Alternative for richer output:**
```bash
ctags -f - --fields=+n <filepath> | sort -t$'\t' -k3 -n
```
Note: macOS ctags is BSD (limited). If `universal-ctags` available, use `ctags --output-format=json`.

**Token cost:** ~300 tokens for a 500-line file vs ~5000 for full Read

---

### 4. Find Importers — Who imports this file/module?

**Workflow:**
1. Extract the module/file name from the path (strip extension, handle index files)
2. `Grep` with import patterns:

| Language | Pattern |
|----------|---------|
| Ruby | `require.*moduleName\|require_relative.*moduleName` |
| Python | `(from\|import)\s+.*moduleName` |
| JS/TS | `(import\|require).*moduleName` |
| Go | `".*moduleName"` |
| Rust | `use\s+.*moduleName` |

3. Filter with `glob` parameter to target only source files of that language
4. Return: list of importing files with line numbers

**Token cost:** ~400 tokens vs thousands for manual grep + read

---

### 5. Blast Radius — What breaks if I change this symbol?

This is the high-value workflow that plain Grep cannot do alone.

**Workflow (3-step):**

**Step 1 — Direct references**
`Grep` for the symbol name across the codebase. Use `output_mode: "content"` + `head_limit: 30` to cap output.

**Step 2 — Transitive importers**
For each file found in Step 1, run workflow #4 (Find Importers) to get files that depend on those files.

**Step 3 — Classify impact**
Categorize results:

| Category | Description |
|----------|-------------|
| **Direct callers** | Files that call the symbol |
| **Direct inheritors** | Classes extending/including the symbol's class |
| **Transitive dependents** | Files importing direct callers (2nd degree) |
| **Test files** | Tests that exercise the symbol |

**Output format:**
```
Blast radius for `symbolName`:
  Direct callers (N files):
    - path/file.rb:42 — method_that_calls_it
    - path/other.rb:15 — another_caller
  Inheritors (N files):
    - path/child.rb:3 — class ChildClass < ParentClass
  Transitive (N files):
    - path/entry.rb:1 — imports direct caller
  Tests (N files):
    - spec/symbol_spec.rb:10
```

**Cap:** Stop at 2 degrees of separation. Beyond that, flag "high fan-out — consider subagent for full analysis."

**Token cost:** ~1500 tokens for moderate codebase vs unbounded manual exploration

---

### 6. Class Hierarchy — Inheritance chain

**Workflow:**
1. Find class definition: `Grep` for `class symbolName`
2. Extract parent: parse `< ParentClass` (Ruby), `extends Parent` (JS/TS/Java), `: Parent` (Python), etc.
3. Recurse: find parent's definition, extract its parent
4. Find children: `Grep` for classes extending `symbolName`

**Output format:**
```
Hierarchy for ClassName:
  GrandParent
    Parent
      > ClassName  (you are here)
        ChildA
        ChildB
```

**Token cost:** ~600 tokens for 3-level hierarchy

---

## When to Use vs When Not To

| Use code-xray when... | Use Read/Grep directly when... |
|----------------------|-------------------------------|
| Exploring unfamiliar codebase | You know exactly which file and lines |
| Need to understand impact before refactoring | Simple one-file edit |
| Codebase > 50 files | Small project < 20 files |
| Need structure, not content | Need full file content anyway |
| Answering "what calls X?" or "what breaks?" | Answering "what does this file do?" |

## Anti-Patterns

- Do NOT run all 6 workflows preemptively. Run only what's asked.
- Do NOT recurse blast radius beyond 2 degrees without user confirmation.
- Do NOT use ctags if Grep achieves the same result — ctags adds a Bash call.
- Cap all Grep results with `head_limit`. Never return unbounded search results.
