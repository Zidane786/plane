# Plane Dokploy Deployment Guide

Complete step-by-step guide to deploy Plane on your Dokploy VPS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Architecture](#deployment-architecture)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Troubleshooting](#troubleshooting)
7. [Backup & Maintenance](#backup--maintenance)

---

## Prerequisites

### 1. **VPS Requirements**

- **RAM**: Minimum 4GB (8GB+ recommended for production)
- **CPU**: 2+ cores
- **Storage**: 50GB+ SSD
- **OS**: Ubuntu 22.04 LTS (or supported Linux distribution)
- **Dokploy**: Installed and configured

### 2. **Domain Names**

You'll need **2 domain names** pointing to your VPS (configured in Dokploy):

| Domain | Purpose | Required | Configure in Dokploy |
|--------|---------|----------|---------------------|
| `plane.mohdop.com` | Frontend (Web, Admin, Space, Live) | ✅ Yes | Frontend app only |
| `plane-api.mohdop.com` | Backend API | ✅ Yes | API app only |

**Optional** (for admin access to infrastructure - Traefik labels already configured):
- `rabbitmq.mohdop.com` - RabbitMQ Management UI (always available if configured)
- `minio.mohdop.com` - MinIO Console (**only if using self-hosted MinIO storage**, not needed for DO Spaces/AWS S3)

**Note on Storage:**
- **Using Digital Ocean Spaces or AWS S3**: MinIO domain not needed (manage via cloud provider console)
- **Using self-hosted MinIO**: Uncomment MinIO in `docker-compose.infra.yml` and configure `minio.mohdop.com` domain

**DNS Configuration:**
```
Type: A Record
Name: plane
Value: <your-vps-ip>

Type: A Record
Name: plane-api
Value: <your-vps-ip>
```

### 3. **External Services**

**Required:**
- **Digital Ocean Spaces** (or AWS S3): S3-compatible object storage
  - Create a Space in DO Console
  - Generate access keys with **Read + Write** permissions
  - Note the region (e.g., nyc3, sfo3, ams3)

**Optional:**
- **OpenAI API Key**: Get from https://platform.openai.com/api-keys (can add later via admin panel)
- **Custom SMTP Server**: For sending notification emails

### 4. **Repository Access**

- Clone this repository to your local machine
- Ensure all `.env` files are created (see `.env.*.example` files)

---

## Pre-Deployment Checklist

### ✅ **Before You Start**

- [ ] Dokploy is installed and accessible
- [ ] Domain names are pointing to your VPS
- [ ] SSL certificates will be auto-provisioned by Traefik (Let's Encrypt)
- [ ] All `.env` files are created and configured:
  - [ ] `.env.infra` - Infrastructure services
  - [ ] `.env.api` - API backend
  - [ ] `.env.frontend` - Frontend apps
  - [ ] `.env.live` - Live server
  - [ ] `.env.worker` - Worker
  - [ ] `.env.beat-worker` - Beat worker
- [ ] Secure passwords and keys are generated (not using defaults!)
- [ ] OpenAI API key is obtained (if using AI features)
- [ ] Email SMTP credentials are ready

### ⚠️ **Security Warning**

**NEVER use default passwords in production!** The `.env` files provided have secure randomly-generated credentials. Make sure to:
1. Keep `.env` files secure and never commit them to git
2. Use the generated passwords provided
3. Store credentials in a password manager

### 🔑 **Generating Secure Credentials**

All credentials in this deployment must be cryptographically secure. Use these commands to generate secrets:

#### **Django SECRET_KEY** (50+ characters)
```bash
# Generate SECRET_KEY for Django
python3 -c 'import secrets; print(secrets.token_urlsafe(50))'

# Example output:
# LtBkbgDqp-ZUlhkBjoO3kH6ftJpj6TcXR_w5HhKVsezQ_qK52pxAAUXokyJlwOUUh_U
```

**Used in**: `.env.api`, `.env.worker`, `.env.beat-worker`, `.env.live`, `.env.migrator`
**CRITICAL**: Must be **identical** across all these files!

#### **Database Password** (32+ characters)
```bash
# Generate PostgreSQL password
openssl rand -base64 32

# Example output:
# ajMeB9eLtQSBfZS_vz4R1ELZE9n34KL3RzhhoK4EqJg=
```

**Used in**: `.env.infra`, `.env.api`, `.env.worker`, `.env.beat-worker`, `.env.migrator`
**CRITICAL**: Must match across all files!

#### **RabbitMQ Password** (32+ characters)
```bash
# Generate RabbitMQ password
openssl rand -base64 32

# Example output:
# lnI5L_985_Ikx6w6l73D9_XeS9m361SCetuBp_UwjBU=
```

**Used in**: `.env.infra`, `.env.api`, `.env.worker`, `.env.beat-worker`
**CRITICAL**: Must match across all files!

#### **Storage Credentials** (DO Spaces / AWS S3)

**For Digital Ocean Spaces:**
- Generate access keys from DO Console: https://cloud.digitalocean.com/account/api/tokens
- Select "Spaces access keys"
- Create new key with Read + Write permissions

**For MinIO (self-hosted):**
```bash
# Generate MinIO access key (27 characters)
openssl rand -base64 20 | tr -d '/+=' | head -c 27

# Generate MinIO secret key (40+ characters)
openssl rand -base64 40

# Example outputs:
# Access Key: fHr_yxVxIsgYxs479hf_Tzf74cM
# Secret Key: Cg28nyvS0HVe6Ph7ovUmx2xBPQi3NrW56oOVQcbw5Y27RsTHI81tTw==
```

**Used in**: `.env.api`, `.env.worker` (and `.env.infra` only if using MinIO)

#### **Quick Generate All Secrets Script**
```bash
#!/bin/bash
echo "=== Plane Deployment - Secret Generation ==="
echo ""
echo "SECRET_KEY (use in all backend services):"
python3 -c 'import secrets; print(secrets.token_urlsafe(50))'
echo ""
echo "POSTGRES_PASSWORD:"
openssl rand -base64 32
echo ""
echo "RABBITMQ_PASSWORD:"
openssl rand -base64 32
echo ""
echo "MINIO_ACCESS_KEY (if using self-hosted MinIO):"
openssl rand -base64 20 | tr -d '/+=' | head -c 27
echo ""
echo "MINIO_SECRET_KEY (if using self-hosted MinIO):"
openssl rand -base64 40
echo ""
echo "⚠️  IMPORTANT: Copy these values to a password manager NOW!"
echo "⚠️  You will need to add them to multiple .env files"
```

**Save this script and run it once** before creating your `.env` files. Store all generated values in a password manager.

---

## Deployment Architecture

Plane is deployed as **6 separate Dokploy applications** + 1 one-time migrator:

```
┌─────────────────────────────────────────────────────────────────┐
│                      DEPLOYMENT ORDER                           │
├─────────────────────────────────────────────────────────────────┤
│  1. Infrastructure (Postgres, Redis, RabbitMQ)                 │
│     ↓ Creates: plane-network                                   │
│     ↓ Type: Docker Compose (3 services)                        │
│  2. Migrator (Database Migrations) **ONE-TIME**                 │
│     ↓ Runs Django migrations, creates DB schema                │
│     ↓ Type: Docker Compose (runs once, then delete)            │
│  3. API Backend (Django)                                        │
│     ↓ Serves REST API on plane-api.mohdop.com                  │
│     ↓ Type: Docker Compose (needs domain: plane-api.mohdop.com)│
│  4. Worker (Celery)                                             │
│     ↓ Type: Docker Compose (no domain needed)                  │
│  5. Beat Worker (Celery Beat)                                   │
│     ↓ Type: Docker Compose (no domain needed)                  │
│  6. Live Server (WebSocket)                                     │
│     ↓ Type: Docker Compose (proxied via frontend)              │
│  7. Frontend (Web + Admin + Space)                              │
│     └ Type: Nixpacks (needs domain: plane.mohdop.com)          │
└─────────────────────────────────────────────────────────────────┘
```

**Understanding the Services:**
- **5 Docker Compose projects** = Backend services (infra, API, worker, beat-worker, live)
- **1 Nixpacks project** = Frontend (auto-builds React apps from `apps/app/` folder)
- **1 One-time migrator** = Runs database migrations (delete after completion)
- **Total containers running**: 8 (Postgres, Redis, RabbitMQ, API, Worker, Beat, Live, Frontend)

**Why 6 applications?**
- **Separation of concerns**: Each service can scale independently
- **Better resource management**: Control CPU/memory per service
- **Easier debugging**: Isolate issues to specific services
- **Flexibility**: Update/restart individual services without affecting others

**Domain Configuration in Dokploy:**
- Only 2 services need domains configured in Dokploy's "Domains" tab:
  - **Frontend**: `plane.mohdop.com`
  - **API**: `plane-api.mohdop.com`
- Other services either run internally or use Traefik labels (RabbitMQ UI)

---

## Step-by-Step Deployment

### **Step 1: Create Infrastructure Application**

The infrastructure application creates the shared network and all backend services.

#### 1.1 **Create Application in Dokploy**

1. Open Dokploy dashboard
2. Click **"Create Application"**
3. Name: `plane-infrastructure`
4. Type: **Docker Compose**

#### 1.2 **Configure Docker Compose**

1. In the application settings, go to **"Compose"** tab
2. Upload or paste the contents of `deployment/6-services/docker-compose.infra.yml`
3. The file contains these services:
   - `postgres` - PostgreSQL database
   - `redis` - Redis cache
   - `rabbitmq` - RabbitMQ message broker
   - `minio` + `minio-setup` - **COMMENTED OUT** (using DO Spaces instead)

**Note:** MinIO services are commented out by default. If you want to use self-hosted MinIO instead of DO Spaces/AWS S3, uncomment the MinIO sections in the docker-compose file.

#### 1.3 **Set Environment Variables**

1. Go to **"Environment"** tab
2. Click **"Add Environment Variable"** or upload `deployment/6-services/.env.infra`
3. Add all variables from `.env.infra`:

```bash
# PostgreSQL Configuration
POSTGRES_USER=plane
POSTGRES_PASSWORD=<your-generated-postgres-password>
POSTGRES_DB=plane
POSTGRES_MAX_CONNECTIONS=1000
PGDATA=/var/lib/postgresql/data

# Redis Configuration
REDIS_HOST=plane-redis
REDIS_PORT=6379

# RabbitMQ Configuration
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=<your-generated-rabbitmq-password>
RABBITMQ_VHOST=plane
```

**Note:** Storage (S3) credentials are NOT needed in infra env file when using DO Spaces/AWS S3. They go in the API and worker env files only.

#### 1.4 **Deploy**

1. Click **"Deploy"**
2. Wait for all services to start (this may take 2-3 minutes)
3. Verify network is created: `docker network ls | grep plane-network`

#### 1.5 **Verify Infrastructure**

Run these commands on your VPS:

```bash
# Check all containers are running
docker ps | grep plane

# Should show (3 containers):
# plane-postgres
# plane-redis
# plane-rabbitmq

# Check network exists
docker network inspect plane-network

# Verify postgres is accepting connections
docker exec plane-postgres pg_isready -U plane
# Should show: accepting connections
```

---

### **Step 2: Run Database Migrations (ONE-TIME)**

**IMPORTANT:** This step runs database migrations to create all tables and schema. Run this ONCE before deploying the API.

#### 2.1 **Create Migrator Application**

1. Click **"Create Application"**
2. Name: `plane-migrator`
3. Type: **Docker Compose**

#### 2.2 **Configure Docker Compose**

1. Upload or paste `deployment/6-services/docker-compose.migrator.yml`
2. Network configuration:
   ```yaml
   networks:
     plane-network:
       external: true
       name: plane-network
   ```

#### 3.3 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.migrator`:

```bash
# Django Configuration (must match API)
SECRET_KEY=<your-generated-secret-key>
DEBUG=0
DJANGO_SETTINGS_MODULE=plane.settings.production

# Database (must match .env.infra)
POSTGRES_USER=plane
POSTGRES_PASSWORD=<your-generated-postgres-password>
POSTGRES_DB=plane

# Python
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1
```

#### 2.4 **Deploy and Monitor**

1. Click **"Deploy"**
2. Monitor logs - you should see:
   ```
   Operations to perform:
     Apply all migrations: admin, auth, contenttypes, db, sessions...
   Running migrations:
     Applying db.0001_initial... OK
     Applying db.0002_auto... OK
     ... (100+ migrations)
   Migrations completed successfully
   ```
3. Wait for completion (2-5 minutes)

#### 2.5 **Delete Migrator (Important!)**

After migrations complete successfully:
1. **Stop** the plane-migrator application
2. **Delete** the plane-migrator application from Dokploy

**Why delete?** The migrator is a one-time job. The container has `restart: "no"` so it won't restart, but it's good practice to remove it.

**Note:** For future redeployments, if you need to run new migrations, recreate this migrator service, run it once, then delete again.

---

### **Step 3: Create API Backend Application**

#### 7.1 **Create Application**

1. Click **"Create Application"**
2. Name: `plane-api`
3. Type: **Docker Compose**

#### 3.2 **Configure Docker Compose**

1. Upload or paste `deployment/6-services/docker-compose.api.yml`
2. **Important**: Ensure the network configuration is correct:
   ```yaml
   networks:
     plane-network:
       external: true
       name: plane-network
   ```

#### 3.2.1 **Configure Domain in Dokploy**

1. Go to **"Domains"** tab in the plane-api application
2. Add domain: `plane-api.mohdop.com`
3. Enable **HTTPS** (Let's Encrypt)
4. Save

#### 3.3 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.api`. **Critical variables:**

```bash
# Traefik Routing
API_DOMAIN=plane-api.mohdop.com

# Django
SECRET_KEY=<your-generated-secret-key>
DEBUG=0

# Database (must match .env.infra)
POSTGRES_USER=plane
POSTGRES_PASSWORD=<your-generated-postgres-password>
POSTGRES_DB=plane
DATABASE_URL=postgresql://plane:ajMeB9eLtQSBfZS_vz4R1ELZE9n34KL3RzhhoK4EqJg@plane-postgres:5432/plane

# Redis
REDIS_URL=redis://plane-redis:6379/

# RabbitMQ (must match .env.infra)
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=<your-generated-rabbitmq-password>
CELERY_BROKER_URL=amqp://plane:lnI5L_985_Ikx6w6l73D9_XeS9m361SCetuBp_UwjBU@plane-rabbitmq:5672/plane

# URLs
WEB_URL=https://plane.mohdop.com
API_BASE_URL=https://plane-api.mohdop.com
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com

# Storage - Digital Ocean Spaces (S3-compatible)
# Choose ONE: DO Spaces (active), AWS S3, or MinIO (see .env.api for all options)
USE_MINIO=0
AWS_ACCESS_KEY_ID=your-do-spaces-access-key
AWS_SECRET_ACCESS_KEY=your-do-spaces-secret-key
AWS_REGION=nyc3
AWS_S3_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
AWS_S3_BUCKET_NAME=your-space-name

# AI (OpenAI) - Optional, can configure later via god-mode admin panel
OPENAI_API_KEY=your-openai-api-key-here
GPT_ENGINE=gpt-4

# Email - Custom SMTP Server
EMAIL_HOST=mail.mohdop.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=zidane@mohdop.com
EMAIL_HOST_PASSWORD=your-smtp-password
DEFAULT_FROM_EMAIL=zidane@mohdop.com

# Security
ALLOWED_HOSTS=plane-api.mohdop.com,localhost
SESSION_COOKIE_SECURE=1
CSRF_COOKIE_SECURE=1
```

#### 3.4 **Deploy**

1. Click **"Deploy"**
2. Monitor logs for:
   - Database connection success
   - **Skipping migrations** (already done by migrator)
   - Gunicorn server starting on port 8000
3. API should start within 30-60 seconds

**Note:** If you see "Waiting for database migrations to complete..." hanging, it means you skipped Step 2 (Migrator). Go back and run the migrator first.

#### 3.5 **Verify API**

```bash
# Check API is running
docker logs plane-api -f

# Test API endpoint
curl https://plane-api.mohdop.com/api/health/
# Should return: {"status": "ok"}

# Check database migrations
docker exec plane-api python manage.py showmigrations
# All migrations should have [X]
```

---

### **Step 4: Create Worker Application**

#### 7.1 **Create Application**

1. Name: `plane-worker`
2. Type: **Docker Compose**
3. Upload `deployment/6-services/docker-compose.worker.yml`

#### 6.2 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.worker`. **Must match API credentials:**

```bash
# Django & Database (must match API)
SECRET_KEY=<your-generated-secret-key>
POSTGRES_PASSWORD=<your-generated-postgres-password>
RABBITMQ_PASSWORD=<your-generated-rabbitmq-password>

# Storage - Digital Ocean Spaces (must match API)
USE_MINIO=0
AWS_ACCESS_KEY_ID=your-do-spaces-access-key
AWS_SECRET_ACCESS_KEY=your-do-spaces-secret-key
AWS_REGION=nyc3
AWS_S3_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
AWS_S3_BUCKET_NAME=your-space-name

# Email - Custom SMTP Server (for sending notification emails)
EMAIL_HOST=mail.mohdop.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=zidane@mohdop.com
EMAIL_HOST_PASSWORD=your-smtp-password
DEFAULT_FROM_EMAIL=zidane@mohdop.com
```

#### 6.3 **Deploy**

```bash
# Verify worker is consuming tasks
docker logs plane-worker -f

# Should see:
# [tasks] celery@... ready
```

---

### **Step 5: Create Beat Worker Application**

#### 7.1 **Create Application**

1. Name: `plane-beat-worker`
2. Type: **Docker Compose**
3. Upload `deployment/6-services/docker-compose.beat-worker.yml`

#### 6.2 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.beat-worker`:

```bash
SECRET_KEY=<your-generated-secret-key>
POSTGRES_PASSWORD=<your-generated-postgres-password>
RABBITMQ_PASSWORD=<your-generated-rabbitmq-password>
```

#### 6.3 **Deploy**

```bash
# Verify beat worker is running
docker logs plane-beat-worker -f

# Should see periodic heartbeats
```

---

### **Step 6: Create Live Server Application**

#### 7.1 **Create Application**

1. Name: `plane-live`
2. Type: **Docker Compose**
3. Upload `deployment/6-services/docker-compose.live.yml`

#### 6.2 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.live`. **Critical: SECRET_KEY must match API!**

```bash
# Routing
FRONTEND_DOMAIN=plane.mohdop.com

# Authentication (MUST MATCH API!)
SECRET_KEY=<your-generated-secret-key>
LIVE_SERVER_SECRET_KEY=<your-generated-secret-key>

# API (internal Docker network!)
API_BASE_URL=http://plane-api:8000

# URLs
WEB_URL=https://plane.mohdop.com
LIVE_BASE_URL=https://plane.mohdop.com
LIVE_BASE_PATH=/live

# CORS
ALLOWED_ORIGINS=https://plane.mohdop.com

# Redis
REDIS_URL=redis://plane-redis:6379/
```

#### 6.3 **Deploy**

```bash
# Verify live server is running
docker logs plane-live -f

# Test WebSocket endpoint
curl https://plane.mohdop.com/live/health
# Should return success
```

---

### **Step 7: Create Frontend Application**

#### 7.1 **Create Application**

1. Name: `plane-frontend`
2. Type: **Nixpacks** (not Docker Compose!)
3. Repository: Select your git repository or upload codebase

#### 7.2 **Configure Nixpacks**

1. In application settings, go to **"Build"** tab
2. Set **Nixpacks Config Path**: `nixpacks.frontend.toml`
3. The build will:
   - Build all 3 frontend apps (web, admin, space)
   - Bundle them with Nginx
   - Serve on port 3000

#### 7.3 **Set Environment Variables**

Upload all variables from `deployment/6-services/.env.frontend`:

```bash
# API
NEXT_PUBLIC_API_BASE_URL=https://plane-api.mohdop.com
VITE_API_BASE_URL=https://plane-api.mohdop.com

# Web App
NEXT_PUBLIC_WEB_BASE_URL=https://plane.mohdop.com
VITE_WEB_BASE_URL=https://plane.mohdop.com

# Admin App
NEXT_PUBLIC_ADMIN_BASE_URL=https://plane.mohdop.com
VITE_ADMIN_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_ADMIN_BASE_PATH=/god-mode
VITE_ADMIN_BASE_PATH=/god-mode

# Space App
NEXT_PUBLIC_SPACE_BASE_URL=https://plane.mohdop.com
VITE_SPACE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_SPACE_BASE_PATH=/spaces
VITE_SPACE_BASE_PATH=/spaces

# Live Server
NEXT_PUBLIC_LIVE_BASE_URL=https://plane.mohdop.com
VITE_LIVE_BASE_URL=https://plane.mohdop.com
NEXT_PUBLIC_LIVE_BASE_PATH=/live
VITE_LIVE_BASE_PATH=/live

# Build
NODE_ENV=production
PORT=3000
```

#### 7.4 **Configure Traefik Routing**

1. Go to **"Domains"** tab
2. Add domain: `plane.mohdop.com`
3. Enable **HTTPS** (Let's Encrypt)
4. Save

#### 7.5 **Deploy**

1. Click **"Deploy"**
2. Build time: 10-15 minutes (installs dependencies, builds 3 apps)
3. Monitor build logs

```bash
# After deployment, verify
docker logs plane-frontend -f

# Test frontend
curl https://plane.mohdop.com/
# Should return HTML
```

---

## Post-Deployment Verification

### ✅ **Verification Checklist**

#### 1. **All Services Running**

```bash
docker ps | grep plane

# Should show 8 containers:
# - plane-postgres
# - plane-redis
# - plane-rabbitmq
# - plane-api
# - plane-worker
# - plane-beat-worker
# - plane-live
# - plane-frontend (or similar name from Nixpacks)
```

#### 2. **Network Connectivity**

```bash
# Check all services are on plane-network
docker network inspect plane-network

# All containers should be listed
```

#### 3. **Health Checks**

```bash
# API Health
curl https://plane-api.mohdop.com/api/health/
# Expected: {"status": "ok"}

# Frontend
curl -I https://plane.mohdop.com/
# Expected: 200 OK

# Live Server
curl https://plane.mohdop.com/live/health
# Expected: success

# RabbitMQ Management UI (if domain configured)
curl https://rabbitmq.mohdop.com/
# Expected: RabbitMQ Management UI

# Storage Health (Digital Ocean Spaces)
# Check via DO Console: https://cloud.digitalocean.com/spaces
# Or test upload via Plane god-mode after deployment
```

#### 4. **Database Migrations**

```bash
docker exec plane-api python manage.py showmigrations

# All should have [X] checkmark
```

#### 5. **Create Superuser**

```bash
docker exec -it plane-api python manage.py createsuperuser

# Follow prompts to create admin account
```

#### 6. **Test Full Flow**

1. Open browser: https://plane.mohdop.com
2. Sign up for new account
3. Create a workspace
4. Create a project
5. Create an issue
6. Test real-time collaboration (open same issue in 2 tabs)

---

## Troubleshooting

### Common Issues

#### Issue: "Cannot connect to database"

**Check:**
```bash
# Is postgres running?
docker ps | grep postgres

# Can API reach postgres?
docker exec plane-api pg_isready -h plane-postgres -U plane

# Check credentials
docker exec plane-api env | grep POSTGRES
```

#### Issue: "CORS error in browser"

**Check:**
1. `.env.api`: `CORS_ALLOWED_ORIGINS=https://plane.mohdop.com` (no trailing slash!)
2. Restart API: `docker restart plane-api`
3. Clear browser cache

#### Issue: "WebSocket connection failed"

**Check:**
1. Live server is running: `docker ps | grep plane-live`
2. SECRET_KEY matches between API and Live
3. Check browser console for error details

#### Issue: "File upload fails"

**Check:**
1. Verify S3 credentials in `.env.api`:
   ```bash
   docker exec plane-api env | grep AWS
   ```
2. For Digital Ocean Spaces:
   - Verify Space exists in DO Console
   - Check CORS configuration on the Space
   - Verify access key has read/write permissions
3. Test connectivity:
   ```bash
   docker exec plane-api python manage.py shell
   # In shell: test S3 connection
   ```
4. Check API logs for S3 errors:
   ```bash
   docker logs plane-api -f | grep -i s3
   ```

#### Issue: "Emails not sending"

**Check:**
1. Worker is running: `docker ps | grep plane-worker`
2. SMTP credentials in `.env.worker`
3. Worker logs: `docker logs plane-worker -f`

---

## Backup & Maintenance

### Daily Backups

#### 1. **Database Backup**

```bash
# Backup PostgreSQL
docker exec plane-postgres pg_dump -U plane plane > plane-backup-$(date +%Y%m%d).sql

# Restore from backup
cat plane-backup-20250119.sql | docker exec -i plane-postgres psql -U plane plane
```

#### 2. **Storage Backup**

**Digital Ocean Spaces:**
- Snapshots are managed via DO Console
- Enable versioning on your Space for automatic backups
- OR use `rclone` to sync to another location:
```bash
# Install rclone and configure for DO Spaces
rclone sync do-spaces:your-space-name /local/backup/path
```

**If using self-hosted MinIO:**
```bash
# Backup MinIO data volume
docker run --rm -v plane-minio-data:/data -v $(pwd):/backup alpine tar czf /backup/minio-backup-$(date +%Y%m%d).tar.gz /data
```

### Monitoring

#### Check Logs

```bash
# All services
docker-compose -f docker-compose.infra.yml logs -f

# Specific service
docker logs plane-api -f
docker logs plane-worker -f
docker logs plane-live -f
```

#### Resource Usage

```bash
# Container stats
docker stats

# Disk usage
docker system df
```

### Updates

#### Update Plane

1. Pull latest code: `git pull origin main`
2. Rebuild services:
   ```bash
   # Rebuild API
   docker-compose -f docker-compose.api.yml build --no-cache
   docker-compose -f docker-compose.api.yml up -d

   # Rebuild Frontend (in Dokploy: Trigger redeploy)
   ```
3. Run migrations:
   ```bash
   docker exec plane-api python manage.py migrate
   ```

---

## Summary

You've successfully deployed Plane on Dokploy! 🎉

**Your Plane installation:**
- Frontend: https://plane.mohdop.com
- API: https://plane-api.mohdop.com
- Admin: https://plane.mohdop.com/god-mode
- Spaces: https://plane.mohdop.com/spaces
- Live: https://plane.mohdop.com/live (WebSocket)

**Next Steps:**
1. Create your first workspace
2. Invite team members
3. Configure integrations (GitHub, Slack, etc.)
4. Set up automated backups
5. Monitor resource usage

**Need Help?**
- Check logs: `docker logs <service-name>`
- Review environment variables in Dokploy
- Consult API_COMMUNICATION_GUIDE.md for CORS/API issues
- Check SECURITY_CHECKLIST.md for security best practices
