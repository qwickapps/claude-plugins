---
name: build-with-cms
description: >
  Use when building any QwickApps product that integrates with Payload CMS via @qwickapps/cms.
  Covers: ServerQwickApp (server-side settings + nav fetch), BlockRenderer (12 block types from CMS),
  FooterFromSettings (auto-rendered footer), standard Payload collections and globals, and seed patterns.
  Invoke before writing any app layout, page, or CMS seed script.
---

# Building with @qwickapps/cms

This skill guides CMS-integrated app development using `@qwickapps/cms`. All patterns are verified
from production clients (work-macha, faabzi). Read each section that applies to your task.

---

## 1. ServerQwickApp — App Layout

`ServerQwickApp` is a server component that fetches navigation and all 4 CMS globals server-side,
then passes them to `ClientSideQwickApp`. Use it as the root wrapper in `app/(app)/layout.tsx`.

### Props

```typescript
import { ServerQwickApp } from '@qwickapps/cms/nextjs';
import type { Config } from 'payload';

interface ServerQwickAppProps {
  children: ReactNode;
  payloadConfig: Config;       // from configPromise (import configPromise from '@payload-config')
  appBar?: {
    actions?: ReactNode | (() => ReactNode);
  };
  providers?: React.ComponentType<{ children: ReactNode }>;
}
```

### Standard Usage Pattern

```tsx
// app/(app)/layout.tsx
import { ServerQwickApp } from '@qwickapps/cms/nextjs';
import { FooterFromSettings } from '@qwickapps/cms/nextjs/client';
import configPromise from '@payload-config';

export default async function AppRouteLayout({ children }: { children: React.ReactNode }) {
  const config = await configPromise;
  return (
    <ServerQwickApp payloadConfig={config}>
      {children}
      <FooterFromSettings />
    </ServerQwickApp>
  );
}
```

### What ServerQwickApp Does Internally

1. Fetches `navigation` collection (position: "main") for nav items
2. Fetches all 4 globals: `SiteSettings`, `ThemeSettings`, `Integrations`, `AdvancedSettings`
3. Handles Payload init errors gracefully (secret key issues, DB not ready)
4. Falls back to default navigation if CMS data unavailable
5. Passes merged settings to `ClientSideQwickApp` via context

### With Custom App Bar Actions

```tsx
<ServerQwickApp
  payloadConfig={config}
  appBar={{
    actions: (
      <>
        <Button variant="outlined" href="/auth/login">Sign In</Button>
        <Button variant="contained" href="/auth/register">Get Started</Button>
      </>
    )
  }}
>
  {children}
  <FooterFromSettings />
</ServerQwickApp>
```

---

## 2. BlockRenderer — CMS-Driven Pages

`BlockRenderer` renders an array of Payload CMS blocks as QwickApps Framework components.
Use it in page components to render the `layout` field of `Pages` collection documents.

### Props

```typescript
import { BlockRenderer } from '@qwickapps/cms/nextjs/client';

interface BlockRendererProps {
  blocks?: BlockData[];    // layout field from Payload Pages document
  className?: string;
}
```

### Standard Page Pattern

```tsx
// app/(app)/[...slug]/page.tsx
import { getPayload } from 'payload';
import configPromise from '@payload-config';
import { BlockRenderer } from '@qwickapps/cms/nextjs/client';

export default async function Page({ params }: { params: { slug: string[] } }) {
  const payload = await getPayload({ config: await configPromise });
  const slug = params.slug?.join('/') ?? 'home';

  const { docs } = await payload.find({
    collection: 'pages',
    where: { slug: { equals: slug }, status: { equals: 'published' } },
    limit: 1,
  });

  if (!docs[0]) notFound();

  return <BlockRenderer blocks={docs[0].layout} />;
}
```

### Supported Block Types (12 total)

All blocks support: `padding`, `marginTop`, `marginBottom`, `background`, `color`,
`backgroundImage`, `backgroundGradient` (ViewSchema props).

| blockType | Key Fields | Renders As |
|-----------|-----------|-----------|
| `hero` | title, subtitle, backgroundImage, backgroundGradient, blockHeight, textAlign, actions[] | HeroBlock |
| `textSection` | heading, content (Lexical), padding, background, textAlign, maxWidth | Section + Text |
| `featureGrid` | heading, features[], columns, spacing, padding, background | GridLayout + FeatureCard[] |
| `ctaSection` | heading, description, buttons[], padding, background, textAlign | Section + Button[] |
| `image` | image, alt, caption, size | Image |
| `spacer` | height | div |
| `code` | code, language, title, showCopy, showLineNumbers, wrapLines | Paper + code block |
| `productGrid` | heading, products[], variant, columns, spacing, padding, background | GridLayout + ProductCard[] |
| `accordion` | heading, items[], allowMultiple, variant, padding | Section + AccordionItem[] |
| `cardGrid` | heading, cards[], columns, spacing, cardVariant, padding, background | GridLayout + Card[] |
| `form` | form (relationship), overrideHeading, overrideDescription, padding | FormBlockComponent |
| `markdown` | heading, content (string), textAlign, maxWidth, padding | Section + Markdown |

### Seed Data Examples

```javascript
// Seed: home page with blocks
await payload.create({
  collection: 'pages',
  data: {
    title: 'Home',
    slug: 'home',
    status: 'published',
    layout: [
      {
        blockType: 'hero',
        title: 'Welcome to Our App',
        subtitle: 'AI-powered solutions for modern teams',
        blockHeight: 'large',
        backgroundGradient: 'linear-gradient(135deg, var(--theme-primary) 0%, var(--theme-secondary) 100%)',
        actions: [
          { label: 'Get Started', href: '/auth/register', variant: 'contained' },
          { label: 'Learn More', href: '/features', variant: 'outlined' },
        ],
      },
      {
        blockType: 'featureGrid',
        heading: 'Why Choose Us',
        columns: 2,
        features: [
          { icon: 'search', title: 'Semantic Search', description: 'Find anything instantly.' },
          { icon: 'auto_awesome', title: 'AI Analysis', description: 'Powered by Claude.' },
        ],
      },
      {
        blockType: 'ctaSection',
        heading: 'Ready to get started?',
        buttons: [{ label: 'Start Free', href: '/auth/register', variant: 'contained' }],
      },
    ],
  },
});
```

---

## 3. FooterFromSettings — Auto-Rendered Footer

`FooterFromSettings` is a client component with no props. It fetches the `footer` collection
(position: "main") and renders with copyright from `SiteSettings`.

### Usage

```tsx
// Already included in the ServerQwickApp layout pattern above.
// Import path:
import { FooterFromSettings } from '@qwickapps/cms/nextjs/client';
```

### What FooterFromSettings Does

- Fetches footer from `footer` collection (position: "main")
- Replaces `{year}` → current year, `{siteName}` → SiteSettings.siteName
- Shows "Powered by QwickPress" and "Payload CMS" links on right side
- Renders `Footer` component with sections, orientation, variant from CMS data

### Footer Seed Pattern

```javascript
// scripts/seeds/002.seed-footer.mjs
await payload.create({
  collection: 'footer',
  data: {
    name: 'Main Footer',
    position: 'main',
    orientation: 'horizontal',
    showDivider: true,
    sections: [
      {
        title: 'PRODUCT',
        items: [
          { label: 'Home', route: '/' },
          { label: 'Features', route: '/features' },
          { label: 'Pricing', route: '/pricing' },
        ],
      },
      {
        title: 'COMPANY',
        items: [
          { label: 'About', route: '/about' },
          { label: 'Contact', route: '/contact' },
        ],
      },
    ],
  },
});
```

---

## 4. Navigation Seed Pattern

```javascript
// scripts/seeds/001.seed-navigation.mjs
await payload.create({
  collection: 'navigation',
  data: {
    name: 'Main Navigation',
    position: 'main',
    items: [
      { label: 'Home', route: '/', icon: 'home' },
      { label: 'Features', route: '/features', icon: 'star' },
      { label: 'Pricing', route: '/pricing', icon: 'payments' },
      { label: 'Sign In', route: '/auth/login', icon: 'login' },
    ],
  },
});
```

---

## 5. Standard Collections

Import individually from `@qwickapps/cms/collections` or use the combined export.

| Collection | Slug | Key Fields |
|------------|------|-----------|
| `Navigation` | `navigation` | name, position, items[] |
| `Pages` | `pages` | title, slug, status, layout (blocks) |
| `Footer` | `footer` | name, position, orientation, sections[], showDivider |
| `Media` | `media` | filename, alt, url |
| `Users` | `users` | email, role, name |
| `Forms` | `forms` | title, fields[], confirmationType |
| `FormSubmissions` | `form-submissions` | form (rel), submissionData[] |
| `Posts` | `posts` | title, slug, status, content (Lexical) |
| `Products` | `products` | name, slug, price, images[], description |
| `HeroBlocks` | `hero-blocks` | title, subtitle, image, actions[] |
| `HeroSlideshows` | `hero-slideshows` | name, position, slides[] |
| `Features` | `features` | name, icon, title, description |
| `Automations` | `automations` | name, trigger, actions[] |

### Adding to payload.config.ts

```typescript
import {
  Navigation,
  Pages,
  Footer,
  Media,
  Users,
  Forms,
  FormSubmissions,
} from '@qwickapps/cms/collections';

export default buildConfig({
  collections: [Navigation, Pages, Footer, Media, Users, Forms, FormSubmissions],
  // ... rest of config
});
```

---

## 6. Standard Globals

| Global | Slug | Key Fields |
|--------|------|-----------|
| `SiteSettings` | `site-settings` | siteName, description, logo, favicon, copyrightText, contactEmail, socialMedia |
| `ThemeSettings` | `theme-settings` | defaultTheme (light/dark/system), defaultPalette, showThemeSwitcher, showPaletteSwitcher |
| `Integrations` | `integrations` | googleAnalytics, gtm, facebookPixel, captcha, emailSettings |
| `AdvancedSettings` | `advanced-settings` | seo, customScripts, maintenanceMode |

### SiteSettings Seed

```javascript
// scripts/seeds/000.seed-site-settings.mjs
await payload.updateGlobal({
  slug: 'site-settings',
  data: {
    siteName: 'My App',
    description: 'AI-powered solutions for modern teams.',
    copyrightText: '© {year} My App. All rights reserved.',
    contactEmail: 'hello@myapp.com',
  },
});
```

### ThemeSettings Seed

```javascript
await payload.updateGlobal({
  slug: 'theme-settings',
  data: {
    defaultTheme: 'dark',
    defaultPalette: 'primary',
    showThemeSwitcher: false,
    showPaletteSwitcher: false,
  },
});
```

---

## 7. Seed Script Boilerplate

All seed scripts follow this pattern:

```javascript
// scripts/seeds/NNN.seed-description.mjs
import { getPayload } from 'payload';
import { importConfig } from 'payload/node';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const configPath = resolve(__dirname, '../../payload.config.ts');

const config = await importConfig(configPath);
const payload = await getPayload({ config });

try {
  // Your seed logic here
  await payload.create({ collection: 'pages', data: { ... } });
  await payload.updateGlobal({ slug: 'site-settings', data: { ... } });
  console.log('Seed complete');
} catch (error) {
  console.error('Seed failed:', error);
  process.exit(1);
} finally {
  await payload.db?.destroy?.();
  process.exit(0);
}
```

---

## 8. Common Mistakes

- **Do not** call `ServerQwickApp` from a client component (`'use client'`). It is a server component only.
- **Do not** import `FooterFromSettings` from `@qwickapps/cms/nextjs` (server path). Use `@qwickapps/cms/nextjs/client`.
- **Do not** import `BlockRenderer` from `@qwickapps/cms/nextjs` (server path). Use `@qwickapps/cms/nextjs/client`.
- **Do not** hard-code nav items in the app — seed the `navigation` collection so `ServerQwickApp` picks them up automatically.
- **Do not** skip the `status: 'published'` filter on pages queries — draft pages should not render.
