# Plane Deployment Guide for Dokploy

Complete guide for deploying Plane project management tool on your VPS using Dokploy with Docker Compose.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Connecting GitHub to Dokploy](#connecting-github-to-dokploy)
- [Network Configuration](#network-configuration---automatic)
- [Quick Start](#quick-start)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Environment Variables](#environment-variables-reference)
- [Domain Configuration](#domain-configuration)
- [Migration to External Services](#migration-to-external-services)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### Domain Structure

- **plane.mohdop.com** - Frontend application
  - `/` - Main web interface
  - `/god-mode` - Admin panel
  - `/spaces` - Public project views
  - `/live` - Real-time collaboration (WebSocket)
- **plane-api.mohdop.com** - Backend REST API
- **minio.mohdop.com** - MinIO console (file storage management)
- **rabbitmq.mohdop.com** - RabbitMQ management (optional)

### Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Dokploy/Traefik                      │
│            (Reverse Proxy + Auto HTTPS/SSL)             │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Frontend   │  │  API Backend │  │ Live Server  │
│ (Nixpacks)   │  │   (Django)   │  │  (Node.js)   │
└──────────────┘  └──────┬───────┘  └──────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Celery Worker│  │ Beat Worker  │  │  PostgreSQL  │
│ (Background) │  │  (Scheduler) │  │    :5432     │
└──────────────┘  └──────────────┘  └──────────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│    Redis     │  │   RabbitMQ   │  │    MinIO     │
│    :6379     │  │    :5672     │  │    :9000     │
└──────────────┘  └──────────────┘  └──────────────┘

All services connected via "plane-network" - Automatic! ✨
```

### Deployment Components

**6 Dokploy Applications:**

1. **plane-infra** - Infrastructure services (`docker-compose.infra.yml`) ⚠️ **Deploy First!**
   - PostgreSQL 15.7
   - Redis (Valkey 7.2)
   - RabbitMQ 3.13.6
   - MinIO (S3-compatible storage)
   - **Creates `plane-network` for service communication**

2. **plane-api** - Django REST API (`docker-compose.api.yml`)
   - Gunicorn + Django application
   - Handles all API requests
   - Exposes port 8000

3. **plane-worker** - Celery worker (`docker-compose.worker.yml`)
   - Background task processing
   - Email sending, webhooks, async operations

4. **plane-beat-worker** - Celery beat scheduler (`docker-compose.beat-worker.yml`)
   - Scheduled/periodic tasks
   - Cleanup, recurring notifications

5. **plane-live** - Live collaboration server (`docker-compose.live.yml`)
   - WebSocket server (Hocuspocus/Yjs)
   - Real-time document collaboration
   - Exposes port 3000

6. **plane-frontend** - React frontend (`nixpacks.frontend.toml`)
   - Web, Admin, Space apps
   - Built with Vite + React
   - Served via Nginx

### Why Docker Compose + Dokploy?

✅ **Automatic Networking** - All services communicate via `plane-network`, no manual setup
✅ **GitHub Auto-Deploy** - Push to GitHub, Dokploy rebuilds automatically
✅ **SSL/HTTPS** - Traefik handles Let's Encrypt certificates automatically
✅ **Easy Scaling** - Adjust worker counts via environment variables
✅ **Clean Separation** - One compose file per service for clarity

---

## ✅ Prerequisites

### Required

- **VPS/Server** with:
  - Ubuntu 20.04+ / Debian 11+ (recommended)
  - 4GB+ RAM (8GB+ recommended for production)
  - 2+ CPU cores
  - 40GB+ storage
  - Public IP address

- **Dokploy Installed** ([installation guide](https://docs.dokploy.com))
  - Dokploy manages: Docker, Traefik, Let's Encrypt
  - Access at `http://your-server-ip:3000`

- **Domain Names** pointed to your server:
  - `plane.mohdop.com` → Your server IP
  - `plane-api.mohdop.com` → Your server IP
  - `minio.mohdop.com` → Your server IP (optional)
  - `rabbitmq.mohdop.com` → Your server IP (optional)

- **GitHub Repository** with Plane codebase
  - Fork or clone [makeplane/plane](https://github.com/makeplane/plane)
  - Push your configuration files to your repo

### Optional (for later migration)

- Managed PostgreSQL (AWS RDS, DigitalOcean, etc.)
- Managed Redis (AWS ElastiCache, Upstash, etc.)
- S3-compatible storage (AWS S3, DigitalOcean Spaces, etc.)

---

## 🔗 Connecting GitHub to Dokploy

Dokploy needs access to your GitHub repository for auto-deployment.

### Method 1: GitHub App (Recommended)

1. **In Dokploy Dashboard:**
   - Go to Settings → GitHub
   - Click "Install GitHub App"
   - Follow GitHub authorization flow

2. **Select Repository:**
   - Choose your Plane repository
   - Grant access to Dokploy

3. **Verify Connection:**
   - Return to Dokploy
   - You should see your repo in the list

### Method 2: SSH Deploy Key

1. **Generate SSH key on your VPS:**
   ```bash
   ssh-keygen -t ed25519 -C "dokploy-plane-deploy" -f ~/.ssh/dokploy-plane
   cat ~/.ssh/dokploy-plane.pub
   ```

2. **Add to GitHub:**
   - Go to your repo → Settings → Deploy keys
   - Click "Add deploy key"
   - Paste the public key
   - Check "Allow write access" if you want Dokploy to push
   - Save

3. **Add to Dokploy:**
   - In Dokploy: Settings → SSH Keys
   - Add the private key content
   - Link to your repository

### Verify Connection

After setup, Dokploy should be able to:
- Clone your repository
- Pull updates on push events
- Trigger automatic rebuilds

---

## 🌐 Network Configuration - Automatic! ✨

**Good news!** With docker-compose deployment, networking is **100% automatic**. No manual configuration needed!

### How It Works

When you deploy `docker-compose.infra.yml`:
1. ✅ Creates the `plane-network` Docker bridge network
2. ✅ Connects PostgreSQL, Redis, RabbitMQ, MinIO to it
3. ✅ Makes the network available as `external: true`

When you deploy other services:
1. ✅ Automatically connect to the existing `plane-network`
2. ✅ Can communicate with all infrastructure services
3. ✅ Can communicate with each other

```
┌─────────────────────────────────────────────────┐
│    Docker Network: plane-network (automatic)    │
├─────────────────────────────────────────────────┤
│                                                 │
│  [plane-api] ←→ [plane-postgres]               │
│       ↕              ↕                          │
│  [plane-worker] ←→ [plane-redis]               │
│       ↕              ↕                          │
│  [plane-live] ←→ [plane-rabbitmq]              │
│       ↕              ↕                          │
│  [plane-beat-worker] ←→ [plane-minio]          │
│                                                 │
│        All services can talk to each other!     │
└─────────────────────────────────────────────────┘
```

### Service Names (DNS Resolution)

All services communicate using container names:

- **Database:** `plane-postgres:5432`
- **Cache/Queue:** `plane-redis:6379`
- **Message Broker:** `plane-rabbitmq:5672`
- **Object Storage:** `plane-minio:9000`
- **API Backend:** `plane-api:8000`

Docker automatically resolves these names within `plane-network`. No IP addresses needed!

### Verification (Optional)

```bash
# Check the network exists
docker network ls | grep plane-network

# See all connected services
docker network inspect plane-network --format '{{range .Containers}}{{.Name}} {{end}}'
# Should output: plane-postgres plane-redis plane-rabbitmq plane-minio plane-api plane-worker plane-beat-worker plane-live
```

---

## 🚀 Quick Start

### 1. Prepare Environment Files

Copy and customize environment variables for each service:

```bash
# On your local machine
cd /path/to/plane

# Copy all example files
cp .env.infra.example .env.infra
cp .env.api.example .env.api
cp .env.worker.example .env.worker
cp .env.beat-worker.example .env.beat-worker
cp .env.live.example .env.live
cp .env.frontend.example .env.frontend

# Edit each file with your values
# Replace passwords, secrets, domains!
nano .env.infra       # Infrastructure credentials
nano .env.api         # API configuration
nano .env.worker      # Worker configuration
nano .env.beat-worker # Beat worker configuration
nano .env.live        # Live server configuration
nano .env.frontend    # Frontend URLs
```

**⚠️ IMPORTANT:** Change all default passwords and secrets!

### 2. Commit Configuration Files

```bash
git add docker-compose.*.yml .env.*.example nixpacks.frontend.toml
git commit -m "Add Dokploy deployment configuration"
git push origin main
```

### 3. Create Dokploy Applications (in order!)

#### App 1: Infrastructure (Deploy First!)

1. Dokploy Dashboard → Create New Application
2. **Name:** `plane-infra`
3. **Type:** Compose
4. **Repository:** Select your GitHub repo
5. **Branch:** `main`
6. **Compose Path:** `docker-compose.infra.yml`
7. **Environment Variables:** Paste contents of `.env.infra`
8. Click **Deploy**

Wait for infrastructure to be healthy before proceeding!

#### App 2: API Backend

1. Create New Application → **Name:** `plane-api`
2. **Type:** Compose
3. **Compose Path:** `docker-compose.api.yml`
4. **Environment Variables:** Paste contents of `.env.api`
5. **Domain:** `plane-api.mohdop.com`
6. Click **Deploy**

#### App 3: Celery Worker

1. Create New Application → **Name:** `plane-worker`
2. **Type:** Compose
3. **Compose Path:** `docker-compose.worker.yml`
4. **Environment Variables:** Paste contents of `.env.worker`
5. Click **Deploy** (no domain needed)

#### App 4: Beat Worker

1. Create New Application → **Name:** `plane-beat-worker`
2. **Type:** Compose
3. **Compose Path:** `docker-compose.beat-worker.yml`
4. **Environment Variables:** Paste contents of `.env.beat-worker`
5. Click **Deploy** (no domain needed)

#### App 5: Live Server

1. Create New Application → **Name:** `plane-live`
2. **Type:** Compose
3. **Compose Path:** `docker-compose.live.yml`
4. **Environment Variables:** Paste contents of `.env.live`
5. **Domain:** `plane.mohdop.com` with path `/live`
6. Click **Deploy**

#### App 6: Frontend

1. Create New Application → **Name:** `plane-frontend`
2. **Type:** Nixpacks
3. **Build Path:** Root directory (`/`)
4. **Nixpacks Config:** `nixpacks.frontend.toml`
5. **Environment Variables:** Paste contents of `.env.frontend`
6. **Domain:** `plane.mohdop.com`
7. Click **Deploy**

### 4. Verify Deployment

```bash
# Check all containers are running
docker ps | grep plane

# Should see:
# plane-postgres
# plane-redis
# plane-rabbitmq
# plane-minio
# plane-api
# plane-worker
# plane-beat-worker
# plane-live
# plane-frontend (or similar Dokploy-generated name)

# Check API health
curl https://plane-api.mohdop.com/api/health/

# Check frontend
curl https://plane.mohdop.com/
```

---

## 📖 Step-by-Step Deployment

*[Continue with detailed deployment steps in next section...]*

---

## 🔧 Environment Variables Reference

### Infrastructure (.env.infra)

```bash
# PostgreSQL
POSTGRES_USER=plane
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=plane

# Redis
REDIS_HOST=plane-redis
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=<strong-password>
RABBITMQ_VHOST=plane

# MinIO (S3-compatible storage)
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=<strong-password>
AWS_S3_BUCKET_NAME=uploads
AWS_REGION=us-east-1
```

### API (.env.api)

```bash
# Traefik routing
API_DOMAIN=plane-api.mohdop.com

# Django
SECRET_KEY=<50-character-random-string>
DEBUG=0
ALLOWED_HOSTS=plane-api.mohdop.com

# Database (matches .env.infra)
POSTGRES_USER=plane
POSTGRES_PASSWORD=<same-as-infra>
POSTGRES_DB=plane

# Redis (matches .env.infra)
REDIS_HOST=plane-redis
REDIS_PORT=6379

# RabbitMQ (matches .env.infra)
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=<same-as-infra>
RABBITMQ_VHOST=plane

# URLs
WEB_URL=https://plane.mohdop.com
API_BASE_URL=https://plane-api.mohdop.com
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com

# Storage (matches .env.infra)
USE_MINIO=1
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=<same-as-infra>
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
```

### Worker & Beat Worker (.env.worker, .env.beat-worker)

Same as API configuration (database, redis, rabbitmq, storage).

### Live Server (.env.live)

```bash
# Traefik routing
FRONTEND_DOMAIN=plane.mohdop.com

# Server
PORT=3000
NODE_ENV=production

# URLs
API_BASE_URL=http://plane-api:8000  # Internal service name!
WEB_BASE_URL=https://plane.mohdop.com
LIVE_BASE_URL=https://plane.mohdop.com
LIVE_BASE_PATH=/live

# Authentication (matches API SECRET_KEY)
LIVE_SERVER_SECRET_KEY=<same-as-api-secret-key>

# Redis (matches .env.infra)
REDIS_HOST=plane-redis
REDIS_PORT=6379

# CORS
ALLOWED_ORIGINS=https://plane.mohdop.com
```

### Frontend (.env.frontend)

```bash
# API URLs (public URLs, not internal)
NEXT_PUBLIC_API_BASE_URL=https://plane-api.mohdop.com
NEXT_PUBLIC_WEBAPP_URL=https://plane.mohdop.com
NEXT_PUBLIC_ADMIN_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_ADMIN_BASE_PATH=/god-mode
NEXT_PUBLIC_SPACE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_SPACE_BASE_PATH=/spaces
NEXT_PUBLIC_LIVE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_LIVE_BASE_PATH=/live
```

---

## 🌍 Domain Configuration

Traefik (built into Dokploy) handles all domain routing and SSL automatically.

### Domain → Service Mapping

| Domain | Service | Port | SSL |
|--------|---------|------|-----|
| plane.mohdop.com | Frontend | 3000 | ✅ Auto |
| plane.mohdop.com/live | Live Server | 3000 | ✅ Auto |
| plane.mohdop.com/god-mode | Frontend (Admin) | 3000 | ✅ Auto |
| plane.mohdop.com/spaces | Frontend (Space) | 3000 | ✅ Auto |
| plane-api.mohdop.com | API Backend | 8000 | ✅ Auto |
| minio.mohdop.com | MinIO Console | 9001 | ✅ Auto |
| rabbitmq.mohdop.com | RabbitMQ Mgmt | 15672 | ✅ Auto |

### DNS Setup

Point all domains to your server's IP:

```
A    plane            →  123.45.67.89
A    plane-api        →  123.45.67.89
A    minio            →  123.45.67.89
A    rabbitmq         →  123.45.67.89
```

Or use wildcard:

```
A    *.mohdop.com     →  123.45.67.89
```

Traefik automatically:
- Detects new domains from Traefik labels
- Requests Let's Encrypt certificates
- Handles HTTPS redirection
- Renews certificates before expiry

---

## 🔄 Migration to External Services

See backup old `DOKPLOY_DEPLOYMENT.md.backup` for migration scripts and detailed instructions.

Quick summary:
- Use `scripts/migrate-postgres-to-external.sh` for database migration
- Use `scripts/migrate-storage-to-s3.sh` for MinIO → S3 migration
- Update environment variables to point to external services
- Redeploy apps with new configuration

---

## 🔧 Troubleshooting

### Service Can't Connect to Database/Redis

**Symptom:** Connection refused, host not found

**Solution:**
```bash
# Verify infrastructure is running
docker ps | grep plane-postgres
docker ps | grep plane-redis

# Check network exists
docker network ls | grep plane-network

# Restart the failing service in Dokploy UI
```

### API Returns 502 Bad Gateway

**Symptom:** Frontend shows 502 error

**Solution:**
```bash
# Check API logs
docker logs plane-api --tail=50

# Check API is healthy
curl http://plane-api:8000/health/  # From another container
curl https://plane-api.mohdop.com/health/  # From outside

# Restart API in Dokploy
```

### Live Server WebSocket Connection Failed

**Symptom:** Real-time features not working

**Solution:**
```bash
# Check live server logs
docker logs plane-live --tail=50

# Verify Redis connection
docker exec plane-live redis-cli -h plane-redis ping

# Check CORS settings in .env.live
# ALLOWED_ORIGINS must match frontend domain
```

### Workers Not Processing Tasks

**Symptom:** Emails not sending, webhooks not firing

**Solution:**
```bash
# Check worker logs
docker logs plane-worker --tail=50
docker logs plane-beat-worker --tail=50

# Verify RabbitMQ connection
docker exec plane-worker ping plane-rabbitmq

# Check RabbitMQ has queues
# Access https://rabbitmq.mohdop.com (use RABBITMQ_USER/PASSWORD)
```

### SSL Certificate Issues

**Symptom:** HTTPS not working, certificate errors

**Solution:**
- Verify DNS points to your server IP
- Wait 5-10 minutes for Let's Encrypt
- Check Traefik logs in Dokploy
- Ensure no firewall blocking ports 80/443

---

## ✅ Post-Deployment Checklist

- [ ] All 6 Dokploy apps deployed and running
- [ ] All containers healthy: `docker ps | grep plane`
- [ ] Frontend accessible: https://plane.mohdop.com
- [ ] API health check passes: https://plane-api.mohdop.com/health/
- [ ] Admin panel accessible: https://plane.mohdop.com/god-mode
- [ ] Live server responding: https://plane.mohdop.com/live
- [ ] MinIO console accessible: https://minio.mohdop.com (use AWS_ACCESS_KEY_ID/SECRET)
- [ ] RabbitMQ console accessible: https://rabbitmq.mohdop.com (use RABBITMQ_USER/PASSWORD)
- [ ] Test email sending from Plane
- [ ] Test file upload/download
- [ ] Test real-time collaboration
- [ ] Verify GitHub auto-deploy: push a commit and check rebuild

---

## 🎉 Success!

Your Plane instance is now running! 🚀

Access your application at: **https://plane.mohdop.com**

### Next Steps

1. **Create admin account** via Django shell:
   ```bash
   docker exec -it plane-api python manage.py createsuperuser
   ```

2. **Configure email** (optional, in `.env.api`):
   ```bash
   EMAIL_HOST=smtp.gmail.com
   EMAIL_HOST_USER=your-email@gmail.com
   EMAIL_HOST_PASSWORD=your-app-password
   ```

3. **Set up backups** using `scripts/backup-data.sh`

4. **Monitor logs** via Dokploy UI or:
   ```bash
   docker logs -f plane-api
   docker logs -f plane-worker
   ```

5. **Scale workers** (if needed):
   - Update `GUNICORN_WORKERS` in `.env.api`
   - Redeploy in Dokploy

---

## 📚 Additional Resources

- [Plane Documentation](https://docs.plane.so)
- [Dokploy Documentation](https://docs.dokploy.com)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [GitHub Issues](https://github.com/makeplane/plane/issues)

---

**Need Help?** Check the [Troubleshooting](#troubleshooting) section or create an issue in your repository.
