# Large / Comprehensive Diagram Strategy

**For comprehensive or technical diagrams, build the JSON one section at a time.** Do NOT attempt to generate the entire file in a single pass. This is a hard constraint — Claude Code has a ~32,000 token output limit per response, and a comprehensive diagram easily exceeds that in one shot.

## The Section-by-Section Workflow

### Phase 1: Build each section

1. **Create the base file** with the JSON wrapper (`type`, `version`, `appState`, `files`) and the first section of elements.
2. **Add one section per edit.** Each section gets its own dedicated pass — think carefully about layout, spacing, and how this section connects to what's already there.
3. **Use descriptive string IDs** (e.g., `"trigger_rect"`, `"arrow_fan_left"`) so cross-section references are readable.
4. **Namespace seeds by section** (e.g., section 1 uses 100xxx, section 2 uses 200xxx) to avoid collisions.
5. **Update cross-section bindings** as you go. When a new element needs to bind to one from a previous section, edit the earlier element's `boundElements` array at the same time.

### Phase 2: Review the whole

After all sections are in place, read through the complete JSON and check:
- Are cross-section arrows bound correctly on both ends?
- Is the overall spacing balanced, or are some sections cramped while others have too much whitespace?
- Do IDs and bindings all reference elements that actually exist?

Fix any alignment or binding issues before rendering.

### Phase 3: Render & validate

Run the render-view-fix loop (see `references/render-validate.md`). This is where you'll catch visual issues not obvious from JSON — overlaps, clipping, imbalanced composition.

## Section Boundaries

Plan sections around natural visual groupings. A typical large diagram might split into:

- **Section 1**: Entry point / trigger
- **Section 2**: First decision or routing
- **Section 3**: Main content (hero section — may be the largest)
- **Section 4-N**: Remaining phases, outputs, etc.

Each section should be independently understandable: its elements, internal arrows, and any cross-references to adjacent sections.

## What NOT to Do

- **Don't generate the entire diagram in one response.** You will hit the output token limit and produce truncated, broken JSON.
- **Don't use a coding agent** to generate the JSON. The agent won't have sufficient context, and coordination overhead negates any benefit.
- **Don't write a Python generator script.** Templating and coordinate math introduce indirection that makes debugging harder. Hand-crafted JSON with descriptive IDs is more maintainable.
