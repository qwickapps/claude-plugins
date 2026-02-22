---
name: extend-framework
description: >
  Use when find-component returns no match, or when the design needs a --theme-* variable,
  palette, or component variant that doesn't exist in @qwickapps/react-framework.
  Guides two paths: inline implementation for small gaps (< 2 hours), or deferred for large gaps.
  NEVER use @mui/material or hardcoded values as workarounds for missing framework pieces.
  The framework is extended to serve the design — not the other way around.
---

# Extend Framework

The design requires something the framework doesn't have. Extend the framework first, then use it.

## Decision: Inline or Deferred?

**Inline (implement now)** when ALL of these are true:
- Implementable in < 2 hours
- No major design decisions needed (clear, well-understood addition)
- Examples: new color palette, new `--theme-*` token, minor component variant (Button size, Section padding value)

**Deferred (document + placeholder)** when ANY of these are true:
- Requires significant design decisions (layout behavior, interaction model, accessibility)
- Needs multiple Storybook stories to document properly
- Cross-cutting changes (affects multiple packages)
- Examples: new data visualization component, complex interactive layout, new form field type

---

## Inline Path

### Step 1: Create a worktree

```bash
cd <qwickapps-monorepo-root>  # Navigate to your local qwickapps monorepo
.claude/scripts/create-worktree.sh framework-add-<name>
cd ../qwickapps-wt-framework-add-<name>
```

### Step 2: Implement the addition

**New `--theme-*` token:**
- File: `packages/qwickapps-react-framework/src/components/QwickApp.css`
- Add the variable in the correct category block under `:root`
- Add it to BOTH light and dark theme selectors

**New palette:**
- File: `packages/qwickapps-react-framework/src/palettes/Palette<Name>.ts`
- Copy an existing palette (e.g. `PaletteOcean.ts`) as a template
- Export from `packages/qwickapps-react-framework/src/palettes/index.ts`

**New component or variant:**
- File: `packages/qwickapps-react-framework/src/components/<category>/<ComponentName>.tsx`
- Follow existing component patterns
- Export from `packages/qwickapps-react-framework/src/index.ts`

### Step 3: Write the Storybook story

File: `packages/qwickapps-react-framework/src/stories/<ComponentName>.stories.tsx`

Every story must include:
- `meta.parameters.docs.description.component` — markdown description
- At least one `Default` story
- At least one story showing real-world use wrapped in `<QwickApp>`

### Step 4: Build and verify

```bash
cd packages/qwickapps-react-framework
pnpm run build
```

### Step 5: Commit and create PR

```bash
git add packages/qwickapps-react-framework/
git commit -m "feat(framework): add <name>"
gh pr create --title "feat(framework): add <name>" \
  --body "Required by design: <brief description>"
```

### Step 6: Update find-component catalog

After the framework PR is merged, update `plugins/qwickapps-ux-design/skills/find-component/SKILL.md` catalog table with the new component/token.

### Step 7: Return to design

Use the new addition in the original design work.

---

## Deferred Path

### Step 1: Document the gap

```
Missing: <ComponentName or token name>
Category: component / token / palette
Purpose: <what it does and why the design needs it>
Props API (if component): <prop1: type — description, prop2: type — description>
Visual description: <detailed description of appearance and behavior>
Design context: <which design/page needs this and why>
```

### Step 2: Create a GitHub issue

```bash
gh issue create \
  --repo qwickapps/qwickapps \
  --label "framework,enhancement" \
  --title "feat(framework): add <ComponentName>" \
  --body "## Missing Framework Component

**Needed by:** <design/page name>
**Purpose:** <what it does>
**Props API:** <list props>
**Visual description:** <detailed description>"
```

Note the issue number.

### Step 3: Insert placeholder in the design

```tsx
{/* TODO: Replace with <ComponentName> once implemented — issue #N */}
<div style={{
  border: '2px dashed var(--theme-border-main)',
  padding: '24px',
  borderRadius: 'var(--theme-border-radius)',
  background: 'var(--theme-surface)'
}}>
  <p style={{ color: 'var(--theme-text-secondary)', margin: 0, textAlign: 'center' }}>
    Placeholder: &lt;ComponentName&gt; (issue #N)
  </p>
</div>
```

Note: `style={{}}` is acceptable ONLY in this placeholder pattern. It will be replaced when the component is implemented.

### Step 4: Continue the design

Proceed with the rest of the design. The placeholder makes the gap visible and trackable.
