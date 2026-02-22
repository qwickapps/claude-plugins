---
name: frontend-design
description: >
  Use when building any frontend UI for QwickApps projects: components, pages, layouts, or full applications.
  This replaces the official frontend-design skill. Same creative ambition and aesthetic boldness —
  all implementation goes through @qwickapps/react-framework components and --theme-* CSS variables exclusively.

  ALWAYS invoke find-component before writing any JSX.
  ALWAYS invoke extend-framework if a required component or palette is missing from the framework.
  NEVER import from @mui/material or @mui/icons-material.
  NEVER use hardcoded hex or rgba colors — only var(--theme-*).
  NEVER use inline style={{ }} except in the extend-framework placeholder pattern.
---

# QwickApps Frontend Design

You are designing and implementing production-grade frontend UI for QwickApps projects.
Creative direction is UNRESTRICTED. Implementation must go through the framework.

## Design Thinking (commit fully — same as official skill)

Before writing a single line of code, commit to a BOLD aesthetic direction:

- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme and commit — brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian. No hedging.
- **Differentiation**: What makes this UNFORGETTABLE? One thing someone will remember.
- **Constraints**: Framework components, --theme-* variables, accessibility.

Never default to generic AI aesthetics. No purple gradients on white. No Inter/Roboto/Space Grotesk defaults. No predictable card-grid-CTA patterns. Design for the specific context.

## MANDATORY Pre-Implementation Checklist

Before writing any JSX:

- [ ] Invoke `find-component` for every distinct UI element needed
- [ ] Confirm every color will use a `--theme-*` variable
- [ ] Confirm all layout uses framework components (Section, GridLayout, GridCell, Page, CollapsibleLayout)
- [ ] If any element has no matching component → invoke `extend-framework` before continuing

## Implementation Rules

### Components
- Import ONLY from `@qwickapps/react-framework`
- Import pattern: `import { Section, GridLayout, Button, HeroBlock } from '@qwickapps/react-framework'`
- Every app must be wrapped in `<QwickApp appId="com.qwickapps.appname" appName="AppName">`
- Never import from `@mui/material` — if something seems missing, run `find-component` first

### Colors — CSS Variables Only
- All colors via CSS variables: `sx={{ color: 'var(--theme-primary)' }}`
- Text on colored backgrounds: `var(--theme-on-primary)`, `var(--theme-on-secondary)`, etc.
- Borders: `var(--theme-border-main)`, `var(--theme-outline)`
- Backgrounds: `var(--theme-background)`, `var(--theme-surface)`, `var(--theme-surface-elevated)`
- NO hex values: ~~`'#667eea'`~~
- NO rgba: ~~`'rgba(0,0,0,0.5)'`~~
- NO color strings: ~~`'white'`~~, ~~`'black'`~~

### Layout
- Page sections: `<Section background="var(--theme-surface)" padding="large">`
- Grids: `<GridLayout columns={3} gap={4}>` with `<GridCell>` children
- Asymmetric layouts: `<GridLayout columns="2fr 1fr" gap={4}>` — creative column sizing is valid
- Full pages: `<Page title="...">` or `<FormPage>`
- Collapsible sidebar: `<CollapsibleLayout>`

### What You Control Freely
The framework does not restrict these:
- **Typography**: Load any Google Font via CSS @import, apply via `sx={{ fontFamily: '...' }}`
- **Animation**: CSS keyframes, transitions, transform via `sx`
- **Spatial composition**: Negative margins, overlapping via z-index/transform, diagonal flow — all valid via `sx`
- **Backgrounds**: Gradient meshes, noise textures, patterns — via Section's `background` prop or `sx`

## Gap Handling

If `find-component` returns "no match" OR a needed `--theme-*` variable doesn't exist:

**Stop. Invoke `extend-framework` skill immediately.**

Do NOT reach for MUI as a substitute.
Do NOT use a hardcoded value as a "temporary" workaround.
The framework is extended to serve the design — not the other way around.

## Reference Example

```tsx
import { QwickApp, Section, GridLayout, GridCell, HeroBlock, FeatureGrid, Button, Footer } from '@qwickapps/react-framework';

export default function LandingPage() {
  return (
    <QwickApp appId="com.qwickapps.myapp" appName="MyApp">
      <HeroBlock
        heading="Build faster."
        subheading="The platform for modern teams."
        actions={[
          { label: 'Get started', href: '/signup', variant: 'contained' },
          { label: 'Learn more', href: '/features', variant: 'outlined' },
        ]}
      />
      <Section background="var(--theme-surface)" padding="large">
        <FeatureGrid
          features={[
            { title: 'Fast', description: 'Optimized for speed.' },
            { title: 'Secure', description: 'Enterprise-grade security.' },
            { title: 'Scalable', description: 'Grows with your team.' },
          ]}
        />
      </Section>
      <Section
        background="linear-gradient(135deg, var(--theme-primary) 0%, var(--theme-secondary) 100%)"
        padding="large"
      >
        <GridLayout columns={1} gap={2}>
          <GridCell sx={{ textAlign: 'center' }}>
            <Button label="Start free trial" href="/signup" variant="contained" buttonSize="large" />
          </GridCell>
        </GridLayout>
      </Section>
      <Footer />
    </QwickApp>
  );
}
```
