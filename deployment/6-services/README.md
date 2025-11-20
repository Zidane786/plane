# 6 Services Deployment

Deploy Plane as **6 separate Dokploy applications** for maximum control and scalability.

## Architecture

```
1. Infrastructure → Postgres, Redis, RabbitMQ, MinIO
2. API Backend   → Django REST API
3. Worker        → Celery background tasks
4. Beat Worker   → Celery scheduler
5. Live Server   → WebSocket collaboration
6. Frontend      → Web + Admin + Space apps
```

## Files in This Folder

```
6-services/
├── README.md                          ← You are here
├── DEPLOYMENT_GUIDE.md                ← **START HERE!**
│
├── docker-compose.infra.yml           ← Infrastructure services
├── docker-compose.api.yml             ← API backend
├── docker-compose.worker.yml          ← Worker
├── docker-compose.beat-worker.yml     ← Beat worker
├── docker-compose.live.yml            ← Live server
│
├── nixpacks.frontend.toml             ← Frontend build config
├── nixpacks.api.toml                  ← API build config (optional)
├── nixpacks.live.toml                 ← Live build config (optional)
├── nixpacks.worker.toml               ← Worker build config (optional)
├── nixpacks.beat-worker.toml          ← Beat build config (optional)
│
├── .env.infra                         ← Infrastructure env vars
├── .env.api                           ← API env vars
├── .env.worker                        ← Worker env vars
├── .env.beat-worker                   ← Beat worker env vars
├── .env.live                          ← Live server env vars
└── .env.frontend                      ← Frontend env vars
```

## Quick Start

```bash
# 1. Read the deployment guide
cat DEPLOYMENT_GUIDE.md

# 2. Review/update environment files
# - .env.infra (secure passwords already generated!)
# - .env.api (update OPENAI_API_KEY and EMAIL_* if needed)
# - .env.worker (update OPENAI_API_KEY and EMAIL_* if needed)
# - .env.live (verify SECRET_KEY matches .env.api)
# - .env.frontend (should be ready to go)

# 3. Deploy to Dokploy (follow guide)
# Order: Infrastructure → API → Worker → Beat → Live → Frontend
```

## Environment Variables

**Already configured with secure credentials:**
- ✅ Django SECRET_KEY (67 chars, cryptographically random)
- ✅ PostgreSQL password (43 chars)
- ✅ RabbitMQ password (43 chars)
- ✅ MinIO access keys (55+ chars)

**You MUST update (placeholders):**
- ⚠️ `OPENAI_API_KEY` in `.env.api` and `.env.worker`
- ⚠️ `EMAIL_HOST_USER` and `EMAIL_HOST_PASSWORD` in `.env.api` and `.env.worker`

**Already configured (no changes needed):**
- ✅ Domains: `plane.mohdop.com`, `plane-api.mohdop.com`
- ✅ CORS: Properly configured
- ✅ Storage: MinIO configured
- ✅ Database connections: All set

## Deployment Steps (Summary)

1. **Infrastructure** (5 min)
   - Creates network + database services
   - Deploy: `docker-compose.infra.yml` + `.env.infra`

2. **API Backend** (5 min)
   - Runs migrations, starts API
   - Deploy: `docker-compose.api.yml` + `.env.api`

3. **Worker** (2 min)
   - Starts background task processing
   - Deploy: `docker-compose.worker.yml` + `.env.worker`

4. **Beat Worker** (2 min)
   - Starts scheduled task processing
   - Deploy: `docker-compose.beat-worker.yml` + `.env.beat-worker`

5. **Live Server** (3 min)
   - Starts WebSocket server
   - Deploy: `docker-compose.live.yml` + `.env.live`

6. **Frontend** (10 min build time)
   - Builds and serves all frontend apps
   - Deploy: Nixpacks with `nixpacks.frontend.toml` + `.env.frontend`

**Total Time**: ~30 minutes (including builds)

## After Deployment

```bash
# Create superuser
docker exec -it plane-api python manage.py createsuperuser

# Verify all services
docker ps | grep plane

# Check API health
curl https://plane-api.mohdop.com/api/health/

# Open frontend
open https://plane.mohdop.com
```

## Scaling

```bash
# In Dokploy: Scale worker service
# Example: Scale to 3 worker instances
# Workers: 1 → 3

# API and other services continue running normally
# No restarts required!
```

## Troubleshooting

See `DEPLOYMENT_GUIDE.md` → Troubleshooting section

## Documentation

- **Deployment Steps**: `DEPLOYMENT_GUIDE.md` (this folder)
- **Environment Variables**: `../ENVIRONMENT_VARIABLES_REFERENCE.md`
- **API Communication**: `../API_COMMUNICATION_GUIDE.md`
- **Security**: `../SECURITY_CHECKLIST.md`
- **Monorepo Mapping**: `../MONOREPO_TO_SERVICES_GUIDE.md`
