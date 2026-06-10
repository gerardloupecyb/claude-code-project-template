---
name: excalidraw-diagram
description: Create Excalidraw diagram JSON files that make visual arguments. Use when the user wants to visualize workflows, architectures, or concepts.
---

# Excalidraw Diagram Creator

Generate `.excalidraw` JSON files that **argue visually**, not just display information.

**Setup:** If the user asks you to set up this skill (renderer, dependencies, etc.), see `README.md` for instructions.

## References

Load the file when the situation matches — do not load all files upfront.

| File | Load when |
|------|-----------|
| `references/color-palette.md` | **Always** — read before generating any diagram, single source of truth for all colors |
| `references/element-templates.md` | When generating JSON — copy-paste templates for each element type |
| `references/visual-patterns.md` | When choosing a pattern or shape type during design |
| `references/layout-principles.md` | When deciding container vs free-floating text, or spacing/scale questions |
| `references/evidence-artifacts.md` | For technical/comprehensive diagrams — artifacts + multi-zoom architecture |
| `references/large-diagram-strategy.md` | For comprehensive diagrams — section-by-section workflow |
| `references/render-validate.md` | When running the render loop — full audit steps, fixes, when to stop |
| `references/json-schema.md` | When looking up element property specs |

**Customization:** All colors and brand-specific styles live in `references/color-palette.md`. Edit it to produce diagrams in your own brand style. Everything else is universal design methodology.

---

## Core Philosophy

**Diagrams should ARGUE, not DISPLAY.**

A diagram isn't formatted text. It's a visual argument that shows relationships, causality, and flow that words alone can't express. The shape should BE the meaning.

**The Isomorphism Test**: If you removed all text, would the structure alone communicate the concept? If not, redesign.

**The Education Test**: Could someone learn something concrete from this diagram, or does it just label boxes? A good diagram teaches — it shows actual formats, real event names, concrete examples.

---

## Depth Assessment (Do This First)

**Simple/Conceptual** — use abstract shapes when:
- Explaining a mental model or philosophy
- The audience doesn't need technical specifics
- The concept IS the abstraction (e.g., "separation of concerns")

**Comprehensive/Technical** — use concrete examples when:
- Diagramming a real system, protocol, or architecture
- The diagram will teach or explain (e.g., YouTube video, onboarding doc)
- The audience needs to understand what things actually look like

For technical diagrams: load `references/evidence-artifacts.md` and include evidence artifacts.

---

## Research Mandate (For Technical Diagrams)

**Before drawing anything technical, research the actual specifications.**

If you're diagramming a protocol, API, or framework:
1. Look up the actual JSON/data formats
2. Find the real event names, method names, or API endpoints
3. Understand how the pieces actually connect
4. Use real terminology, not generic placeholders

Bad: `"Protocol" → "Frontend"`
Good: `"AG-UI streams events (RUN_STARTED, STATE_DELTA)" → "CopilotKit renders via createA2UIMessageRenderer()"`

---

## Design Process

### Step 0: Assess Depth
Simple/Conceptual or Comprehensive/Technical? If comprehensive, research first.

### Step 1: Understand Deeply
For each concept, ask:
- What does it **DO**? (not what IS it)
- What relationships exist?
- What's the core transformation or flow?
- **What would someone need to SEE to understand this?**

### Step 2: Map Concepts to Patterns
Load `references/visual-patterns.md` and find the pattern that mirrors each concept's behavior: fan-out, convergence, tree, spiral/cycle, cloud, assembly line, side-by-side, gap/break, lines as structure.

### Step 3: Ensure Variety
Each major concept must use a different visual pattern. No uniform cards or grids.

### Step 4: Sketch the Flow
Mentally trace how the eye moves. There should be a clear visual story.

### Step 5: Generate JSON
Create the Excalidraw elements. For comprehensive diagrams, **load `references/large-diagram-strategy.md`** — build one section at a time, never the entire file in one response.

Use `references/element-templates.md` for copy-paste templates.
Pull colors from `references/color-palette.md`.

### Step 6: Render & Validate (MANDATORY)

```bash
cd .claude/skills/excalidraw-diagram/references && uv run python render_excalidraw.py <path-to-file.excalidraw>
```

Then use the **Read tool** on the output PNG to view it.

Repeat render → view → fix until the diagram looks right. Load `references/render-validate.md` for the full audit checklist, common fixes, and stopping criteria. Typically takes 2-4 iterations.

---

## JSON Structure

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [...],
  "appState": {
    "viewBackgroundColor": "#ffffff",
    "gridSize": 20
  },
  "files": {}
}
```

**Text rules — CRITICAL:** The `text` property contains ONLY readable words.

```json
{
  "id": "myElement1",
  "text": "Start",
  "originalText": "Start"
}
```

Settings: `fontSize: 16`, `fontFamily: 3`, `textAlign: "center"`, `verticalAlign: "middle"`

---

## Quality Checklist

### Depth & Evidence (Check First for Technical Diagrams)
1. **Research done**: Did you look up actual specs, formats, event names?
2. **Evidence artifacts**: Are there code snippets, JSON examples, or real data?
3. **Multi-zoom**: Does it have summary flow + section boundaries + detail?
4. **Concrete over abstract**: Real content shown, not just labeled boxes?
5. **Educational value**: Could someone learn something concrete from this?

### Conceptual
6. **Isomorphism**: Does each visual structure mirror its concept's behavior?
7. **Argument**: Does the diagram SHOW something text alone couldn't?
8. **Variety**: Does each major concept use a different visual pattern?
9. **No uniform containers**: Avoided card grids and equal boxes?

### Container Discipline
10. **Minimal containers**: Could any boxed element work as free-floating text instead?
11. **Lines as structure**: Are tree/timeline patterns using lines + text rather than boxes?
12. **Typography hierarchy**: Are font size and color creating visual hierarchy (reducing need for boxes)?

### Structural
13. **Connections**: Every relationship has an arrow or line
14. **Flow**: Clear visual path for the eye to follow
15. **Hierarchy**: Important elements are larger/more isolated

### Technical
16. **Text clean**: `text` contains only readable words
17. **Font**: `fontFamily: 3`
18. **Roughness**: `roughness: 0` for clean/modern (unless hand-drawn style requested)
19. **Opacity**: `opacity: 100` for all elements (no transparency)
20. **Container ratio**: <30% of text elements should be inside containers

### Visual Validation (Render Required)
21. **Rendered to PNG**: Diagram has been rendered and visually inspected
22. **No text overflow**: All text fits within its container
23. **No overlapping elements**: Shapes and text don't overlap unintentionally
24. **Even spacing**: Similar elements have consistent spacing
25. **Arrows land correctly**: Arrows connect to intended elements without crossing others
26. **Readable at export size**: Text is legible in the rendered PNG
27. **Balanced composition**: No large empty voids or overcrowded regions
