# Consolidated Deployment (3 Services)

Deploy Plane as **3 Dokploy applications** for simplicity.

## Architecture

```
1. Infrastructure → Postgres, Redis, RabbitMQ, MinIO
2. Backend        → API + Worker + Beat Worker + Live Server (all in one)
3. Frontend       → Web + Admin + Space apps
```

## Files in This Folder

```
consolidated/
├── README.md                          ← You are here
├── DEPLOYMENT_GUIDE.md                ← **START HERE!** (to be created)
│
├── docker-compose.infra.yml           ← Infrastructure services
├── docker-compose.backend.yml         ← All backend services combined
│
├── nixpacks.frontend.toml             ← Frontend build config
│
├── .env.infra                         ← Infrastructure env vars
├── .env.backend                       ← All backend env vars (single file)
└── .env.frontend                      ← Frontend env vars
```

## Quick Start

```bash
# 1. Read the deployment guide
cat DEPLOYMENT_GUIDE.md

# 2. Review/update environment files
# - .env.infra (secure passwords already generated!)
# - .env.backend (update OPENAI_API_KEY and EMAIL_* if needed)
# - .env.frontend (should be ready to go)

# 3. Deploy to Dokploy (follow guide)
# Order: Infrastructure → Backend → Frontend
```

## Environment Variables

**Already configured with secure credentials:**
- ✅ Django SECRET_KEY (67 chars, cryptographically random)
- ✅ PostgreSQL password (43 chars)
- ✅ RabbitMQ password (43 chars)
- ✅ MinIO access keys (55+ chars)

**You MUST update (placeholders):**
- ⚠️ `OPENAI_API_KEY` in `.env.backend`
- ⚠️ `EMAIL_HOST_USER` and `EMAIL_HOST_PASSWORD` in `.env.backend`

**Already configured (no changes needed):**
- ✅ Domains: `plane.mohdop.com`, `plane-api.mohdop.com`
- ✅ CORS: Properly configured
- ✅ Storage: MinIO configured
- ✅ Database connections: All set

## Deployment Steps (Summary)

1. **Infrastructure** (5 min)
   - Creates network + database services
   - Deploy: `docker-compose.infra.yml` + `.env.infra`

2. **Backend** (7 min)
   - Starts API, Worker, Beat Worker, and Live Server
   - Deploy: `docker-compose.backend.yml` + `.env.backend`

3. **Frontend** (10 min build time)
   - Builds and serves all frontend apps
   - Deploy: Nixpacks with `nixpacks.frontend.toml` + `.env.frontend`

**Total Time**: ~25 minutes (including builds)

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

## Scaling Limitations

⚠️ **Note**: With consolidated deployment, scaling is limited:

```bash
# Can scale entire backend
# Backend: 1 → 2 instances
# But this scales EVERYTHING (API + Worker + Beat + Live)

# Cannot scale just workers independently
```

**Need independent scaling?** → Migrate to 6 services (see `../MONOREPO_TO_SERVICES_GUIDE.md`)

## Migration to 6 Services

If you outgrow this setup, you can migrate to 6 services with **zero downtime**:

```bash
# See migration guide
cat ../MONOREPO_TO_SERVICES_GUIDE.md

# Migration time: ~20 minutes
# Downtime: 0 minutes ✅
```

## Troubleshooting

Common issues and solutions (to be added in DEPLOYMENT_GUIDE.md)

## Documentation

- **Deployment Steps**: `DEPLOYMENT_GUIDE.md` (this folder)
- **Environment Variables**: `../../ENVIRONMENT_VARIABLES_REFERENCE.md`
- **API Communication**: `../../API_COMMUNICATION_GUIDE.md`
- **Security**: `../../SECURITY_CHECKLIST.md`
- **Monorepo Mapping**: `../MONOREPO_TO_SERVICES_GUIDE.md`
- **Migration to 6 Services**: `../MONOREPO_TO_SERVICES_GUIDE.md` → Migration section
