---
name: deploying
description: >
  This skill should be used when setting up or executing a deployment, configuring CI/CD
  pipelines, promoting code between environments, or managing infrastructure for an
  application. Auto-loads when working on Dockerfiles, GitHub Actions workflows, deployment
  scripts, Kubernetes manifests, or environment configuration. Trigger phrases include:
  "deploy", "CI/CD", "pipeline", "staging", "production", "release to", "push to prod",
  "set up deployment", "configure the pipeline", "Dockerfile", "health check",
  "rollback", "blue-green", "canary".
---

# Deploying

Apply this checklist when setting up or executing a deployment. Work through each section
relevant to the deployment at hand. Stop on failures. Fix before proceeding to the next
environment.

---

## 1. CI/CD Pipeline Structure

A well-structured pipeline enforces quality before every deployment. Build it in stages.
Each stage must pass before the next begins.

### Standard Stage Sequence

```
[Build] -> [Test] -> [Lint & Security Scan] -> [Publish Artifact] -> [Deploy: Staging] -> [Smoke Test] -> [Deploy: Production] -> [Verify]
```

Every stage is a job. Jobs within a stage can run in parallel. Stages run sequentially.

### Stage Definitions

**Build**
- Compile the application
- Generate production assets
- Fail fast on syntax errors or missing dependencies

**Test**
- Unit tests (fast, no external dependencies)
- Integration tests (may require service containers)
- Coverage gate: fail if coverage drops below threshold

**Lint and Security Scan**
- Static analysis (ESLint, Pylint, or equivalent)
- Dependency vulnerability audit (`npm audit`, `pip-audit`, or equivalent)
- Secret scanning — ensure no credentials appear in the diff

**Publish Artifact**
- Build and push Docker image to registry
- Tag image with the git SHA and the branch name
- Tag image with `latest` only on main/trunk
- Never publish an untagged or uncommitted image

**Deploy: Staging**
- Apply to staging environment
- Run staging-specific configuration

**Smoke Test**
- Hit the health endpoint
- Run a minimal set of end-to-end tests against staging
- Fail the pipeline if smoke tests fail — do not proceed to production

**Deploy: Production**
- Require explicit approval gate in the pipeline before running
- Apply to production using the same artifact that passed staging

**Verify**
- Post-deploy health check
- Check key metrics for 5-10 minutes
- Automated rollback trigger if health checks fail

### Pipeline Checklist

- [ ] Build, test, lint, and scan run on every pull request
- [ ] Deploy to staging runs on merge to main/trunk
- [ ] Deploy to production requires explicit manual approval
- [ ] All stages share the same Docker image (build once, promote the artifact)
- [ ] Pipeline artifacts (images, build outputs) are immutable after the build stage
- [ ] Failed stages send notifications to the team

---

## 2. Environment Promotion

Code moves in one direction: dev -> staging -> production. Never push directly to
production without passing through staging first.

### Environment Definitions

| Environment | Purpose | Who Deploys | Access |
|-------------|---------|-------------|--------|
| Development | Local or shared dev | Any engineer | Internal |
| Staging | Pre-production validation | CI/CD | Internal |
| Production | Live traffic | CI/CD with approval gate | Public |

### Promotion Rules

- [ ] The same Docker image (same SHA) that passed staging is deployed to production —
      never rebuild for production
- [ ] Environment-specific values (secrets, database URLs, feature flags) are injected
      at runtime via environment variables — not baked into the image
- [ ] Staging environment mirrors production configuration as closely as possible (same
      resources, same dependencies, same infrastructure)
- [ ] No code is deployed to production if staging smoke tests are failing

---

## 3. Deployment Strategies

Choose a strategy based on the risk profile of the release and the available infrastructure.

### Rolling Update (Default)

Replace instances one at a time. Traffic continues flowing to healthy instances throughout.

- Zero downtime for stateless applications
- Risk: a bad deployment affects some users before rollback completes
- Rollback: deploy the previous image

Suitable for: most stateless applications with low release risk.

### Blue-Green Deployment

Maintain two identical environments (blue = current, green = new). Route all traffic to
blue until green is fully deployed and validated, then switch the load balancer to green.

- Zero downtime
- Instant rollback: switch load balancer back to blue
- Cost: requires 2x infrastructure capacity during deployment
- Risk: traffic cut-over is abrupt — all users switch at once

Suitable for: high-traffic systems where partial failure is unacceptable and instant
rollback is required.

### Canary Deployment

Route a small percentage of traffic (1-10%) to the new version. Monitor for errors. Expand
to 25%, 50%, 100% if metrics are healthy.

- Limits blast radius of a bad deployment
- Requires traffic-splitting at the load balancer or service mesh layer
- Rollback: reduce canary weight to 0%

Suitable for: high-risk releases, changes to critical paths, or systems where gradual
validation is more important than speed.

### Checklist for Chosen Strategy

- [ ] Strategy selected based on release risk and infrastructure capability
- [ ] Rollback procedure documented and tested before deployment begins
- [ ] Load balancer or service mesh configured for the chosen strategy
- [ ] Monitoring alerts active before deployment starts

---

## 4. Docker Deployment

### Dockerfile Best Practices

- [ ] Use a specific base image tag — never `FROM node:latest`; use `FROM node:20-alpine`
- [ ] Use multi-stage builds: separate the build stage from the runtime stage
- [ ] The runtime stage contains only what the application needs to run — no build tools,
      no dev dependencies, no source code that is not needed at runtime
- [ ] Run the application as a non-root user:
      `RUN addgroup app && adduser --ingroup app app && USER app`
- [ ] Set `WORKDIR` explicitly; do not rely on the default working directory
- [ ] Copy `package.json` and lockfile before copying source — layer caching installs
      dependencies only when they change
- [ ] Use `COPY --chown=app:app` to avoid root-owned files in the container

### Example Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# Stage 2: Runtime
FROM node:20-alpine AS runner
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --from=builder --chown=app:app /app/package.json ./
USER app
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### .dockerignore

- [ ] `.dockerignore` exists and excludes: `node_modules`, `.git`, `.env*`, `*.log`,
      `coverage`, `.next/cache`, `dist` (if built in the container), `docs`, `tests`
- [ ] Never copy `.env` files into the image — inject secrets at runtime

### Image Tagging

- [ ] Tag with the git commit SHA: `registry/image:abc1234`
- [ ] Tag with branch or release: `registry/image:main`, `registry/image:v1.4.2`
- [ ] Apply `latest` only to the most recent main/trunk build, never to feature branches
- [ ] Record the SHA in deployment metadata so every running instance can be traced to
      its exact source commit

---

## 5. Health Checks

A healthy application answers health checks. A failing health check triggers rollback.

### Probe Types

**Readiness Probe**
Answers: "Is this instance ready to receive traffic?"

- Path: `GET /health/ready` or equivalent
- Returns `200 OK` when all dependencies (database, cache, external APIs) are reachable
- Returns `503 Service Unavailable` if any dependency is down
- Used by load balancers and orchestrators to route traffic only to ready instances

**Liveness Probe**
Answers: "Is this instance alive and not deadlocked?"

- Path: `GET /health/live` or equivalent
- Returns `200 OK` as long as the process is running and responsive
- Does not check external dependencies — only the process itself
- Used by orchestrators to restart instances that are deadlocked or stuck

**Startup Probe**
Answers: "Has this instance finished starting up?"

- Used for applications with long startup times (>30 seconds)
- Disables liveness and readiness probes until startup is confirmed
- Prevents premature restarts during initialization

### Health Endpoint Implementation Rules

- [ ] Readiness probe checks: database connectivity, cache connectivity, and any
      mandatory external service
- [ ] Liveness probe returns immediately — no I/O operations
- [ ] Health endpoints require no authentication
- [ ] Health endpoints do not appear in access logs (filter them out to reduce noise)
- [ ] Health endpoints respond in under 100ms — if a dependency check takes longer,
      use a timeout with failure

### Kubernetes Health Check Example

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

---

## 6. Rollback Strategies

Plan rollback before deploying. A rollback plan that is figured out after an incident is
too slow.

### Automated Rollback

Configure the deployment system to roll back automatically when:

- Readiness probes fail for more than N consecutive checks after deployment
- Error rate rises above a threshold within the first 10 minutes
- Liveness probes trigger more than N restarts within a time window

```yaml
# Example: GitHub Actions deployment with rollback on failure
- name: Deploy
  run: kubectl set image deployment/app app=registry/image:${{ github.sha }}

- name: Verify rollout
  run: kubectl rollout status deployment/app --timeout=5m
  # If this fails, the previous rollout is still running — no action needed
  # If partial rollout happened, roll back:

- name: Rollback on failure
  if: failure()
  run: kubectl rollout undo deployment/app
```

### Manual Rollback Procedure

Document the manual rollback procedure in the project's runbook before the first deployment.
The procedure must be executable by any engineer in under 5 minutes.

```bash
# Kubernetes
kubectl rollout undo deployment/app
kubectl rollout status deployment/app

# Docker Compose
docker-compose pull  # pull previous image by tag
docker-compose up -d

# Verify rollback succeeded
curl https://app.example.com/health/ready
```

### Rollback Checklist

- [ ] Previous Docker image is retained in the registry for at least 7 days
- [ ] Automated rollback is configured and tested in staging
- [ ] Manual rollback procedure is documented in the project runbook
- [ ] Rollback tested in staging before any production deployment

---

## 7. Environment Variables and Secrets

### Per-Environment Configuration

- [ ] All environment-specific values are injected via environment variables at runtime
- [ ] No environment-specific values are baked into Docker images
- [ ] A `.env.example` file documents every required environment variable with a
      description and example value (never a real secret)
- [ ] The deployment system (Kubernetes, Docker Compose, ECS, etc.) injects values from
      a secrets manager at runtime

### Secrets Management

- [ ] Secrets (API keys, database passwords, signing keys) are stored in a secrets manager:
      AWS Secrets Manager, HashiCorp Vault, 1Password Secrets Automation, or equivalent
- [ ] Secrets are never stored in:
      - Source code or `.env` files committed to git
      - Docker images
      - CI/CD environment variable logs (mask all secret values)
      - Unencrypted storage
- [ ] Each environment has its own secret values — staging and production share no secrets
- [ ] Secret rotation is documented and tested — know how to rotate every secret without
      downtime

### Environment Variable Checklist

- [ ] `DATABASE_URI` or equivalent set per environment
- [ ] `NODE_ENV` set to `production` in production (enables optimizations and disables
      dev tooling)
- [ ] `PORT` set explicitly — do not rely on defaults
- [ ] All required variables are present before the application starts — fail fast on
      missing required configuration

---

## 8. Database Migrations

Database migrations must run before the application deploys. A deployed application that
cannot connect to an up-to-date schema is broken.

### Migration Rules

- [ ] Migrations are idempotent — running the same migration twice produces no error and
      no duplicate data
- [ ] Migrations are backward compatible during the deploy window — the old code must be
      able to run against the new schema until all instances are updated
- [ ] Migrations run as a separate job before the deployment job, not as part of
      application startup
- [ ] Migration failures abort the deployment — do not proceed to deploy application code
      if migrations fail
- [ ] A rollback migration exists for every migration that changes data or removes columns

### Migration Sequence in CI/CD

```yaml
jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - name: Run migrations
        run: npm run migrate
        env:
          DATABASE_URI: ${{ secrets.PROD_DATABASE_URI }}

  deploy:
    needs: migrate   # deploy only runs if migrate succeeds
    runs-on: ubuntu-latest
    steps:
      - name: Deploy application
        run: kubectl apply -f k8s/
```

### Migration Checklist

- [ ] Migration tested on a clean database in staging before production
- [ ] Migration tested for idempotency (run twice, no error)
- [ ] Rollback migration written and tested
- [ ] Estimated migration run time documented — if it exceeds 30 seconds, plan for zero-
      downtime migration techniques (expand-contract pattern)

---

## 9. Monitoring and Observability

A deployed application that is not monitored is not managed. Set up monitoring before
deploying to production.

### Log Aggregation

- [ ] Application logs stream to a log aggregation system (Datadog, CloudWatch, Loki,
      Papertrail, or equivalent)
- [ ] Logs include: timestamp, log level, request ID (for tracing), user ID (when
      available and legal), and structured context (not concatenated strings)
- [ ] Error logs include the full stack trace
- [ ] Health check requests are filtered from access logs

### Error Tracking

- [ ] An error tracking system captures unhandled exceptions (Sentry, Bugsnag, Rollbar,
      or equivalent)
- [ ] Errors include: request context, user context, environment, and release version
- [ ] Alerts fire when the error rate exceeds a threshold

### Performance Metrics

- [ ] Response time (p50, p95, p99) tracked per endpoint
- [ ] Error rate tracked per endpoint
- [ ] Application resource usage tracked (CPU, memory, open file descriptors, database
      connection pool usage)
- [ ] Alerts defined for: error rate spike, response time degradation, resource saturation

### Alerting Rules

- [ ] Alerts route to the on-call engineer, not a silent dashboard
- [ ] Alerts are actionable — every alert has a corresponding runbook entry
- [ ] Flapping alerts are suppressed — add minimum duration before firing (e.g., error
      rate above 5% for 5 consecutive minutes)

---

## 10. Post-Deploy Verification

After every deployment, run a structured verification before declaring success.

### Smoke Test Checklist

- [ ] Health endpoint returns `200 OK`: `curl -f https://app.example.com/health/ready`
- [ ] Application version endpoint reflects the deployed version:
      `curl https://app.example.com/health/version`
- [ ] A key user-facing flow completes successfully (log in, view dashboard, or equivalent)
- [ ] No new errors appear in the error tracker within 5 minutes of deployment
- [ ] p95 response time is within the expected range (check monitoring dashboard)
- [ ] All instances report healthy in the load balancer or orchestrator

### Verification Gate

If any smoke test fails:

1. Do not declare the deployment successful
2. Investigate the failure with the monitoring tools
3. Trigger rollback if the failure is critical and root cause is not immediately clear
4. Document the incident in the runbook

---

## Deployment Gate

Run through this gate before marking any deployment complete:

- [ ] All CI stages passed (build, test, lint, security scan)
- [ ] Docker image tagged with git SHA and pushed to registry
- [ ] Migrations ran successfully before application deployed
- [ ] Health checks pass on all instances after deployment
- [ ] Smoke tests pass in the target environment
- [ ] No new errors in error tracker 10 minutes post-deploy
- [ ] Rollback procedure tested and documented
- [ ] Monitoring and alerts active

If any item fails, investigate immediately. Do not move on to the next environment until
the current environment is verified healthy.
