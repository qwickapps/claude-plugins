# QwickApps Full Stack Setup

This reference provides the single authoritative configuration for a full QwickApps product
using all three packages: `@qwickapps/cms`, `@qwickapps/server`, and `@qwickapps/react-framework`.

All configuration examples assume the "Full Product" stack combination. For subset
combinations, omit the sections that do not apply.

---

## Port Scheme

Every QwickApps product follows a consistent port layout:

```
PORT        -> Gateway (public-facing, proxies everything)
PORT + 1    -> Control Panel internal HTTP server
PORT + 2+   -> App services (Payload, Next.js, etc.)
```

**Example with PORT=3400:**

| Port | Service | Access |
|------|---------|--------|
| 3400 | Gateway (createGateway) | Public-facing, proxies all routes |
| 3401 | Control Panel internal server | Internal only, not exposed externally |
| 3402 | Payload/Next.js application | Accessed through gateway proxy |

Next.js must use `PORT + 2` to avoid conflict with the gateway's internal control panel
server on `PORT + 1`.

---

## Environment Variables (.env.local)

Complete template for a full-stack QwickApps product:

```env
# Gateway
PORT=3400

# Payload CMS
PAYLOAD_SERVICE_URL=http://localhost:3402
DATABASE_URI=postgresql://postgres:postgres@localhost:5432/myapp_local
PAYLOAD_SECRET=your-secret-key-change-in-production

# Control Panel
ADMIN_USERNAME=admin
ADMIN_PASSWORD=changeme

# Next.js
NEXT_PUBLIC_APP_URL=http://localhost:3400
```

**Notes:**
- `PORT` is the gateway port. All other ports derive from it.
- `PAYLOAD_SERVICE_URL` points to the Next.js/Payload service on PORT+2.
- `DATABASE_URI` uses the standard PostgreSQL connection string format.
- `PAYLOAD_SECRET` must be unique per environment. Generate with `openssl rand -base64 32`.
- `ADMIN_USERNAME` and `ADMIN_PASSWORD` protect the control panel (HTTP Basic Auth).

---

## package.json Scripts

Complete scripts section for a full-stack product. Note: `build:turbo` is a monorepo root-level
script (runs turbo to build shared packages like `@qwickapps/cms`). It is not defined in the
client's own package.json.

```json
{
  "scripts": {
    "dev": "pnpm run build:turbo && qwickapps-migrate && concurrently \"next dev -p $((PORT+2))\" \"tsx watch gateway.ts\"",
    "dev:fast": "qwickapps-migrate && concurrently \"next dev -p $((PORT+2))\" \"tsx watch gateway.ts\"",
    "dev:fresh": "pnpm run db:reset && qwickapps-migrate && concurrently \"next dev -p $((PORT+2))\" \"tsx watch gateway.ts\"",
    "dev:local": "qwickapps-migrate && concurrently \"next dev -p $((PORT+2))\" \"tsx watch gateway.ts\"",
    "dev:local:nobuild": "concurrently \"next dev -p $((PORT+2)) --no-turbo\" \"tsx watch gateway.ts\"",
    "start": "concurrently \"next start -p $((PORT+2))\" \"node dist/gateway.js\"",
    "build": "next build && tsc -p tsconfig.gateway.json",
    "migrate:promote": "qwickapps-migrate --promote",
    "db:reset": "payload migrate:reset"
  }
}
```

**Script breakdown:**

| Script | Purpose |
|--------|---------|
| `dev` | Full dev startup: build shared monorepo packages via turbo (root-level script), run migrations, start Next.js + gateway |
| `dev:fast` | Skip monorepo turbo build (use when shared packages are already built) |
| `dev:fresh` | Reset database, run migrations, start fresh |
| `dev:local` | Same as dev:fast (alias for clarity) |
| `dev:local:nobuild` | Skip monorepo build, migrations, and turbopack (fastest restart for local iteration) |
| `start` | Production start: Next.js + gateway from compiled output |
| `build` | Production build: Next.js + gateway TypeScript compilation |
| `migrate:promote` | Copy dev migration from .dev-migrations/ to src/migrations/ |
| `db:reset` | Reset database (drops all tables, re-runs migrations) |

**Key dependencies to include in devDependencies:**
- `concurrently` -- Run Next.js and gateway simultaneously
- `tsx` -- Execute TypeScript gateway in dev mode with watch

---

## payload.config.ts

Complete database adapter configuration:

```typescript
import { buildConfig } from 'payload';
import { postgresAdapter } from '@payloadcms/db-postgres';
import path from 'path';
import { fileURLToPath } from 'url';

const dirname = path.dirname(fileURLToPath(import.meta.url));

export default buildConfig({
  db: postgresAdapter({
    pool: {
      connectionString: process.env.DATABASE_URI || 'postgresql://postgres:postgres@localhost:5432/myapp_local',
    },
    // NEVER use push: true -- it has DDL ordering bugs (FK constraints before CREATE TABLE).
    // Use qwickapps-migrate instead (runs automatically before dev server).
    push: false,
    migrationDir: process.env.DEV_MIGRATION_DIR || path.resolve(dirname, 'migrations'),
  }),

  // Import collections from @qwickapps/cms
  collections: [
    // Add collections here -- see qwickapps-cms skill for available collections
  ],

  // Import globals from @qwickapps/cms
  globals: [
    // Add globals here -- see qwickapps-cms skill for available globals
  ],
});
```

**Critical rules:**
- `push` must be `false` (never `true`, even in dev)
- `migrationDir` must include the `DEV_MIGRATION_DIR` env var override
- The `DEV_MIGRATION_DIR` env var is set automatically by `qwickapps-migrate` at dev startup

---

## .gitignore Entries

Add these entries for QwickApps-specific generated files:

```gitignore
# Ephemeral dev migrations (generated by qwickapps-migrate)
.dev-migrations/
```

---

## Directory Structure

Standard directory layout for a full-stack QwickApps client:

```
my-client/
  .env.local                    # Environment variables (not committed)
  gateway.ts                    # Gateway entry point (@qwickapps/server)
  payload.config.ts             # Payload CMS configuration
  tsconfig.gateway.json         # TypeScript config for gateway compilation
  package.json                  # Scripts, dependencies
  next.config.mjs               # Next.js configuration
  .gitignore                    # Includes .dev-migrations/
  src/
    app/
      (app)/                    # Public app routes (uses ServerQwickApp layout)
        layout.tsx              # ServerQwickApp + FooterFromSettings
        page.tsx                # Home page
        [...slug]/
          page.tsx              # CMS-driven pages via BlockRenderer
      (dashboard)/              # Authenticated dashboard routes
        layout.tsx              # DashboardClientApp wrapper
      admin/                    # Payload admin panel (auto-generated)
    collections/                # Custom Payload collections
      index.ts                  # Re-exports all collections
    globals/                    # Custom Payload globals
    migrations/                 # Committed migrations (from migrate:promote)
      index.ts                  # Auto-generated migration index
    components/                 # React components
  scripts/
    seeds/                      # Database seed scripts
      000.seed-site-settings.mjs
      001.seed-navigation.mjs
      002.seed-footer.mjs
      003.seed-pages.mjs
```

---

## New Project Setup Checklist

Follow these steps to set up a new full-stack QwickApps client:

1. **Create the client directory** in the monorepo under `clients/`
2. **Initialize package.json** with the scripts from this reference
3. **Install dependencies:**
   - `@qwickapps/cms`, `@qwickapps/server`, `@qwickapps/react-framework`
   - `payload`, `@payloadcms/db-postgres`, `@payloadcms/richtext-lexical`
   - `next`, `react`, `react-dom`
   - `concurrently`, `tsx` (devDependencies)
4. **Create .env.local** from the template above
5. **Create payload.config.ts** from the template above, adding collections and globals
6. **Create gateway.ts** -- see `qwickapps-server` skill for the full createGateway example
7. **Create tsconfig.gateway.json** for compiling gateway.ts:
   ```json
   {
     "compilerOptions": {
       "target": "ES2022",
       "module": "NodeNext",
       "moduleResolution": "NodeNext",
       "outDir": "dist",
       "declaration": true,
       "esModuleInterop": true,
       "skipLibCheck": true
     },
     "include": ["gateway.ts"]
   }
   ```
8. **Create Next.js config** (next.config.mjs)
9. **Create app layout** -- see `qwickapps-cms` skill for ServerQwickApp pattern
10. **Add .gitignore entries** from this reference
11. **Run `pnpm dev`** to start the dev server and generate initial migration
12. **Run `pnpm migrate:promote`** to commit the initial migration
13. **Create seed scripts** -- see `qwickapps-cms` skill for seed patterns

---

## Subset Configurations

### CMS Application (no gateway)

Omit from the full setup:
- `gateway.ts` and `tsconfig.gateway.json`
- Gateway-related env vars (`ADMIN_USERNAME`, `ADMIN_PASSWORD`)
- `concurrently` and `tsx` dependencies
- Replace dev scripts with standard Next.js scripts:
  ```json
  {
    "dev": "qwickapps-migrate && next dev",
    "start": "next start",
    "build": "next build"
  }
  ```

### API Service (gateway only)

Omit from the full setup:
- Payload CMS configuration and collections
- Next.js configuration and app directory
- CMS-related env vars (`PAYLOAD_SECRET`, `DATABASE_URI`)
- Migration scripts
- Replace with gateway-only scripts:
  ```json
  {
    "dev": "tsx watch gateway.ts",
    "start": "node dist/gateway.js",
    "build": "tsc -p tsconfig.gateway.json"
  }
  ```
