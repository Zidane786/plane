# Monorepo to 6 Services - Complete Mapping Guide

**TL;DR**: Keep the monorepo! 6 services run from the SAME codebase, just deployed separately.

---

## Table of Contents
1. [Why Monorepo for 6 Services?](#why-monorepo-for-6-services)
2. [Monorepo Structure Overview](#monorepo-structure-overview)
3. [Service→Code Mapping](#servicecode-mapping)
4. [Deployment Flow](#deployment-flow)
5. [Migration from Consolidated to 6 Services](#migration-from-consolidated-to-6-services)
6. [Common Misconceptions](#common-misconceptions)

---

## Why Monorepo for 6 Services?

### ❓ The Question

**"Should I split into micro-repos (6 repos) for 6 services?"**

### ✅ The Answer: NO - Keep the Monorepo!

**6 Services ≠ 6 Repositories**

```
┌────────────────────────────────────────────────────────┐
│             ONE MONOREPO (plane/)                      │
│                                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │ apps/api │ │apps/web  │ │apps/live │  ... etc    │
│  └──────────┘ └──────────┘ └──────────┘             │
│         │            │            │                   │
│         └────────────┴────────────┘                   │
│                      │                                │
└──────────────────────┼────────────────────────────────┘
                       │
                       │ Deploy to Dokploy as 6 apps
                       ▼
    ┌─────────────────────────────────────────────┐
    │   Dokploy (6 Separate Applications)         │
    ├─────────────────────────────────────────────┤
    │  1. Infrastructure                          │
    │  2. API (uses apps/api/)                    │
    │  3. Worker (uses apps/api/)                 │
    │  4. Beat Worker (uses apps/api/)            │
    │  5. Live (uses apps/live/)                  │
    │  6. Frontend (uses apps/web|admin|space)    │
    └─────────────────────────────────────────────┘
```

### Why Monorepo Wins

| Aspect | Monorepo (✅) | Micro-repos (❌) |
|--------|--------------|------------------|
| **Shared Code** | Easy (shared packages/) | Hard (npm packages for everything) |
| **Type Safety** | API types → Frontend instantly | Publish types package, wait, install |
| **Atomic Changes** | Update API + Frontend in 1 commit | 2 PRs, 2 repos, sync nightmare |
| **Dependencies** | One `pnpm install` | Install in each repo separately |
| **Versioning** | No version conflicts | "Frontend needs API v2.3, Worker needs v2.2" |
| **Onboarding** | Clone once, setup once | Clone 6 repos, setup 6 times |
| **CI/CD** | One pipeline, smart caching | 6 pipelines, complex orchestration |
| **Refactoring** | Change everywhere safely | Hope you didn't miss a repo |
| **Examples** | Google, Microsoft, Meta | Legacy systems |

### Real-World Example

**Scenario**: Add a new field `priority` to Issue model

**With Monorepo:**
```bash
# One commit, atomic change
1. Update API model (apps/api/models.py)
2. Update TypeScript types (packages/types/issue.ts)
3. Update frontend UI (apps/web/components/issue.tsx)
4. Commit → Deploy → Everything works
```

**With Micro-repos:**
```bash
# 4 separate repos, 4 PRs, coordination nightmare
1. Repo: api-backend → Add field, deploy v2.1
2. Repo: types-package → Update types, publish v1.3
3. Repo: frontend → Update package.json, wait for types v1.3
4. Repo: worker → Update package.json, wait for types v1.3
5. Deploy frontend → 500 errors (API deployed but frontend not updated yet)
6. Fix deployment order, document deployment sequence
7. Hope nothing breaks
```

---

## Monorepo Structure Overview

```
plane/                                 ← ROOT (the monorepo)
├── apps/                              ← Application code
│   ├── api/                           ← Backend API (Django)
│   │   ├── plane/                     ← Django project
│   │   │   ├── settings/
│   │   │   ├── api/                   ← REST API endpoints
│   │   │   ├── db/                    ← Database models
│   │   │   └── utils/
│   │   ├── bin/                       ← Docker entrypoints
│   │   │   ├── docker-entrypoint-api.sh      ← API service
│   │   │   ├── docker-entrypoint-worker.sh   ← Worker service
│   │   │   └── docker-entrypoint-beat.sh     ← Beat service
│   │   ├── Dockerfile.api             ← Build image (used by 3 services)
│   │   ├── requirements.txt
│   │   └── manage.py
│   │
│   ├── web/                           ← Main web app (React Router)
│   │   ├── app/                       ← Application routes
│   │   ├── components/
│   │   ├── store/                     ← MobX stores
│   │   ├── nginx/                     ← Nginx config
│   │   └── Dockerfile.web
│   │
│   ├── admin/                         ← Admin app (god-mode)
│   │   ├── app/
│   │   ├── components/
│   │   ├── nginx/
│   │   └── Dockerfile.admin
│   │
│   ├── space/                         ← Public spaces app
│   │   ├── app/
│   │   ├── components/
│   │   ├── nginx/
│   │   └── Dockerfile.space
│   │
│   └── live/                          ← Live server (WebSocket)
│       ├── src/
│       │   ├── server.ts              ← Hocuspocus server
│       │   ├── auth.ts                ← JWT validation
│       │   └── extensions/            ← Yjs extensions
│       ├── Dockerfile.live
│       └── package.json
│
├── packages/                          ← Shared packages
│   ├── types/                         ← TypeScript types (shared!)
│   ├── ui/                            ← Shared React components
│   ├── eslint-config/                 ← Shared linting
│   └── tsconfig/                      ← Shared TypeScript config
│
├── deployment/                        ← Deployment configurations
│   ├── 6-services/                    ← 6-service deployment
│   │   ├── docker-compose.*.yml       ← Docker compose files
│   │   ├── .env.*                     ← Environment files
│   │   └── DEPLOYMENT_GUIDE.md
│   │
│   └── consolidated/                  ← 3-service deployment
│       ├── docker-compose.*.yml
│       └── .env.*
│
├── docker-compose.*.yml               ← Compose files (root level)
├── nixpacks.*.toml                    ← Nixpacks configs
├── turbo.json                         ← Turborepo configuration
├── pnpm-workspace.yaml                ← pnpm workspaces
└── package.json                       ← Root package.json
```

---

## Service→Code Mapping

### Which Service Uses Which Code?

| Service | Uses Code From | Dockerfile/Build | Runtime |
|---------|----------------|------------------|---------|
| **Infrastructure** | *(none - external images)* | postgres:15, redis:7, rabbitmq:3, minio | - |
| **API** | `apps/api/` | `apps/api/Dockerfile.api` | `bin/docker-entrypoint-api.sh` |
| **Worker** | `apps/api/` **(same as API!)** | `apps/api/Dockerfile.api` **(same!)** | `bin/docker-entrypoint-worker.sh` |
| **Beat Worker** | `apps/api/` **(same as API!)** | `apps/api/Dockerfile.api` **(same!)** | `bin/docker-entrypoint-beat.sh` |
| **Live Server** | `apps/live/` | `apps/live/Dockerfile.live` | `node dist/start.js` |
| **Frontend** | `apps/web/`, `apps/admin/`, `apps/space/` | Nixpacks (builds all 3) | `nginx -g 'daemon off;'` |

### Key Insight: API, Worker, Beat Worker Share Code!

```
┌───────────────────────────────────────────────────┐
│          apps/api/ (Django Codebase)              │
│                                                   │
│  Same Docker Image Built From:                   │
│  apps/api/Dockerfile.api                          │
│                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │   plane-api │  │plane-worker │  │plane-beat│ │
│  │             │  │             │  │          │ │
│  │  Runs:      │  │  Runs:      │  │  Runs:   │ │
│  │  gunicorn   │  │  celery     │  │  celery  │ │
│  │             │  │  worker     │  │  beat    │ │
│  └─────────────┘  └─────────────┘  └──────────┘ │
│         ▲               ▲                ▲        │
│         └───────────────┴────────────────┘        │
│            Same image, different commands         │
└───────────────────────────────────────────────────┘
```

**Why?** Celery workers need access to the same Django models, tasks, and utilities as the API.

---

## Deployment Flow

### How One Monorepo Becomes 6 Services

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: Developer Pushes Code to Git                          │
├─────────────────────────────────────────────────────────────────┤
│  git push origin main                                           │
│                                                                 │
│  Monorepo (plane/) pushed to GitHub/GitLab                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: Dokploy Pulls Monorepo (6 times, once per service)    │
├─────────────────────────────────────────────────────────────────┤
│  Each Dokploy application points to SAME git repo              │
│  but uses DIFFERENT build configs                              │
└─────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
  ┌──────────┐        ┌──────────┐       ┌──────────┐
  │ API App  │        │Worker App│       │Frontend  │
  │          │        │          │       │   App    │
  │ Builds:  │        │ Builds:  │       │          │
  │ apps/api │        │ apps/api │       │ Builds:  │
  │          │        │          │       │ apps/web │
  │ Runs:    │        │ Runs:    │       │ apps/adm │
  │ gunicorn │        │ celery   │       │ apps/spa │
  └──────────┘        └──────────┘       └──────────┘
        │                   │                   │
        ▼                   ▼                   ▼
   Deployed          Deployed            Deployed
  as separate       as separate         as separate
   container         container           container
```

### Dokploy Configuration Per Service

**Service 1: Infrastructure**
```yaml
# In Dokploy
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.infra.yml
```

**Service 2: API**
```yaml
# In Dokploy
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.api.yml
Build Context: apps/api/               ← Only builds this folder
Dockerfile: apps/api/Dockerfile.api
Command: ./bin/docker-entrypoint-api.sh
```

**Service 3: Worker**
```yaml
# In Dokploy
Repository: plane (monorepo)           ← SAME repo as API!
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.worker.yml
Build Context: apps/api/               ← SAME folder as API!
Dockerfile: apps/api/Dockerfile.api    ← SAME Dockerfile as API!
Command: ./bin/docker-entrypoint-worker.sh  ← DIFFERENT command!
```

**Service 4: Beat Worker**
```yaml
# In Dokploy
Repository: plane (monorepo)           ← SAME repo!
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.beat-worker.yml
Build Context: apps/api/               ← SAME folder!
Dockerfile: apps/api/Dockerfile.api    ← SAME Dockerfile!
Command: ./bin/docker-entrypoint-beat.sh   ← DIFFERENT command!
```

**Service 5: Live Server**
```yaml
# In Dokploy
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.live.yml
Build Context: apps/live/              ← Different folder!
Dockerfile: apps/live/Dockerfile.live
Command: node dist/start.js
```

**Service 6: Frontend**
```yaml
# In Dokploy
Repository: plane (monorepo)
Type: Nixpacks
Nixpacks Config: deployment/6-services/nixpacks.frontend.toml
Build Commands:
  - pnpm build --filter=web...
  - pnpm build --filter=admin...
  - pnpm build --filter=space...
Start Command: nginx -g 'daemon off;' -c /app/nginx/combined-frontend.conf
```

---

## What Each Service Actually Does

### 1. Infrastructure
**Code Used**: None (external Docker images)
**Purpose**: Provides databases and services
**Containers**:
- `postgres:15.7-alpine` - Database
- `valkey/valkey:7.2.7-alpine` - Redis cache
- `rabbitmq:3.13.6-management-alpine` - Message queue
- `minio/minio` - S3-compatible storage

### 2. API Backend
**Code Used**: `apps/api/`
**Entry Point**: `apps/api/bin/docker-entrypoint-api.sh`
**What It Runs**:
```bash
#!/bin/bash
# Wait for database
python manage.py wait_for_db

# Run migrations
python manage.py migrate --no-input

# Collect static files
python manage.py collectstatic --no-input

# Start Gunicorn
gunicorn plane.wsgi:application \
  --workers ${GUNICORN_WORKERS:-2} \
  --bind 0.0.0.0:8000
```
**Serves**: REST API endpoints at `/api/*`

### 3. Worker
**Code Used**: `apps/api/` **(same as API!)**
**Entry Point**: `apps/api/bin/docker-entrypoint-worker.sh`
**What It Runs**:
```bash
#!/bin/bash
# Wait for database
python manage.py wait_for_db

# Start Celery worker
celery -A plane worker \
  --loglevel=info \
  --concurrency=4
```
**Handles**:
- Email sending
- File processing
- Webhooks
- Data imports/exports
- Background computations

### 4. Beat Worker
**Code Used**: `apps/api/` **(same as API!)**
**Entry Point**: `apps/api/bin/docker-entrypoint-beat.sh`
**What It Runs**:
```bash
#!/bin/bash
# Wait for database
python manage.py wait_for_db

# Start Celery beat scheduler
celery -A plane beat \
  --loglevel=info \
  --scheduler django_celery_beat.schedulers:DatabaseScheduler
```
**Handles**:
- Scheduled cleanup jobs
- Recurring notifications
- Periodic data sync
- Automated maintenance tasks

### 5. Live Server
**Code Used**: `apps/live/`
**Entry Point**: `apps/live/dist/start.js`
**What It Runs**:
```typescript
// Hocuspocus WebSocket server
const server = Server.configure({
  port: 3000,
  extensions: [
    new RedisExtension(),     // Persist to Redis
    new AuthExtension(),      // Validate JWTs
    new DatabaseExtension(),  // Sync to database
  ],
});
server.listen();
```
**Handles**:
- Real-time collaborative editing (Yjs CRDTs)
- WebSocket connections
- Document synchronization

### 6. Frontend
**Code Used**: `apps/web/`, `apps/admin/`, `apps/space/`
**Build Process**:
```bash
# Nixpacks builds all 3 apps
pnpm build --filter=web...    → /var/www/web
pnpm build --filter=admin...  → /var/www/admin
pnpm build --filter=space...  → /var/www/space

# Nginx serves all 3
nginx -c /app/nginx/combined-frontend.conf
```
**Serves**:
- `/` → Web app (main application)
- `/god-mode` → Admin app
- `/spaces` → Space app (public views)

---

## Migration from Consolidated to 6 Services

### Scenario: You Started with 3 Services, Want to Move to 6

**Current (3 Services)**:
```
1. Infrastructure (Postgres, Redis, RabbitMQ, MinIO)
2. Backend (API + Worker + Beat + Live) ← All in one container
3. Frontend (Web + Admin + Space)
```

**Target (6 Services)**:
```
1. Infrastructure (Postgres, Redis, RabbitMQ, MinIO)
2. API
3. Worker
4. Beat Worker
5. Live Server
6. Frontend (Web + Admin + Space)
```

### Migration Steps (Zero Downtime!)

#### Step 1: Deploy Worker as Separate Service (5 minutes)

```bash
# In Dokploy: Create new application "plane-worker"
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.worker.yml
Environment: Copy from .env.backend

# Deploy
# Now you have:
# - Backend (API + Beat + Live)
# - Worker (separate)
```

**Status**: ✅ Worker now independent, API still running

#### Step 2: Deploy Beat Worker as Separate Service (5 minutes)

```bash
# In Dokploy: Create new application "plane-beat-worker"
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.beat-worker.yml
Environment: Copy from .env.backend

# Deploy
# Now you have:
# - Backend (API + Live)
# - Worker (separate)
# - Beat Worker (separate)
```

**Status**: ✅ Beat Worker now independent

#### Step 3: Deploy Live Server as Separate Service (5 minutes)

```bash
# In Dokploy: Create new application "plane-live"
Repository: plane (monorepo)
Type: Docker Compose
Compose File: deployment/6-services/docker-compose.live.yml
Environment: Copy from .env.backend (ensure SECRET_KEY matches!)

# Deploy
# Now you have:
# - Backend (API only)
# - Worker (separate)
# - Beat Worker (separate)
# - Live Server (separate)
```

**Status**: ✅ Live Server now independent

#### Step 4: Update Backend to API-Only (5 minutes)

```bash
# In Dokploy: Update "plane-backend" application
Compose File: deployment/6-services/docker-compose.api.yml
(This removes worker, beat, live services)

# Deploy
# Now you have fully migrated to 6 services!
```

**Status**: ✅ Fully migrated! All 6 services running independently

### Total Migration Time: ~20 minutes
### Downtime: 0 minutes ✅

---

## Common Misconceptions

### Myth 1: "6 Services = Need 6 Repositories"
❌ **FALSE**

- Services are **deployment units**, not code organization
- You can deploy 100 services from 1 monorepo
- Example: Google has 1 monorepo, 1000s of services

### Myth 2: "Monorepo Means Everything Deploys Together"
❌ **FALSE**

- Each Dokploy application deploys independently
- Updating API doesn't redeploy Frontend
- Monorepo just means code is in one place

### Myth 3: "Can't Scale Individual Services in Monorepo"
❌ **FALSE**

- Dokploy scales services independently
- Scale Worker to 5 instances, API stays at 1
- Monorepo doesn't affect runtime scaling

### Myth 4: "Monorepo Builds Slower"
❌ **FALSE**

- Turborepo caches builds
- Only rebuilds changed code
- Often faster than micro-repos (shared dependencies)

### Myth 5: "Need Different Repos for Different Teams"
❌ **FALSE**

- Use code ownership (CODEOWNERS file)
- PR permissions per directory
- Teams work in their folders (`apps/api/` vs `apps/web/`)

---

## Directory Ownership (For Teams)

If you have separate teams, use `CODEOWNERS`:

```
# .github/CODEOWNERS

# Backend team owns API code
/apps/api/              @backend-team
/apps/live/             @backend-team

# Frontend team owns frontend code
/apps/web/              @frontend-team
/apps/admin/            @frontend-team
/apps/space/            @frontend-team

# Shared packages require both teams
/packages/types/        @backend-team @frontend-team
```

Now PRs automatically request reviews from the right team!

---

## Summary

| Concept | Answer |
|---------|--------|
| **Should I use 6 repos for 6 services?** | No, keep the monorepo |
| **Do all services share code?** | API/Worker/Beat share `apps/api/`, others separate |
| **Can I deploy services independently?** | Yes! That's the whole point |
| **Can I scale services independently?** | Yes! Monorepo doesn't affect runtime |
| **Can I migrate from 3→6 services?** | Yes, zero downtime, 20 minutes |
| **Do I need different build pipelines?** | No, Dokploy handles it per service |
| **Is this production-ready?** | Yes! Used by Google, Microsoft, etc. |

---

## Next Steps

1. ✅ Decide: 6 services or 3 services?
2. ✅ Read: `deployment/6-services/DEPLOYMENT_GUIDE.md` or `deployment/consolidated/DEPLOYMENT_GUIDE.md`
3. ✅ Deploy: Follow the guide step-by-step
4. ✅ Scale: Add more worker instances as needed
5. ✅ Migrate: 3→6 services when you need more control

**Remember**: The monorepo stays the same regardless of how many services you deploy!
