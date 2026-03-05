---
name: qwickapps-server
description: >
  This skill should be used when building or modifying the gateway layer for any QwickApps product
  using @qwickapps/server. Covers: createGateway configuration, MountedAppConfig (proxy and static
  sources), controlPanel setup, available built-in plugins, WebSocket proxying, and guard patterns.
  Invoke before writing any gateway.ts or server entry point.
---

> **Setup:** For initial project setup (env, port scheme, package.json scripts), start with the `use-stack` skill.

# Building with @qwickapps/server

This skill guides gateway and server development using `@qwickapps/server`. All APIs are verified from production clients (authkeaper, work-macha).

---

## 1. Port Scheme

Every QwickApps product follows a consistent port layout:

```
PORT        → Gateway (public-facing, proxies everything)
PORT + 1    → Control Panel internal HTTP server
PORT + 2+   → App services (Payload, Next.js, etc.)
```

**Example with PORT=3400:**
```
3400 → Gateway (createGateway listens here)
3401 → Control Panel internal server
3402 → Payload/Next.js application
```

For the complete `.env.local` template and port scheme details, see `use-stack` skill and `references/qwickapps-full-stack.md`.

---

## 2. createGateway — Full Interface

```typescript
import { createGateway } from '@qwickapps/server';

const gateway = createGateway({
  port: Number(process.env.PORT) || 3000,    // Gateway port (public-facing)
  productName: 'My App',                      // Display name in control panel
  version: process.env.npm_package_version,   // Version string (optional)
  logoIconUrl: '/cpanel/logo.svg',            // Logo shown in control panel header

  // Proxy routes to backend services
  apps: [...],

  // Built-in control panel
  controlPanel: { ... },

  // Optional: what to show at root path (/) when no app is mounted there
  frontendApp: { ... },
});

await gateway.start();
```

**GatewayInstance returned:**
```typescript
{
  app: Application;       // Express app
  server: Server | null;
  start: () => Promise<void>;
  stop: () => Promise<void>;
  port: number;
}
```

---

## 3. apps[] — Mounted App Configuration

Each entry in `apps` mounts a service at a path. Two source types: `proxy` and `static`.

### Proxy Source (most common)

```typescript
apps: [
  {
    path: '/api',
    name: 'API Service',
    source: {
      type: 'proxy',
      target: `http://localhost:${payloadPort}`,  // PORT + 2
      ws: true,    // Enable WebSocket proxy (needed for HMR in dev)
    },
    // stripPrefix: true (default) — strips /api before forwarding
  },
]
```

### Static Source

```typescript
apps: [
  {
    path: '/docs',
    name: 'Documentation',
    source: {
      type: 'static',
      directory: join(__dirname, '../dist-docs'),
      spa: true,   // Serve index.html for all paths (SPA mode)
    },
  },
]
```

### Full MountedAppConfig Interface

```typescript
interface MountedAppConfig {
  path: string;             // Mount path (e.g., '/api', '/admin', '/')
  name?: string;            // Display name in control panel

  source:
    | { type: 'proxy'; target: string; ws?: boolean }
    | { type: 'static'; directory: string; spa?: boolean };

  stripPrefix?: boolean;    // Strip path prefix when proxying (default: true)
  guard?: GuardConfig;      // Route-level auth guard
  maintenance?: MaintenanceConfig;
  fallback?: FallbackConfig;
}
```

---

## 4. controlPanel — Control Panel Configuration

```typescript
controlPanel: {
  enabled: true,                  // Default: true
  path: '/cpanel',                // Mount path for control panel UI
  port: Number(process.env.PORT) + 1,  // Internal server port (PORT + 1)

  // Auth guard for control panel
  guard: {
    type: 'basic',
    username: process.env.ADMIN_USERNAME || 'admin',
    password: process.env.ADMIN_PASSWORD,
    realm: 'My App Control Panel',
    excludePaths: ['/health', '/api', '/assets'],
  },

  // Built-in plugins (monitoring, management)
  plugins: [
    { plugin: createHealthPlugin() },
    { plugin: createDiagnosticsPlugin() },
    { plugin: createPostgresPlugin({
      connectionString: process.env.DATABASE_URI,
    })},
    { plugin: createLogsPlugin() },
    { plugin: createConfigPlugin({
      config: { /* key-value pairs to display */ },
      maskKeys: ['ADMIN_PASSWORD', 'PAYLOAD_SECRET', 'DATABASE_URI'],
    })},
  ],

  // Quick links shown in control panel sidebar
  links: [
    { label: 'App Home', url: '/' },
    { label: 'API Health', url: '/api/health' },
    { label: 'Payload Admin', url: '/admin' },
  ],
}
```

---

## 5. Available Built-in Plugins

Import from `@qwickapps/server`:

| Plugin | Import | Purpose |
|--------|--------|---------|
| `createHealthPlugin` | `@qwickapps/server` | Health check dashboard |
| `createDiagnosticsPlugin` | `@qwickapps/server` | System diagnostics |
| `createConfigPlugin` | `@qwickapps/server` | Config viewer with masking |
| `createLogsPlugin` | `@qwickapps/server` | Log viewer |
| `createPostgresPlugin` | `@qwickapps/server` | PostgreSQL connection monitor |
| `createCachePlugin` | `@qwickapps/server` | Redis/cache connection monitor |
| `createRateLimitPluginFromEnv` | `@qwickapps/server` | Rate limiting |
| `createUsersPlugin` | `@qwickapps/server` | User management |
| `createBansPlugin` | `@qwickapps/server` | User ban management |
| `createEntitlementsPlugin` | `@qwickapps/server` | Entitlements system |

---

## 6. Complete gateway.ts Example

```typescript
// gateway.ts
import { createGateway, createHealthPlugin, createPostgresPlugin,
         createLogsPlugin, createConfigPlugin, createDiagnosticsPlugin } from '@qwickapps/server';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const gatewayPort = Number(process.env.PORT) || 3400;
const appPort = gatewayPort + 2;     // Next.js/Payload

const gateway = createGateway({
  port: gatewayPort,
  productName: 'My App',
  version: process.env.npm_package_version,
  logoIconUrl: '/cpanel/logo.svg',

  apps: [
    {
      path: '/',                     // Proxy everything at root to Next.js
      name: 'Next.js App',
      source: {
        type: 'proxy',
        target: `http://localhost:${appPort}`,
        ws: true,
      },
    },
  ],

  controlPanel: {
    enabled: true,
    path: '/cpanel',
    port: gatewayPort + 1,

    guard: {
      type: 'basic',
      username: process.env.ADMIN_USERNAME || 'admin',
      password: process.env.ADMIN_PASSWORD || 'changeme',
      realm: 'My App Control Panel',
      excludePaths: ['/health', '/_next', '/api', '/favicon.ico'],
    },

    plugins: [
      { plugin: createHealthPlugin() },
      { plugin: createDiagnosticsPlugin() },
      { plugin: createPostgresPlugin({ connectionString: process.env.DATABASE_URI }) },
      { plugin: createLogsPlugin() },
      { plugin: createConfigPlugin({
        config: {
          PORT: process.env.PORT,
          NODE_ENV: process.env.NODE_ENV,
          APP_URL: process.env.NEXT_PUBLIC_APP_URL,
        },
        maskKeys: ['DATABASE_URI', 'PAYLOAD_SECRET', 'ADMIN_PASSWORD'],
      })},
    ],

    links: [
      { label: 'App', url: '/' },
      { label: 'Payload Admin', url: '/admin' },
    ],
  },
});

gateway.start().then(() => {
  console.log(`Gateway running on port ${gatewayPort}`);
});
```

For migration workflow details, see `qwickapps-cms` skill.

---

## 7. WebSocket Proxy for Next.js HMR

When developing with Next.js, HMR requires WebSocket proxy support. Set `ws: true` on the app
that proxies to Next.js. This is handled automatically in `createGateway`.

```typescript
source: {
  type: 'proxy',
  target: `http://localhost:${appPort}`,
  ws: true,    // REQUIRED for Next.js HMR to work through the gateway
}
```

---

## 8. Route Guards

Guards protect specific mounted paths. Apply at `controlPanel.guard` or `apps[].guard`.

```typescript
guard: {
  type: 'basic',                          // HTTP Basic Auth
  username: process.env.ADMIN_USERNAME,
  password: process.env.ADMIN_PASSWORD,
  realm: 'Protected Area',
  excludePaths: ['/health', '/api/public'], // Paths that bypass the guard
}
```

---

## 9. Common Mistakes

- **Do not** use PORT directly for Payload/Next.js — it conflicts with the gateway. Always use `PORT + 2`.
- **Do not** expose the control panel port (PORT + 1) externally — it is an internal server.
- **Do not** set `stripPrefix: false` on proxied apps unless the target service expects the full path.
- **Do not** start Next.js and gateway on the same port — the gateway must be on PORT, Next.js on PORT+2.
- **Do not** skip `ws: true` on the Next.js proxy during development — HMR will fail.
