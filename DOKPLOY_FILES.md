# Dokploy Deployment Files

This directory contains all the necessary files for deploying Plane on Dokploy.

## 📦 Services Summary

**Total: 9 Services**
- **5 Dokploy Applications** (created in Dokploy dashboard)
- **4 Docker Infrastructure Services** (via docker-compose.infra.yml)

## 📁 File Structure

```
plane/
├── nixpacks.api.toml              # Nixpacks config for Django API
├── nixpacks.worker.toml           # Nixpacks config for Celery Worker ⚠️ NEW
├── nixpacks.beat-worker.toml      # Nixpacks config for Beat Worker ⚠️ NEW
├── nixpacks.frontend.toml         # Nixpacks config for React frontend
├── nixpacks.live.toml             # Nixpacks config for Live server
├── .env.api.example               # API environment variables template
├── .env.worker.example            # Worker environment variables template ⚠️ NEW
├── .env.frontend.example          # Frontend environment variables template
├── .env.live.example              # Live server environment variables template
├── .env.infra.example             # Infrastructure services template
├── docker-compose.infra.yml       # PostgreSQL, Redis, RabbitMQ, MinIO
├── DOKPLOY_DEPLOYMENT.md          # Complete deployment guide
├── scripts/
│   ├── migrate-postgres-to-external.sh
│   ├── migrate-storage-to-s3.sh
│   └── backup-data.sh
├── healthcheck/
│   ├── api.sh
│   ├── frontend.sh
│   └── live.sh
└── nginx/
    └── combined-frontend.conf     # Nginx config for frontend apps
```

## 🚀 Quick Start

1. **Read the deployment guide:**
   ```bash
   cat DOKPLOY_DEPLOYMENT.md
   ```

2. **Prepare environment files:**
   ```bash
   cp .env.infra.example .env.infra
   cp .env.api.example .env.api
   cp .env.frontend.example .env.frontend
   cp .env.live.example .env.live
   ```

3. **Edit with your actual values:**
   ```bash
   nano .env.infra
   nano .env.api
   nano .env.frontend
   nano .env.live
   ```

4. **Deploy infrastructure:**
   ```bash
   docker-compose -f docker-compose.infra.yml up -d
   ```

5. **Create apps in Dokploy UI** following the guide in `DOKPLOY_DEPLOYMENT.md`

## 🌐 Your Domains

- **plane.mohdop.com** - Main app (web, admin, space, live)
- **plane-api.mohdop.com** - API backend
- **minio.mohdop.com** - MinIO console
- **rabbitmq.mohdop.com** - RabbitMQ management (optional)

## 📖 Documentation

For complete step-by-step instructions, see: **DOKPLOY_DEPLOYMENT.md**

## 🔧 Useful Commands

```bash
# Health checks
./healthcheck/api.sh https://plane-api.mohdop.com
./healthcheck/frontend.sh https://plane.mohdop.com
./healthcheck/live.sh https://plane.mohdop.com/live

# Backup
./scripts/backup-data.sh

# Migration to external services
./scripts/migrate-postgres-to-external.sh
./scripts/migrate-storage-to-s3.sh
```

## ⚠️ Important Notes

- All `.env.*.example` files contain **example values with your domain (mohdop.com)**
- **Change all passwords and secrets** before deploying
- Generate a secure `SECRET_KEY` for Django
- Keep `.env` files secure and never commit them to git
