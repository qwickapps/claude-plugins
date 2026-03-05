---
name: optimizing-performance
description: >
  This skill should be used when the user asks to optimize, profile, improve performance,
  or speed up any part of the system — whether frontend, backend, database, or infrastructure.
  Also auto-loads when the user reports slowness, high latency, large bundle sizes, excessive
  memory usage, or N+1 query patterns.
  Provides a decision tree and checklist: measure first, identify the real bottleneck,
  apply targeted fixes, verify improvement with the same benchmark.
---

# Optimizing Performance

Follow this process in order. Do not skip to solutions. Do not optimize what has not been measured.

---

## The Core Law

**Measure first. Fix the bottleneck. Measure again.**

Optimizing without measurement is guessing. Guesses waste time and frequently make things worse
by introducing complexity without improving the actual constraint.

The bottleneck is the single resource or operation that limits overall throughput. Optimizing
anything other than the bottleneck produces no improvement.

---

## Phase 1: Measure Before Touching Anything

Before writing a single line of optimization code:

### Establish a baseline benchmark

The benchmark must be repeatable and objective. Document it before starting:

```
Benchmark: [What is being measured]
Method: [How measured — profiler, benchmark script, production trace, browser DevTools]
Environment: [Local, staging, production]
Baseline result: [Specific number — ms, MB, req/s, queries/request]
Date: [When measured]
```

### Choose the right measurement tool

| Area | Tool |
|------|------|
| Frontend rendering | Chrome DevTools Performance panel, Lighthouse |
| Frontend bundle | webpack-bundle-analyzer, `next build` output, Vite rollup stats |
| Network | Chrome DevTools Network panel, WebPageTest |
| Node.js CPU | `node --prof`, Clinic.js, `0x` |
| Node.js memory | `node --inspect` with Chrome heap snapshots |
| Database queries | `EXPLAIN ANALYZE` (PostgreSQL), query logs with durations |
| API latency | `curl -w "%{time_total}"`, wrk, autocannon |
| React components | React DevTools Profiler |

Do not proceed until the baseline is recorded.

---

## Phase 2: Identify the Real Bottleneck

### Decision tree

```
Is the problem on the frontend or backend?
  |
  +-- Frontend: Is it rendering time or network time?
  |     |
  |     +-- Rendering: Go to section 7 (Rendering Performance)
  |     +-- Network: Is it asset size or request count?
  |           |
  |           +-- Asset size: Go to section 6 (Bundle Size)
  |           +-- Request count: Go to section 8 (Network Optimization)
  |
  +-- Backend: Is it CPU, memory, or I/O?
        |
        +-- CPU: Profile with node --prof. Find hot function. Go to section 5 (Caching).
        +-- Memory: Capture heap snapshot. Go to section 6 (Memory Management).
        +-- I/O (database): Run EXPLAIN ANALYZE. Go to section 3 (Database Queries).
        +-- I/O (network calls): Go to section 5 (Caching) or section 8 (Network Optimization).
```

### Red flags that reveal the bottleneck category

- **N+1 queries**: ORM log shows one query per iteration in a loop — database bottleneck
- **Waterfall requests**: Network tab shows sequential requests that could be parallel — network bottleneck
- **Large initial bundle**: Lighthouse shows > 200kB JS on initial load — bundle size bottleneck
- **Re-rendering entire trees**: React Profiler shows full component tree re-renders on minor state changes — rendering bottleneck
- **High time-to-first-byte (TTFB)**: Server takes > 200ms before sending response — backend bottleneck
- **Memory climbing without release**: Heap grows over time, never stabilizes — memory leak

Do not move to solutions until the category is confirmed with measurement evidence.

---

## Phase 3: Apply Targeted Solutions

Work through the relevant section(s) below. Apply only what the measurement indicates is needed.

---

## 3. Database Query Optimization

**The most common backend bottleneck. Always check here first for data-heavy applications.**

### N+1 query detection and elimination

N+1 pattern: one query to fetch a list, then one query per item in the list.

```typescript
// N+1: fetches N additional queries for N orders
const users = await prisma.user.findMany();
for (const user of users) {
  const orders = await prisma.order.findMany({ where: { userId: user.id } }); // N queries
}

// Fixed: single query with include
const users = await prisma.user.findMany({
  include: { orders: true },
});
```

Detection: enable query logging in development. Count queries per request. If query count
scales with result set size, it is N+1.

### Index analysis

Run `EXPLAIN ANALYZE` on slow queries in PostgreSQL:

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending'
ORDER BY created_at DESC;
```

Read the output:
- `Seq Scan` on large tables indicates a missing index
- `Index Scan` confirms index use
- High `rows` estimates vs actual rows indicates stale statistics — run `ANALYZE <table>`

Add indexes to columns used in `WHERE`, `JOIN ON`, and `ORDER BY` clauses of slow queries.
Do not add indexes speculatively — each index has write overhead.

### Pagination

Never `findMany()` without a `limit` on user-facing endpoints. Choose a strategy:

- **Offset pagination**: `LIMIT 20 OFFSET 40` — simple, but slow for large offsets (full scan to offset)
- **Cursor pagination**: `WHERE id > :cursor LIMIT 20` — consistent performance, preferred for large datasets

Apply pagination at the query level. Never fetch all rows and paginate in application code.

### Query optimization checklist

- [ ] No N+1 patterns — use batch fetches or `include`/`join`
- [ ] `EXPLAIN ANALYZE` run on queries taking > 100ms
- [ ] Indexes present on WHERE/JOIN/ORDER BY columns in hot queries
- [ ] `SELECT *` replaced with specific column lists where subset is sufficient
- [ ] All paginated endpoints use `limit`/`offset` or cursor at the database level
- [ ] Aggregate queries (`COUNT`, `SUM`) use indexes where possible

---

## 4. Caching Patterns

**Cache to avoid redundant computation or I/O. Never cache as the first response to a problem.**

### When to cache

Cache when ALL of these are true:
- The operation is expensive (measured — not assumed)
- The result is deterministic for the same inputs
- Stale data is acceptable for a defined window

Do not cache when: data must be real-time, cache invalidation is complex beyond the value of caching,
or the operation is not actually a bottleneck.

### Cache levels (inner to outer)

| Level | Tool | Latency | Use For |
|-------|------|---------|---------|
| In-process (memory) | Map, LRU cache | < 1ms | Computation results, config |
| Shared server cache | Redis, Memcached | 1-5ms | Session data, rate limit counters, shared state |
| HTTP cache | Cache-Control headers | 0ms (client) | Static assets, API responses |
| CDN | Cloudflare, CloudFront | 0ms (edge) | Static files, cacheable API responses |

### Invalidation strategies

Choose an invalidation strategy before building the cache:

- **TTL-based**: Expire after N seconds. Simple. Acceptable for data where some staleness is fine.
- **Event-based**: Invalidate on write. Use when freshness matters and write events are known.
- **Cache-aside with versioning**: Include version key in cache key. Invalidate by incrementing version.

Avoid cache stampede (multiple processes regenerating cache simultaneously on expiry) by using:
- Stochastic TTL jitter (randomize expiry within a range)
- Locking to allow one process to regenerate while others wait

### HTTP caching

```
# Static assets (long-lived, content-addressed URLs)
Cache-Control: public, max-age=31536000, immutable

# API responses (short-lived, private)
Cache-Control: private, max-age=60

# Never cache
Cache-Control: no-store
```

---

## 5. Lazy Loading

**Defer loading resources until they are needed. Reduce initial load cost.**

### Code splitting

Split bundles by route or by logical group. Do not load all application code upfront.

```typescript
// Next.js: automatic per-page splitting (default)
// Manual dynamic import:
const HeavyComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <Spinner />,
});

// Vite / webpack:
const AdminPanel = React.lazy(() => import('./AdminPanel'));
```

### Deferred imports in Node.js

Move expensive imports inside the function that uses them to avoid slowing startup:

```typescript
// Avoid at module level if rarely used:
import sharp from 'sharp'; // loaded on every server startup

// Prefer:
async function resizeImage(buffer: Buffer) {
  const { default: sharp } = await import('sharp'); // loaded only when called
  return sharp(buffer).resize(800).toBuffer();
}
```

### Intersection Observer for UI elements

Load images, charts, or components only when they scroll into view:

```typescript
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      loadComponent();
      observer.unobserve(entry.target);
    }
  });
});
observer.observe(targetElement);
```

Use `loading="lazy"` on `<img>` elements for images below the fold.

---

## 6. Bundle Size

**Smaller bundles load faster on all connections. Analyze before optimizing.**

### Analyze first

```bash
# Next.js
ANALYZE=true next build

# webpack
webpack --profile --json > stats.json
# Open with webpack-bundle-analyzer
```

Look for: duplicate packages, large unused imports, unintentionally bundled server-side modules.

### Tree shaking

Import named exports, not default namespace imports:

```typescript
// Bundler cannot tree-shake this:
import * as _ from 'lodash';

// Bundler can tree-shake:
import { debounce } from 'lodash-es';
// Or use individual package:
import debounce from 'lodash/debounce';
```

### Dynamic imports for large optional features

```typescript
// Load chart library only when user opens chart view
async function renderChart(data: ChartData) {
  const { Chart } = await import('chart.js');
  // ...
}
```

### Bundle size checklist

- [ ] Bundle analyzed — largest contributors identified
- [ ] No duplicate packages (two versions of the same library)
- [ ] No server-side modules in client bundle (check for Node.js built-ins in browser bundle)
- [ ] Named imports used for tree-shakeable libraries
- [ ] Large optional features loaded dynamically
- [ ] Images optimized and served in modern formats (WebP, AVIF)

---

## 7. Memory Management

**Memory leaks degrade performance over time. Identify them with heap snapshots, not guesses.**

### Common leak patterns in Node.js / React

- Event listeners added but never removed
- Timers (`setInterval`, `setTimeout`) not cleared on component unmount
- Closures referencing large objects past their useful lifetime
- Growing Maps/Sets that accumulate entries without eviction
- Module-level caches without size limits

### React: cleanup in effects

```typescript
useEffect(() => {
  const handler = (event: Event) => { /* ... */ };
  window.addEventListener('resize', handler);

  return () => {
    window.removeEventListener('resize', handler); // REQUIRED
  };
}, []);
```

### WeakRef for optional references

Use `WeakRef` when holding a reference to an object that should not prevent garbage collection:

```typescript
const cache = new WeakMap<object, ComputedValue>();
```

### Memory management checklist

- [ ] All `addEventListener` calls paired with `removeEventListener` in cleanup
- [ ] All `setInterval` / `setTimeout` cleared in cleanup or on component unmount
- [ ] In-memory caches have a size limit or TTL eviction policy
- [ ] Heap snapshot taken before and after suspected leak to confirm resolution
- [ ] No circular references in long-lived objects

---

## 8. Network Optimization

**Reduce payload size, reduce round trips, reduce latency.**

### Compression

Enable gzip or Brotli compression on the server for text responses (JSON, HTML, CSS, JS).
Brotli achieves 15-20% better compression than gzip for text content.

```typescript
// Express with compression middleware
import compression from 'compression';
app.use(compression());
```

Verify: `curl -H "Accept-Encoding: br,gzip" -I https://example.com` should return
`Content-Encoding: br` or `Content-Encoding: gzip`.

### CDN for static assets

Serve static assets (JS, CSS, images, fonts) from a CDN. CDN edge nodes are geographically
close to users, reducing latency. Configure long `Cache-Control` TTLs with content-addressed
filenames (hashed filenames) for cache busting.

### Prefetching

```html
<!-- Prefetch the next page the user is likely to visit -->
<link rel="prefetch" href="/next-page" />

<!-- Preconnect to third-party origins used on the page -->
<link rel="preconnect" href="https://api.external.com" />
```

In Next.js, `<Link>` prefetches linked pages by default for links in the viewport.

### HTTP/2 and HTTP/3

Verify the server and CDN support HTTP/2 or HTTP/3. HTTP/2 multiplexes requests over a single
connection, eliminating head-of-line blocking for parallel resource loading.

Reduce unnecessary request round trips: batch API calls, use `Promise.all` for parallel fetches,
avoid sequential waterfalls.

---

## 9. Rendering Performance

**For frontend: minimize work the browser does on each frame.**

### Virtual lists for large datasets

Rendering 1,000 DOM nodes is expensive. Use virtualization to render only the visible window:

```typescript
// react-window
import { FixedSizeList } from 'react-window';

<FixedSizeList height={600} itemCount={items.length} itemSize={50} width="100%">
  {({ index, style }) => <Row style={style} item={items[index]} />}
</FixedSizeList>
```

### Memoization

Prevent re-rendering components or recomputing values when inputs have not changed:

```typescript
// Memoize expensive computation
const sortedItems = useMemo(() => items.slice().sort(compareFn), [items]);

// Memoize component to prevent re-render when parent re-renders
const ItemRow = React.memo(({ item }: { item: Item }) => <Row item={item} />);

// Memoize callback to keep referential identity
const handleClick = useCallback(() => submitForm(formData), [formData]);
```

Apply memoization where the React Profiler shows unnecessary re-renders. Do not apply
speculatively — memoization has memory overhead and can mask bugs if applied incorrectly.

### Debounce and throttle for high-frequency events

```typescript
// Debounce: fire only after user pauses (search input)
const handleSearch = useMemo(
  () => debounce((query: string) => fetchResults(query), 300),
  []
);

// Throttle: fire at most once per interval (scroll handler)
const handleScroll = useMemo(
  () => throttle(() => updateScrollPosition(), 100),
  []
);
```

### Rendering checklist

- [ ] React Profiler shows no unnecessary full-tree re-renders
- [ ] Lists with > 100 items use virtualization
- [ ] Expensive computations wrapped in `useMemo`
- [ ] Frequently created callbacks wrapped in `useCallback` when passed to memoized children
- [ ] High-frequency event handlers debounced or throttled

---

## Phase 4: Verify the Improvement

**Run the same benchmark from Phase 1 after applying changes.**

Record results:

```
Benchmark: [Same description as baseline]
Method: [Same method]
Environment: [Same environment]
Result after optimization: [Specific number]
Improvement: [Percentage or absolute delta]
Date: [When measured]
```

If the improvement is not measurable with the chosen benchmark:
- The wrong bottleneck was targeted — return to Phase 2
- The benchmark method is insufficient — improve the benchmark

Do not claim performance improvement without measurement confirming it.

---

## Performance Gate Before Commit

- [ ] Baseline benchmark documented before any changes
- [ ] Bottleneck identified by measurement, not assumption
- [ ] Fix applied to the measured bottleneck, not a convenient target
- [ ] No premature optimization added (no speculative caching, memoization, or lazy loading without evidence)
- [ ] Post-optimization benchmark shows measurable improvement
- [ ] No N+1 queries introduced (verify with query logging)
- [ ] Bundle size not increased significantly for frontend changes (verify with build output)

If improvement is not verified by measurement, the optimization is incomplete.
