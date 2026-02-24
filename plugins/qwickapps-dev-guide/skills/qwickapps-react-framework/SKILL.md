---
name: qwickapps-react-framework
description: >
  This skill should be used when setting up the frontend application shell for any QwickApps product
  using `@qwickapps/react-framework`. Covers: QwickApp wrapper (required for every app), navigation
  items (MenuItem format), enableScaffolding (app bar + sidebar), theme CSS variables (--theme-*),
  and framework component imports. Invoke before creating any layout component or app shell.
  Use alongside qwickapps-cms and qwickapps-ux-design.
---

> **Setup:** For initial project setup (env, config, package.json scripts), start with the `use-stack` skill.

# Building the Frontend App Shell with @qwickapps/react-framework

This skill covers the `QwickApp` wrapper and app shell setup using `@qwickapps/react-framework`.

---

## 1. QwickApp — Required Root Wrapper

Every QwickApps frontend must be wrapped in `QwickApp`. This provides:
- Theme system (light/dark/system, palette)
- App context (`useQwickApp` hook)
- Optional scaffolding (app bar + sidebar nav)
- Routing integration

**Import:**

```typescript
import { QwickApp } from '@qwickapps/react-framework';
```

### Full Props Interface

```typescript
interface QwickAppProps {
  // App Identity
  appName?: string;                    // Display name (used in title, app bar)
  appId?: string | true | false;       // Storage key prefix for persisted state
  appVersion?: string;                 // Version string

  // Theme
  defaultTheme?: 'light' | 'dark' | 'system';    // Default: 'system'
  defaultPalette?: string;                         // Default palette name
  showThemeSwitcher?: boolean;                     // Default: false
  showPaletteSwitcher?: boolean;                   // Default: false

  // Scaffolding (Nav)
  enableScaffolding?: boolean;                     // Enable app bar + sidebar (default: false)
  navigationItems?: MenuItem[];                    // Primary nav items
  appBar?: ScaffoldProps['appBar'];                // App bar customization
  showAppBar?: boolean;                            // Default: true
  appBarHeight?: number;                           // Default: 64

  // Callbacks
  onLogoClick?: () => void;

  // Content
  children?: React.ReactNode;
  className?: string;
  footerContent?: React.ReactNode;

  // Advanced
  logo?: React.ReactNode;              // Custom logo component
  config?: AppConfig;                  // Config instance (overrides individual props)
}
```

---

## 2. Navigation Items Format

```typescript
interface MenuItem {
  label: string;          // Display text
  route: string;          // URL path (e.g., '/', '/dashboard', '/repos')
  icon?: string;          // Material icon name (e.g., 'home', 'search', 'settings')
  children?: MenuItem[];  // Sub-menu items
}
```

### Marketing Site Navigation

```typescript
const marketingNav: MenuItem[] = [
  { label: 'Home', route: '/', icon: 'home' },
  { label: 'Features', route: '/features', icon: 'star' },
  { label: 'Pricing', route: '/pricing', icon: 'payments' },
  { label: 'Sign In', route: '/auth/login', icon: 'login' },
];
```

### Dashboard Navigation (authenticated area)

```typescript
const dashboardNav: MenuItem[] = [
  { label: 'Dashboard', route: '/dashboard', icon: 'dashboard' },
  { label: 'Repositories', route: '/repositories', icon: 'source' },
  { label: 'Documents', route: '/documents', icon: 'description' },
  { label: 'Query', route: '/query', icon: 'search' },
  { label: 'Settings', route: '/settings', icon: 'settings' },
];
```

### Nested Navigation

```typescript
const nav: MenuItem[] = [
  {
    label: 'Services',
    route: '/services',
    icon: 'build',
    children: [
      { label: 'Consulting', route: '/services/consulting' },
      { label: 'Development', route: '/services/development' },
    ],
  },
];
```

---

## 3. Marketing Site App Shell Pattern

For marketing/public pages (no auth required, no persistent nav scaffolding).
Navigation is driven by CMS via `ServerQwickApp` — see `qwickapps-cms`.

```tsx
// src/components/MarketingClientApp.tsx
'use client';

import { QwickApp } from '@qwickapps/react-framework';

interface MarketingClientAppProps {
  children: React.ReactNode;
  navigationItems?: MenuItem[];
  theme?: 'light' | 'dark' | 'system';
}

export function MarketingClientApp({ children, navigationItems, theme = 'system' }: MarketingClientAppProps) {
  return (
    <QwickApp
      appId="com.myapp.website"
      appName="My App"
      defaultTheme={theme}
      enableScaffolding={true}
      navigationItems={navigationItems}
      showThemeSwitcher={false}
    >
      {children}
    </QwickApp>
  );
}
```

---

## 4. Dashboard App Shell Pattern

For authenticated dashboard areas with sidebar navigation.

```tsx
// src/components/DashboardClientApp.tsx
'use client';

import { QwickApp } from '@qwickapps/react-framework';
import type { MenuItem } from '@qwickapps/react-framework';

const dashboardNav: MenuItem[] = [
  { label: 'Dashboard', route: '/dashboard', icon: 'dashboard' },
  { label: 'Repositories', route: '/repositories', icon: 'source' },
  { label: 'Query', route: '/query', icon: 'search' },
  { label: 'Settings', route: '/settings', icon: 'settings' },
];

export function DashboardClientApp({ children }: { children: React.ReactNode }) {
  return (
    <QwickApp
      appId="com.myapp.dashboard"
      appName="My App"
      defaultTheme="dark"
      enableScaffolding={true}
      navigationItems={dashboardNav}
      showThemeSwitcher={true}
    >
      {children}
    </QwickApp>
  );
}
```

---

## 5. App Bar Customization

Customize the app bar with actions (buttons, icons) on the right side.

```tsx
<QwickApp
  appName="My App"
  enableScaffolding={true}
  navigationItems={nav}
  appBar={{
    actions: (
      <>
        <IconButton sx={{ color: 'var(--theme-on-surface)' }}>
          <NotificationsIcon />
        </IconButton>
        <Button variant="contained" href="/auth/login">Sign In</Button>
      </>
    ),
  }}
>
  {children}
</QwickApp>
```

---

## 6. Theme CSS Variables

All colors must use `--theme-*` CSS variables. Never use hex, rgba, or color strings directly.
These variables are applied via `data-theme` and `data-palette` attributes on `<html>`.

### Available Variables

```css
/* Primary Brand Colors */
var(--theme-primary)              /* Main brand color */
var(--theme-on-primary)           /* Text/icons on primary background */
var(--theme-primary-container)    /* Lighter primary container */
var(--theme-on-primary-container) /* Text on primary container */

/* Secondary Colors */
var(--theme-secondary)
var(--theme-on-secondary)
var(--theme-secondary-container)
var(--theme-on-secondary-container)

/* Surfaces */
var(--theme-background)           /* Page background */
var(--theme-on-background)        /* Text on page background */
var(--theme-surface)              /* Card/panel background */
var(--theme-on-surface)           /* Text on surface */
var(--theme-surface-variant)      /* Alternate surface */
var(--theme-surface-elevated)     /* Elevated surface (modals, dropdowns) */

/* Borders */
var(--theme-outline)              /* Default border color */
var(--theme-border-main)          /* Main border */

/* Feedback */
var(--theme-error)
var(--theme-on-error)
var(--theme-success)
var(--theme-warning)

/* Text */
var(--theme-text-secondary)       /* Secondary/muted text */
```

### Usage in sx Props

```tsx
// Correct — all via CSS variables
<Box sx={{
  backgroundColor: 'var(--theme-surface)',
  color: 'var(--theme-on-surface)',
  borderColor: 'var(--theme-outline)',
  '&:hover': {
    backgroundColor: 'var(--theme-surface-variant)',
  },
}}>
  Content
</Box>
```

---

## 7. Framework Component Imports

All UI components import from `@qwickapps/react-framework`:

```typescript
// Layout
import { Section, GridLayout, GridCell, Page, HeroBlock } from '@qwickapps/react-framework';

// Content
import { Text, Button, FeatureCard, FeatureGrid, Markdown, Footer } from '@qwickapps/react-framework';

// Commerce
import { ProductCard } from '@qwickapps/react-framework';

// Forms
import { FormField, FormSelect, FormCheckbox, Captcha } from '@qwickapps/react-framework';

// Utils
import { iconMap } from '@qwickapps/react-framework';
```

Never import from `@mui/material` or `@mui/icons-material` — invoke `find-component` first.
If a component is missing, invoke `extend-framework`.

---

## 8. useQwickApp Hook

Access and update app config from any child component:

```typescript
import { useQwickApp } from '@qwickapps/react-framework';

function MyComponent() {
  const {
    appName,
    enableScaffolding,
    navigationItems,
    showAppBar,
    updateConfig,    // Dynamically update app config
  } = useQwickApp();

  // Example: show/hide nav based on auth state
  useEffect(() => {
    if (isAuthenticated) {
      updateConfig({ navigationItems: dashboardNav });
    }
  }, [isAuthenticated]);
}
```

---

## 9. Next.js Integration Pattern

For project setup (env, package.json scripts, payload.config.ts), see `use-stack` skill and
`references/qwickapps-full-stack.md`.

In a Next.js app with App Router, the `QwickApp` wrapper goes in the client layout:

```tsx
// app/(app)/layout.tsx (server component — uses ServerQwickApp from @qwickapps/cms)
// The ServerQwickApp internally creates QwickApp via ClientSideQwickApp.
// Do NOT create a separate QwickApp wrapper in the layout — ServerQwickApp handles it.
```

For dashboard routes that don't go through `ServerQwickApp` (auth-required areas):

```tsx
// app/(dashboard)/layout.tsx
import { DashboardClientApp } from '@/components/DashboardClientApp';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <DashboardClientApp>{children}</DashboardClientApp>;
}
```

---

## 10. Common Mistakes

- **Do not** nest `QwickApp` inside `QwickApp` — only one wrapper per route group.
- **Do not** use `QwickApp` in server components (`'use server'` or `async function`). It is a client component.
- **Do not** hardcode colors with hex or rgba. Use `var(--theme-*)` exclusively.
- **Do not** import MUI components directly. Import from `@qwickapps/react-framework` or invoke `find-component`.
- **Do not** set `enableScaffolding={false}` if you need the app bar — set it to `true` with your `navigationItems`.
- **Do not** create a duplicate `QwickApp` wrapper when using `ServerQwickApp` from `@qwickapps/cms` — `ServerQwickApp` already creates the client-side wrapper internally.
