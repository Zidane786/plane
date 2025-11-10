# Plane Deployment Guide for Dokploy

Complete guide for deploying Plane project management tool on your VPS using Dokploy with custom domains and HTTPS.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Connecting GitHub to Dokploy](#connecting-github-to-dokploy)
- [Network Configuration](#network-configuration-critical) ⚠️ **CRITICAL**
- [Quick Start](#quick-start)
- [Step-by-Step Deployment](#step-by-step-deployment)
  - [1. Deploy Infrastructure Services](#1-deploy-infrastructure-services)
  - [2. Deploy API Backend](#2-deploy-api-backend)
  - [3. Deploy Celery Workers](#3-deploy-celery-workers)
  - [4. Deploy Frontend](#4-deploy-frontend)
  - [5. Deploy Live Server](#5-deploy-live-server)
  - [6. Configure Domains & HTTPS](#6-configure-domains--https)
- [Migration to External Services](#migration-to-external-services)
- [Backup & Restore](#backup--restore)
- [Monitoring & Health Checks](#monitoring--health-checks)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### Domain Structure

Your Plane deployment will use the following domain structure:

- **plane.mohdop.com** - Main application (frontend)
  - `/` - Web app (main interface)
  - `/god-mode` - Admin panel
  - `/spaces` - Public project views
  - `/live` - Real-time collaboration WebSocket server
- **plane-api.mohdop.com** - Backend API
- **minio.mohdop.com** - MinIO console (file storage UI)
- **rabbitmq.mohdop.com** - RabbitMQ management (optional)

### Application Components

```
┌─────────────────────────────────────────────────────────┐
│                    Dokploy/Traefik                      │
│                  (Reverse Proxy + SSL)                  │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Frontend   │  │  API Backend │  │ Live Server  │
│ (React/Vite) │  │   (Django)   │  │  (Node.js)   │
│  Port 3000   │  │  Port 8000   │  │  Port 3000   │
└──────────────┘  └──────┬───────┘  └──────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Celery Worker│  │ Beat Worker  │  │  PostgreSQL  │
│ (Background) │  │  (Scheduler) │  │  Port 5432   │
└──────────────┘  └──────────────┘  └──────────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│    Redis     │  │   RabbitMQ   │  │    MinIO     │
│  Port 6379   │  │  Port 5672   │  │  Port 9000   │
└──────────────┘  └──────────────┘  └──────────────┘
```

### 📦 Total Services Required

#### **Dokploy Applications: 5 apps**

1. **plane-api** - Django backend API (nixpacks.api.toml)
2. **plane-worker** - Celery worker for background tasks (nixpacks.worker.toml)
3. **plane-beat-worker** - Celery beat for scheduled tasks (nixpacks.beat-worker.toml)
4. **plane-frontend** - React frontend (web + admin + space) (nixpacks.frontend.toml)
5. **plane-live** - Live collaboration WebSocket server (nixpacks.live.toml)

#### **Infrastructure Services: 4 containers** (via docker-compose.infra.yml)

1. **PostgreSQL** (plane-postgres) - Database
2. **Redis** (plane-redis) - Cache & Queue
3. **RabbitMQ** (plane-rabbitmq) - Message broker
4. **MinIO** (plane-minio) - S3-compatible object storage

#### **Total: 9 services**
- **5 Dokploy apps** (created in Dokploy dashboard)
- **4 Docker containers** (run via docker-compose on VPS)

---

## ✅ Prerequisites

### On Your VPS

1. **Dokploy installed and running**
   - Follow: https://dokploy.com/docs/get-started/installation

2. **Domain DNS configured**
   - Point the following A records to your VPS IP:
     - `plane.mohdop.com`
     - `plane-api.mohdop.com`
     - `minio.mohdop.com`
     - `rabbitmq.mohdop.com` (optional)

3. **System Requirements**
   - Minimum: 4 CPU cores, 8GB RAM, 50GB storage
   - Recommended: 8 CPU cores, 16GB RAM, 100GB storage

### On Your Development Machine

1. **Git** - To clone the repository
2. **SSH access** to your VPS
3. **Docker** (optional) - For local testing

---

## 🔗 Connecting GitHub to Dokploy

Before deploying, you need to connect your GitHub repository to Dokploy. Follow these steps:

### Method 1: GitHub App (Recommended)

This method provides the best integration with automatic webhook setup.

1. **Navigate to Dokploy Dashboard**
   - Go to **Settings** → **Git Providers** → **GitHub**

2. **Create GitHub App**
   - Click **"Create Github App"**
   - Enter a unique name (e.g., `plane-dokploy-app`)
   - Click **"Create Github App"** again
   - You'll be redirected to GitHub

3. **Install GitHub App**
   - An **"Install"** button will appear in Dokploy
   - Click **"Install"**
   - Choose repository access:
     - **All repositories** (easier)
     - **Select repositories** (more secure - choose your Plane repo)
   - Click **"Install & Authorize"**

4. **Verify Connection**
   - After redirect, you should see your GitHub account connected
   - Your repositories will be available when creating applications

### Method 2: SSH Keys (Alternative)

If you prefer SSH key authentication:

1. **Generate SSH Key in Dokploy**
   - Go to **Settings** → **Git Providers** → **GitHub**
   - Click **"Generate RSA SSH Key"**
   - Copy the **Public Key**

2. **Add to GitHub**
   - Go to GitHub → **Settings** → **SSH and GPG keys**
   - Click **"New SSH key"**
   - Paste the public key
   - Click **"Add SSH key"**

3. **Configure Repository**
   - When creating apps, use SSH URL format:
     ```
     git@github.com:username/plane.git
     ```

### Auto-Deploy Setup

After connecting, auto-deploy is configured automatically:

- **Default**: Deploys on every push to the selected branch
- **Branch-specific**: Only deploys when changes are pushed to the configured branch
- **Multiple environments**: Create separate apps in Dokploy for dev/staging/production

**Example:**
- **plane-api-dev** → branch: `develop`
- **plane-api-staging** → branch: `staging`
- **plane-api-prod** → branch: `main`

---

## 🌐 Network Configuration (CRITICAL!)

**⚠️ IMPORTANT:** All services MUST be on the same Docker network to communicate!

### How Dokploy Networking Works

By default, Dokploy creates **separate networks** for each app, which means:
- ❌ plane-api **cannot** reach plane-postgres
- ❌ plane-worker **cannot** reach plane-redis
- ❌ plane-frontend **cannot** reach plane-api
- ❌ Services are **ISOLATED** and will fail!

### The Solution: Shared Network

All services must connect to the same Docker network: `plane-network`

```
┌─────────────────────────────────────────────────┐
│         Docker Network: plane-network           │
├─────────────────────────────────────────────────┤
│                                                 │
│  [plane-api] ←→ [plane-postgres]               │
│       ↕              ↕                          │
│  [plane-worker] ←→ [plane-redis]               │
│       ↕              ↕                          │
│  [plane-frontend] ←→ [plane-rabbitmq]          │
│       ↕              ↕                          │
│  [plane-live] ←→ [plane-minio]                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Setup Steps

#### 1. Create the Network First

The `docker-compose.infra.yml` creates `plane-network` automatically:

```bash
# On your VPS
cd /opt/plane
docker-compose -f docker-compose.infra.yml up -d

# Verify network exists
docker network ls | grep plane-network
# Should show: plane-network
```

#### 2. Connect Dokploy Apps to Network

**For EACH Dokploy app**, you need to connect it to `plane-network`:

**Method 1: Via Dokploy UI (Recommended)**

When creating each app in Dokploy:
1. Go to app **Settings** → **Advanced** → **Network**
2. Set **Network Mode**: `Custom Network`
3. Enter **Network Name**: `plane-network`
4. Save and redeploy

**Method 2: Via Docker Commands (Alternative)**

After deploying an app, connect it manually:

```bash
# Get container name
docker ps | grep plane-api

# Connect to network
docker network connect plane-network <container-name>

# Verify
docker network inspect plane-network
```

**Method 3: Via Docker Compose Labels (If using compose mode)**

Add to your app configuration:
```yaml
networks:
  - plane-network

networks:
  plane-network:
    external: true
```

#### 3. Verify Connectivity

After connecting all apps to `plane-network`:

```bash
# Check all containers on the network
docker network inspect plane-network | grep Name

# Should show all containers:
# - plane-postgres
# - plane-redis
# - plane-rabbitmq
# - plane-minio
# - plane-api
# - plane-worker
# - plane-beat-worker
# - plane-frontend
# - plane-live
```

#### 4. Test Communication

From inside any container:

```bash
# From plane-api, test PostgreSQL connection
docker exec -it plane-api ping plane-postgres

# From plane-worker, test Redis connection
docker exec -it plane-worker ping plane-redis

# From plane-frontend, test API connection
docker exec -it plane-frontend curl http://plane-api:8000/api/health/
```

### Container Name Resolution

Once on the same network, containers can reach each other by name:

| Service Type | Container Name | How Others Reach It |
|-------------|----------------|---------------------|
| PostgreSQL | plane-postgres | `postgresql://plane-postgres:5432` |
| Redis | plane-redis | `redis://plane-redis:6379` |
| RabbitMQ | plane-rabbitmq | `amqp://plane-rabbitmq:5672` |
| MinIO | plane-minio | `http://plane-minio:9000` |
| API | plane-api | `http://plane-api:8000` |
| Live | plane-live | `http://plane-live:3000` |

**This is why your .env files use these names!**

### Common Network Issues

**Issue:** "Connection refused" or "Host not found"
- **Cause:** App not connected to `plane-network`
- **Fix:** Connect app to network using Method 1 or 2 above

**Issue:** "Name or service not known"
- **Cause:** Wrong container name in environment variables
- **Fix:** Use exact container names from docker-compose.infra.yml

**Issue:** "Cannot connect to database"
- **Cause:** Infrastructure services not running or not on same network
- **Fix:** Ensure `docker-compose.infra.yml` is running and network exists

---

## 🚀 Quick Start

### 1. Clone & Prepare

```bash
# Clone your Plane repository
cd /path/to/plane

# Copy environment examples
cp .env.infra.example .env.infra
cp .env.api.example .env.api
cp .env.frontend.example .env.frontend
cp .env.live.example .env.live

# Edit and customize environment variables
nano .env.infra
```

### 2. Deploy Infrastructure

```bash
# Copy docker-compose.infra.yml to your VPS
scp docker-compose.infra.yml user@your-vps:/opt/plane/
scp .env.infra user@your-vps:/opt/plane/.env

# SSH into VPS and start infrastructure
ssh user@your-vps
cd /opt/plane
docker-compose -f docker-compose.infra.yml up -d
```

### 3. Deploy Apps via Dokploy UI

Follow the detailed steps in [Step-by-Step Deployment](#step-by-step-deployment) section.

---

## 📖 Step-by-Step Deployment

### 1. Deploy Infrastructure Services

Infrastructure services (PostgreSQL, Redis, RabbitMQ, MinIO) run as Docker containers outside of Dokploy.

#### On Your VPS:

```bash
# Create directory
mkdir -p /opt/plane
cd /opt/plane

# Copy files (from your dev machine)
# scp docker-compose.infra.yml .env.infra user@vps:/opt/plane/

# Edit .env.infra and customize passwords
nano .env.infra

# Start infrastructure services
docker-compose -f docker-compose.infra.yml up -d

# Verify services are running
docker-compose -f docker-compose.infra.yml ps

# Check logs
docker-compose -f docker-compose.infra.yml logs -f
```

#### Configure DNS Labels

The `docker-compose.infra.yml` includes Traefik labels for:
- MinIO Console: `minio.mohdop.com`
- RabbitMQ Management: `rabbitmq.mohdop.com`

These will automatically get SSL certificates via Let's Encrypt.

#### Get Container Network Info

```bash
# Get container names for environment variables
docker ps --format "{{.Names}}"

# You'll use these names in your app environment variables:
# - plane-postgres (for DATABASE_URL)
# - plane-redis (for REDIS_URL)
# - plane-rabbitmq (for RABBITMQ_HOST)
# - plane-minio (for AWS_S3_ENDPOINT_URL)
```

---

### 2. Deploy API Backend

#### Create New App in Dokploy

1. **Go to Dokploy Dashboard** → Create New Application

2. **General Settings:**
   - **Name:** `plane-api`
   - **App Name:** `plane-api`

3. **Source Configuration:**
   - **Provider:** Select your connected GitHub account
   - **Repository:** Select your Plane repository
   - **Branch:** `main` (or your deployment branch)

4. **Build Configuration:**
   - **Build Type:** Select `Nixpacks`
   - **Nixpacks Config Path:** Leave empty (will auto-detect `nixpacks.api.toml` at root)
   - Alternatively, you can specify: `nixpacks.api.toml`

> **Note:** Dokploy will automatically detect and use the `nixpacks.api.toml` file in your repository root. The file contains all build and start commands needed for the API.

5. **Environment Variables:**

Copy all variables from `.env.api.example` and customize:

**Critical Variables:**

```bash
# Django
SECRET_KEY=<generate-a-secure-random-key>
DEBUG=0
ALLOWED_HOSTS=plane-api.mohdop.com,localhost

# Database (Docker containers)
DATABASE_URL=postgresql://plane:your-password@plane-postgres:5432/plane
PGHOST=plane-postgres
PGUSER=plane
PGPASSWORD=your-password
PGDATABASE=plane

# Redis
REDIS_URL=redis://plane-redis:6379/
REDIS_HOST=plane-redis
REDIS_PORT=6379

# RabbitMQ
RABBITMQ_HOST=plane-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_VHOST=plane
RABBITMQ_DEFAULT_USER=plane
RABBITMQ_DEFAULT_PASS=your-password
CELERY_BROKER_URL=amqp://plane:your-password@plane-rabbitmq:5672/plane

# URLs
WEB_URL=https://plane.mohdop.com
API_BASE_URL=https://plane-api.mohdop.com
ADMIN_BASE_URL=https://plane.mohdop.com
ADMIN_BASE_PATH=/god-mode
SPACE_BASE_URL=https://plane.mohdop.com
SPACE_BASE_PATH=/spaces
LIVE_BASE_URL=https://plane.mohdop.com
LIVE_BASE_PATH=/live

# CORS
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com

# Storage (MinIO)
USE_MINIO=1
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=your-password
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
FILE_SIZE_LIMIT=5242880
MINIO_ENDPOINT_SSL=0

# Gunicorn
GUNICORN_WORKERS=2
```

5. **Domain Configuration:**
   - Domain: `plane-api.mohdop.com`
   - Enable HTTPS (Let's Encrypt)
   - Port: `8000`

6. **Network Configuration (CRITICAL!):**

   **⚠️ MUST DO:** Connect to `plane-network` so API can reach PostgreSQL/Redis/RabbitMQ

   - Go to **Settings** → **Advanced** → **Network**
   - Set **Network Mode**: `Custom Network`
   - Enter **Network Name**: `plane-network`
   - Save

   **Without this, the API CANNOT connect to the database!**

7. **Deploy:**
   - Click "Deploy"
   - Wait for build and deployment
   - Check logs for any errors

#### Verify API Deployment

```bash
# Check health
./healthcheck/api.sh https://plane-api.mohdop.com

# Or with curl
curl https://plane-api.mohdop.com/api/health/
```

#### Run Database Migrations

After first deployment, run migrations:

```bash
# Via Dokploy console or SSH into the API container
docker exec -it plane-api python apps/api/manage.py migrate

# Create superuser
docker exec -it plane-api python apps/api/manage.py createsuperuser
```

---

### 3. Deploy Celery Workers

**⚠️ CRITICAL:** Celery workers are essential for background tasks like:
- Sending email notifications
- Processing webhooks
- Running scheduled cleanups
- Generating reports
- Handling async operations

You need to deploy **TWO separate apps** in Dokploy:
1. **Celery Worker** - Handles background tasks
2. **Beat Worker** - Handles scheduled/periodic tasks

---

#### A. Deploy Celery Worker

1. **Create New App in Dokploy**
   - Name: `plane-worker`
   - Build Type: `Nixpacks`
   - Repository: Your Plane Git repository
   - Branch: `main`

2. **Nixpacks Configuration:**
   - Config path: `/nixpacks.worker.toml`

3. **Environment Variables:**

Copy all variables from `.env.worker.example`. **IMPORTANT:** Use the **same values** as your API app for:
- SECRET_KEY
- Database credentials
- Redis credentials
- RabbitMQ credentials
- Storage credentials

```bash
# Django
SECRET_KEY=<same-as-api>
DEBUG=0
DJANGO_SETTINGS_MODULE=plane.settings.production

# Database (same as API)
DATABASE_URL=postgresql://plane:your-password@plane-postgres:5432/plane
PGHOST=plane-postgres
PGUSER=plane
PGPASSWORD=your-password
PGDATABASE=plane

# Redis (same as API)
REDIS_URL=redis://plane-redis:6379/
REDIS_HOST=plane-redis
REDIS_PORT=6379

# RabbitMQ (same as API)
RABBITMQ_HOST=plane-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_VHOST=plane
RABBITMQ_DEFAULT_USER=plane
RABBITMQ_DEFAULT_PASS=your-password
CELERY_BROKER_URL=amqp://plane:your-password@plane-rabbitmq:5672/plane

# Storage (same as API)
USE_MINIO=1
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=your-password
AWS_S3_ENDPOINT_URL=http://plane-minio:9000
AWS_S3_BUCKET_NAME=uploads
MINIO_ENDPOINT_SSL=0

# URLs (for generating links)
WEB_URL=https://plane.mohdop.com
API_BASE_URL=https://plane-api.mohdop.com

# Email (for sending emails from worker)
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noreply@mohdop.com

# Python
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1
```

4. **Network Configuration (CRITICAL!):**

   **⚠️ MUST DO:** Connect to `plane-network`

   - Go to **Settings** → **Advanced** → **Network**
   - Set **Network Mode**: `Custom Network`
   - Enter **Network Name**: `plane-network`
   - Save

5. **Domain:**
   - **No domain needed** - Workers don't serve HTTP traffic

6. **Deploy:**
   - Click "Deploy"
   - Check logs for successful startup

---

#### B. Deploy Beat Worker (Scheduler)

1. **Create New App in Dokploy**
   - Name: `plane-beat-worker`
   - Build Type: `Nixpacks`
   - Repository: Your Plane Git repository
   - Branch: `main`

2. **Nixpacks Configuration:**
   - Config path: `/nixpacks.beat-worker.toml`

3. **Environment Variables:**
   - **Use exactly the same environment variables as the Worker app above**
   - Copy all variables from `.env.worker.example`

4. **Network Configuration (CRITICAL!):**

   **⚠️ MUST DO:** Connect to `plane-network`

   - Go to **Settings** → **Advanced** → **Network**
   - Set **Network Mode**: `Custom Network`
   - Enter **Network Name**: `plane-network`
   - Save

5. **Domain:**
   - **No domain needed**

6. **Deploy:**
   - Click "Deploy"
   - Check logs for "beat: Starting..."

---

#### Verify Worker Deployment

```bash
# Check worker logs in Dokploy UI
# You should see:
# - "Connected to amqp://..." (RabbitMQ connection)
# - "celery@hostname ready" (Worker ready)

# Check beat-worker logs
# You should see:
# - "beat: Starting..."
# - "Scheduler: Sending due task..." (periodic tasks)
```

**⚠️ IMPORTANT:** Workers must be running BEFORE the API is fully functional. Deploy workers AFTER API but BEFORE using the application.

---

### 4. Deploy Frontend

The frontend serves three applications: web (main), admin, and space.

#### Option A: Using Existing Dockerfile

Plane already has Dockerfiles for frontend apps. Use Docker build type in Dokploy:

1. **Create New App in Dokploy**
   - Name: `plane-frontend`
   - Build Type: `Docker`
   - Dockerfile Path: `apps/web/Dockerfile.web`

2. **Build Configuration:**

Since this is a monorepo, you need to build with the entire context:

```dockerfile
# Dokploy will automatically detect and use apps/web/Dockerfile.web
# The Dockerfile already handles the monorepo structure
```

3. **Environment Variables:**

Copy from `.env.frontend.example`:

```bash
# API Configuration
NEXT_PUBLIC_API_BASE_URL=https://plane-api.mohdop.com
VITE_API_BASE_URL=https://plane-api.mohdop.com

# App URLs
NEXT_PUBLIC_WEB_BASE_URL=https://plane.mohdop.com
VITE_WEB_BASE_URL=https://plane.mohdop.com

NEXT_PUBLIC_ADMIN_BASE_URL=https://plane.mohdop.com
VITE_ADMIN_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_ADMIN_BASE_PATH=/god-mode
VITE_ADMIN_BASE_PATH=/god-mode

NEXT_PUBLIC_SPACE_BASE_URL=https://plane.mohdop.com
VITE_SPACE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_SPACE_BASE_PATH=/spaces
VITE_SPACE_BASE_PATH=/spaces

NEXT_PUBLIC_LIVE_BASE_URL=https://plane.mohdop.com
VITE_LIVE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_LIVE_BASE_PATH=/live
VITE_LIVE_BASE_PATH=/live

# Deployment
NODE_ENV=production
PORT=3000
```

4. **Domain Configuration:**
   - Domain: `plane.mohdop.com`
   - Enable HTTPS (Let's Encrypt)
   - Port: `3000`

5. **Network Configuration (CRITICAL!):**

   **⚠️ MUST DO:** Connect to `plane-network` so frontend can reach API

   - Go to **Settings** → **Advanced** → **Network**
   - Set **Network Mode**: `Custom Network`
   - Enter **Network Name**: `plane-network`
   - Save

6. **Deploy**

#### Option B: Using Nixpacks

If you prefer nixpacks (already configured):

1. Use Build Type: `Nixpacks`
2. Config: Point to `nixpacks.frontend.toml`
3. Same environment variables as above

#### Verify Frontend Deployment

```bash
# Check health
./healthcheck/frontend.sh https://plane.mohdop.com

# Check different routes
curl -I https://plane.mohdop.com/
curl -I https://plane.mohdop.com/god-mode
curl -I https://plane.mohdop.com/spaces
```

---

### 5. Deploy Live Server

The live server handles real-time collaboration via WebSocket.

#### Create New App in Dokploy

1. **App Settings:**
   - Name: `plane-live`
   - Build Type: `Nixpacks`
   - Config: Point to `nixpacks.live.toml`

2. **Environment Variables:**

Copy from `.env.live.example`:

```bash
# Server
PORT=3000
NODE_ENV=production

# URLs
API_BASE_URL=https://plane-api.mohdop.com
WEB_BASE_URL=https://plane.mohdop.com
LIVE_BASE_URL=https://plane.mohdop.com
LIVE_BASE_PATH=/live

# Authentication (must match API secret)
LIVE_SERVER_SECRET_KEY=<same-as-api-secret-key>

# Redis
REDIS_URL=redis://plane-redis:6379/
REDIS_HOST=plane-redis
REDIS_PORT=6379

# CORS
ALLOWED_ORIGINS=https://plane.mohdop.com

# WebSocket Configuration
WS_HEARTBEAT_INTERVAL=30000
WS_HEARTBEAT_TIMEOUT=90000
MAX_CONNECTIONS_PER_ROOM=100
```

3. **Domain Configuration (Path-based Routing):**

Since live server runs on the same domain with `/live` path:

**Method 1: Using Traefik Path Prefix (Recommended)**

Add these labels in Dokploy:

```yaml
traefik.http.routers.plane-live.rule=Host(`plane.mohdop.com`) && PathPrefix(`/live`)
traefik.http.routers.plane-live.entrypoints=websecure
traefik.http.routers.plane-live.tls=true
traefik.http.routers.plane-live.tls.certresolver=letsencrypt
traefik.http.services.plane-live.loadbalancer.server.port=3000
```

**Method 2: Using Separate Port with Manual Proxy**

Alternatively, expose on a different port and configure Traefik manually.

4. **Network Configuration (CRITICAL!):**

   **⚠️ MUST DO:** Connect to `plane-network` so live server can reach Redis/API

   - Go to **Settings** → **Advanced** → **Network**
   - Set **Network Mode**: `Custom Network`
   - Enter **Network Name**: `plane-network`
   - Save

5. **Deploy**

#### Verify Live Server

```bash
# Check health
./healthcheck/live.sh https://plane.mohdop.com/live

# Test WebSocket connection (if wscat installed)
wscat -c wss://plane.mohdop.com/live
```

---

### 6. Configure Domains & HTTPS

#### DNS Configuration

Ensure all domains point to your VPS IP:

```bash
# Check DNS resolution
dig plane.mohdop.com
dig plane-api.mohdop.com
dig minio.mohdop.com
```

#### HTTPS Certificates

Dokploy uses Traefik with automatic Let's Encrypt certificates:

1. **In Dokploy:** Enable HTTPS for each app
2. **Certificate Resolver:** Select `letsencrypt`
3. **Auto-renewal:** Traefik handles this automatically

#### Verify HTTPS

```bash
# Check SSL certificates
curl -vI https://plane.mohdop.com 2>&1 | grep -i "SSL\|TLS"
curl -vI https://plane-api.mohdop.com 2>&1 | grep -i "SSL\|TLS"
curl -vI https://minio.mohdop.com 2>&1 | grep -i "SSL\|TLS"
```

---

## 🔄 Migration to External Services

### Migrate PostgreSQL to Managed Database

When you're ready to move from Docker PostgreSQL to a managed service (AWS RDS, DigitalOcean, etc.):

```bash
# Run migration script
./scripts/migrate-postgres-to-external.sh

# Follow the interactive prompts
# Script will:
# 1. Export data from Docker container
# 2. Import to external database
# 3. Validate migration
# 4. Generate new environment variables
```

After migration:

1. Update `.env.api` in Dokploy with new database connection
2. Restart API app
3. Verify application works
4. Stop Docker PostgreSQL container (keep backup!)

### Migrate MinIO to S3/Spaces

To migrate from self-hosted MinIO to AWS S3 or DigitalOcean Spaces:

```bash
# Run migration script
./scripts/migrate-storage-to-s3.sh

# Follow the interactive prompts
# Script will:
# 1. Sync files from MinIO to S3
# 2. Validate file transfer
# 3. Generate new environment variables
```

After migration:

1. Update `.env.api` in Dokploy:
   ```bash
   USE_MINIO=0
   AWS_REGION=your-region
   AWS_ACCESS_KEY_ID=your-key
   AWS_SECRET_ACCESS_KEY=your-secret
   AWS_S3_BUCKET_NAME=your-bucket
   # Remove AWS_S3_ENDPOINT_URL for AWS S3
   # Or set to Spaces endpoint for DigitalOcean
   ```
2. Restart API app
3. Test file uploads
4. Stop MinIO container (keep backup!)

---

## 💾 Backup & Restore

### Automated Backups

Set up automated backups using the included script:

```bash
# Manual backup
./scripts/backup-data.sh

# Database only
./scripts/backup-data.sh --database-only

# Storage only
./scripts/backup-data.sh --storage-only
```

### Schedule with Cron

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/plane/scripts/backup-data.sh >> /var/log/plane-backup.log 2>&1

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 /opt/plane/scripts/backup-data.sh >> /var/log/plane-backup-weekly.log 2>&1
```

### Restore from Backup

```bash
# See detailed instructions in:
cat backups/RESTORE.md

# Quick restore database
gunzip -c backups/database/latest.sql.gz | docker exec -i plane-postgres psql -U plane -d plane

# Quick restore storage
tar -xzf backups/storage/plane_storage_YYYYMMDD.tar.gz -C /tmp/restore
docker cp /tmp/restore/. plane-minio:/data/uploads/
```

### Off-site Backups

Sync backups to remote storage:

```bash
# To AWS S3
aws s3 sync ./backups/ s3://your-backup-bucket/plane-backups/

# To DigitalOcean Spaces
s3cmd sync ./backups/ s3://your-space/plane-backups/

# Using rclone
rclone sync ./backups/ remote:plane-backups/
```

---

## 📊 Monitoring & Health Checks

### Manual Health Checks

Use provided health check scripts:

```bash
# Check all services
./healthcheck/api.sh https://plane-api.mohdop.com
./healthcheck/frontend.sh https://plane.mohdop.com
./healthcheck/live.sh https://plane.mohdop.com/live
```

### Setup Monitoring with Dokploy

Dokploy includes monitoring features:

1. **Metrics:** View CPU, Memory, Network usage per app
2. **Logs:** Real-time log streaming
3. **Alerts:** Configure alerts for high resource usage

### External Monitoring

Setup external monitoring services:

- **UptimeRobot:** Monitor uptime and response time
- **Better Uptime:** Advanced monitoring with status page
- **Sentry:** Error tracking (configure SENTRY_DSN in environment)
- **Scout APM:** Performance monitoring (configure SCOUT_KEY)

### Log Aggregation

```bash
# View logs for each service
docker logs -f plane-postgres
docker logs -f plane-redis
docker logs -f plane-rabbitmq
docker logs -f plane-minio

# Dokploy app logs available in UI
```

---

## 🔧 Troubleshooting

### API Not Starting

**Check Logs:**
```bash
# In Dokploy UI, check build and runtime logs
```

**Common Issues:**

1. **Database Connection Failed**
   ```bash
   # Verify container is running
   docker ps | grep plane-postgres

   # Test connection
   docker exec plane-postgres psql -U plane -d plane -c "SELECT 1;"

   # Check network
   docker network inspect plane-network
   ```

2. **Migration Errors**
   ```bash
   # Reset migrations (CAUTION: will lose data)
   docker exec -it plane-api python apps/api/manage.py migrate --fake-initial

   # Or run migrations manually
   docker exec -it plane-api python apps/api/manage.py migrate
   ```

3. **Permission Issues**
   ```bash
   # Fix file permissions
   docker exec -it plane-api chown -R nobody:nobody /app
   ```

### Frontend Build Failures

**Common Issues:**

1. **Out of Memory During Build**
   ```bash
   # Increase Node memory in Dokploy build settings
   NODE_OPTIONS=--max-old-space-size=4096
   ```

2. **Dependency Installation Fails**
   ```bash
   # Clear pnpm cache
   rm -rf node_modules
   rm pnpm-lock.yaml
   pnpm install
   ```

3. **Environment Variables Not Applied**
   ```bash
   # Rebuild with --no-cache
   # In Dokploy, trigger a clean rebuild
   ```

### Live Server WebSocket Issues

**Check WebSocket Connection:**

```bash
# Test with wscat
npm install -g wscat
wscat -c wss://plane.mohdop.com/live

# Check Traefik configuration
docker exec traefik cat /etc/traefik/traefik.yml
```

**Common Issues:**

1. **WebSocket Upgrade Failed**
   - Ensure Traefik has WebSocket support enabled
   - Check CORS configuration
   - Verify path routing is correct

2. **Connection Timeout**
   - Increase timeout in Traefik:
   ```yaml
   http:
     services:
       plane-live:
         loadBalancer:
           passHostHeader: true
           responseForwarding:
             flushInterval: 1ms
   ```

### Storage/MinIO Issues

**Check MinIO Status:**

```bash
# Check container
docker ps | grep plane-minio

# Check logs
docker logs plane-minio

# Access MinIO console
open https://minio.mohdop.com

# Login with credentials from .env.infra
```

**Common Issues:**

1. **Cannot Upload Files**
   - Check bucket permissions
   - Verify AWS credentials in API environment
   - Check FILE_SIZE_LIMIT setting

2. **Files Not Accessible**
   - Check bucket policy (public read?)
   - Verify endpoint URLs
   - Check CORS configuration

### Database Performance Issues

**Check Database Stats:**

```bash
# Connection count
docker exec plane-postgres psql -U plane -d plane -c "SELECT count(*) FROM pg_stat_activity;"

# Long running queries
docker exec plane-postgres psql -U plane -d plane -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC;"

# Database size
docker exec plane-postgres psql -U plane -d plane -c "SELECT pg_size_pretty(pg_database_size('plane'));"
```

**Optimize:**

```bash
# Run VACUUM
docker exec plane-postgres psql -U plane -d plane -c "VACUUM ANALYZE;"

# Reindex
docker exec plane-postgres psql -U plane -d plane -c "REINDEX DATABASE plane;"
```

### SSL Certificate Issues

**Check Certificate:**

```bash
# View certificate details
echo | openssl s_client -servername plane.mohdop.com -connect plane.mohdop.com:443 2>/dev/null | openssl x509 -noout -dates -subject

# Force certificate renewal in Traefik
docker exec traefik traefik healthcheck
```

**Common Issues:**

1. **Certificate Not Issued**
   - Check DNS is propagated
   - Verify port 80/443 are open
   - Check Traefik logs
   - Ensure email is configured in Let's Encrypt

2. **Certificate Expired**
   - Traefik auto-renews, but check:
   ```bash
   docker logs traefik | grep -i "renew\|certificate"
   ```

---

## 🆘 Getting Help

### Check Logs

1. **Dokploy UI:** View real-time logs for each app
2. **Infrastructure logs:**
   ```bash
   docker-compose -f docker-compose.infra.yml logs -f [service]
   ```

### Useful Commands

```bash
# Check all containers
docker ps -a

# Check disk usage
df -h
docker system df

# Check Docker networks
docker network ls
docker network inspect plane-network

# Check memory usage
free -h

# Check ports
netstat -tulpn | grep -E '(3000|5432|6379|5672|9000)'
```

### Community & Documentation

- **Plane Documentation:** https://docs.plane.so
- **Dokploy Documentation:** https://dokploy.com/docs
- **Plane GitHub:** https://github.com/makeplane/plane
- **Plane Discord:** https://discord.com/invite/plane

---

## ✅ Post-Deployment Checklist

- [ ] All services are running and healthy
- [ ] HTTPS certificates are active for all domains
- [ ] Database migrations completed successfully
- [ ] Superuser account created
- [ ] File uploads working correctly
- [ ] Real-time collaboration functional
- [ ] Automated backups configured
- [ ] Monitoring/alerting set up
- [ ] DNS configured correctly
- [ ] Firewall rules configured
- [ ] Environment variables secured
- [ ] Documentation reviewed by team

---

## 🎉 Congratulations!

Your Plane instance is now deployed and running on Dokploy with:

- ✅ Custom domains with HTTPS
- ✅ Scalable architecture
- ✅ Automated backups
- ✅ Easy migration path to managed services
- ✅ Production-ready configuration

Access your Plane instance at: **https://plane.mohdop.com**

---

## 📝 Maintenance

### Regular Tasks

**Daily:**
- Check application health
- Review logs for errors
- Monitor resource usage

**Weekly:**
- Review backup status
- Check for security updates
- Monitor disk space

**Monthly:**
- Update dependencies
- Review and optimize database
- Test backup restoration
- Review access logs

### Updating Plane

```bash
# Pull latest changes
git pull origin main

# Rebuild in Dokploy
# Trigger rebuild for each app in Dokploy UI

# Run migrations if needed
docker exec -it plane-api python apps/api/manage.py migrate
```

---

**Need help?** Check the troubleshooting section or reach out to the Plane community!
