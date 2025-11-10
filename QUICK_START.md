# Plane on Dokploy - Quick Start Guide

Deploy Plane to your VPS in under 30 minutes. ⚡

## Prerequisites Checklist

- [ ] VPS with Dokploy installed ([docs](https://docs.dokploy.com))
- [ ] 4GB+ RAM, 2+ CPU cores, 40GB storage
- [ ] Domain names pointed to server IP:
  - `plane.mohdop.com`
  - `plane-api.mohdop.com`
  - `minio.mohdop.com` (optional)
- [ ] GitHub repo with Plane codebase
- [ ] Dokploy connected to GitHub

## 🚀 Deployment Steps

### Step 1: Prepare Environment Variables (5 min)

```bash
# Clone your Plane repository locally
git clone <your-repo-url>
cd plane

# Copy all environment example files
cp .env.infra.example .env.infra
cp .env.api.example .env.api
cp .env.worker.example .env.worker
cp .env.beat-worker.example .env.beat-worker
cp .env.live.example .env.live
cp .env.frontend.example .env.frontend
```

**Edit each file** and replace:
- All passwords (search for `change-this`)
- `mohdop.com` → your domain
- `SECRET_KEY` → generate with: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`

**⚠️ CRITICAL:** Make sure these credentials match across all files:
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- `SECRET_KEY` (must be same in `.env.api`, `.env.worker`, `.env.beat-worker`)

### Step 2: Commit to GitHub (1 min)

```bash
git add .env.*.example docker-compose.*.yml nixpacks.frontend.toml
git commit -m "Configure Dokploy deployment"
git push origin main
```

### Step 3: Deploy Infrastructure (5 min) ⚠️ FIRST!

**In Dokploy Dashboard:**

1. Click **"Create Application"**
2. **Name:** `plane-infra`
3. **Type:** **Compose** (Docker Compose)
4. **Repository:** Select your GitHub repo
5. **Branch:** `main`
6. **Compose File:** `docker-compose.infra.yml`
7. **Environment Variables:** Copy/paste entire contents of `.env.infra`
8. Click **"Deploy"**

**Wait for all services to be healthy!** Check logs for:
- ✅ PostgreSQL ready for connections
- ✅ Redis ready to accept connections
- ✅ RabbitMQ started
- ✅ MinIO initialized

This creates the `plane-network` that all other services will use.

### Step 4: Deploy API Backend (3 min)

1. Create Application → **Name:** `plane-api`
2. **Type:** Compose
3. **Compose File:** `docker-compose.api.yml`
4. **Environment Variables:** Paste `.env.api` contents
5. **Domains:**
   - Add domain: `plane-api.mohdop.com`
   - Port: `8000`
   - HTTPS: ✅ (automatic Let's Encrypt)
6. Deploy

**Verify:** `curl https://plane-api.mohdop.com/api/health/` should return `{"status": "ok"}`

### Step 5: Deploy Celery Worker (2 min)

1. Create Application → **Name:** `plane-worker`
2. **Type:** Compose
3. **Compose File:** `docker-compose.worker.yml`
4. **Environment Variables:** Paste `.env.worker` contents
5. No domain needed (internal service)
6. Deploy

### Step 6: Deploy Beat Worker (2 min)

1. Create Application → **Name:** `plane-beat-worker`
2. **Type:** Compose
3. **Compose File:** `docker-compose.beat-worker.yml`
4. **Environment Variables:** Paste `.env.beat-worker` contents
5. No domain needed (internal service)
6. Deploy

### Step 7: Deploy Live Server (3 min)

1. Create Application → **Name:** `plane-live`
2. **Type:** Compose
3. **Compose File:** `docker-compose.live.yml`
4. **Environment Variables:** Paste `.env.live` contents
5. **Domains:**
   - Domain: `plane.mohdop.com`
   - Path: `/live` (path-based routing)
   - Port: `3000`
   - HTTPS: ✅
6. Deploy

### Step 8: Deploy Frontend (5 min)

1. Create Application → **Name:** `plane-frontend`
2. **Type:** **Nixpacks** (not Compose!)
3. **Build Path:** `/` (root directory)
4. **Nixpacks Config:** `nixpacks.frontend.toml`
5. **Environment Variables:** Paste `.env.frontend` contents
6. **Domains:**
   - Domain: `plane.mohdop.com`
   - Port: `3000`
   - HTTPS: ✅
7. Deploy (this will take 5-10 minutes to build)

## ✅ Verification (2 min)

```bash
# SSH to your server and check all containers
ssh your-server
docker ps | grep plane

# Should see 9+ containers:
# plane-postgres, plane-redis, plane-rabbitmq, plane-minio
# plane-api, plane-worker, plane-beat-worker, plane-live
# plane-frontend (or Dokploy-generated name)

# Test API
curl https://plane-api.mohdop.com/health/
# Should return: {"status":"ok"}

# Test frontend
curl -I https://plane.mohdop.com/
# Should return: HTTP/2 200

# Check network connectivity
docker network inspect plane-network --format '{{range .Containers}}{{.Name}} {{end}}'
# Should list all plane-* containers
```

## 🎉 Access Your Plane Instance

**Frontend:** https://plane.mohdop.com
**API:** https://plane-api.mohdop.com
**Admin:** https://plane.mohdop.com/god-mode
**MinIO Console:** https://minio.mohdop.com (login with AWS_ACCESS_KEY_ID/SECRET)
**RabbitMQ Console:** https://rabbitmq.mohdop.com (login with RABBITMQ_USER/PASSWORD)

## 🔧 Create First Admin User

```bash
# SSH to server
ssh your-server

# Create superuser
docker exec -it plane-api python manage.py createsuperuser

# Follow prompts:
# - Email: admin@mohdop.com
# - Password: (create secure password)
# - Confirm password
```

Now login at https://plane.mohdop.com 🚀

## 🔄 Enable Auto-Deploy

Dokploy automatically redeploys when you push to GitHub!

To test:
```bash
# Make a change
echo "# Dokploy deployed!" >> README.md
git add README.md
git commit -m "Test auto-deploy"
git push origin main

# Watch Dokploy dashboard - it will rebuild automatically!
```

## 📊 Monitor Your Deployment

**In Dokploy Dashboard:**
- Click each app to see:
  - Real-time logs
  - Resource usage (CPU, memory)
  - Deployment history
  - Environment variables

**Via Command Line:**
```bash
# View all logs
docker logs -f plane-api
docker logs -f plane-worker
docker logs -f plane-beat-worker
docker logs -f plane-live

# View all containers
docker ps | grep plane

# Check resource usage
docker stats --no-stream | grep plane
```

## ⚙️ Common Configuration Changes

### Scale API Workers

Edit `.env.api` in Dokploy UI:
```bash
GUNICORN_WORKERS=4  # Increase from 2 to 4
```
Then redeploy the `plane-api` app.

### Configure Email (SMTP)

Edit `.env.api` and `.env.worker`:
```bash
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=noreply@mohdop.com
```
Redeploy both apps.

### Enable OpenAI Features

Edit `.env.api` and `.env.worker`:
```bash
OPENAI_API_KEY=sk-your-api-key-here
GPT_ENGINE=gpt-4
```
Redeploy both apps.

## 🚨 Troubleshooting

### Service can't reach database/redis

**Problem:** Logs show "connection refused" or "host not found"

**Solution:**
```bash
# Check infrastructure is running
docker ps | grep plane-postgres
docker ps | grep plane-redis

# Verify network exists
docker network ls | grep plane-network

# Check service is on network
docker network inspect plane-network | grep plane-api

# If not on network, restart the app in Dokploy UI
```

### API returns 502

**Problem:** Frontend shows "Bad Gateway"

**Solution:**
```bash
# Check API logs
docker logs plane-api --tail=100

# Common issues:
# - Database migration not run
# - Wrong database credentials
# - Service not started

# Try redeploying plane-api in Dokploy
```

### Frontend build fails

**Problem:** Nixpacks build errors

**Solution:**
```bash
# Check build logs in Dokploy
# Common issues:
# - Missing environment variables
# - Wrong Node.js version (should be 22)
# - Incorrect build path

# Verify nixpacks.frontend.toml is correct:
cat nixpacks.frontend.toml

# Should have:
# [phases.setup]
# nixPkgs = ["nodejs_22", "pnpm"]
```

### SSL certificate not working

**Problem:** HTTPS shows certificate error

**Solution:**
- Wait 5-10 minutes (Let's Encrypt takes time)
- Verify DNS is pointing to your server: `nslookup plane-api.mohdop.com`
- Check Traefik logs in Dokploy
- Ensure ports 80 and 443 are open in firewall

### Live server WebSocket issues

**Problem:** Real-time features not working

**Solution:**
```bash
# Check live server logs
docker logs plane-live --tail=50

# Verify CORS configuration in .env.live
# ALLOWED_ORIGINS must match frontend domain exactly
ALLOWED_ORIGINS=https://plane.mohdop.com

# Check Redis connection
docker exec plane-live redis-cli -h plane-redis ping
# Should return: PONG
```

## 📈 Performance Tuning

### For Production Use

1. **Scale workers:**
   ```bash
   # In .env.api
   GUNICORN_WORKERS=4  # 2-4 × CPU cores
   ```

2. **Enable caching:**
   - Redis is already configured ✅
   - No additional setup needed

3. **Configure backups:**
   ```bash
   # Set up daily backups (see DOKPLOY_DEPLOYMENT.md)
   ./scripts/backup-data.sh
   ```

4. **Monitor resources:**
   ```bash
   docker stats
   ```
   - Aim for <80% CPU usage
   - Aim for <70% memory usage
   - Scale VPS if needed

5. **Consider external services:**
   - Managed PostgreSQL (better backups, scaling)
   - Managed Redis (better performance)
   - S3 storage (unlimited space)
   - See `DOKPLOY_DEPLOYMENT.md` for migration guides

## 🎓 Next Steps

- [ ] Set up email configuration
- [ ] Configure OAuth providers (Google, GitHub, etc.)
- [ ] Enable AI features (OpenAI)
- [ ] Set up automated backups
- [ ] Configure monitoring/alerting
- [ ] Read full `DOKPLOY_DEPLOYMENT.md` for advanced features
- [ ] Join [Plane community](https://discord.gg/plane) for support

## 📚 Documentation Links

- **Full Deployment Guide:** [DOKPLOY_DEPLOYMENT.md](./DOKPLOY_DEPLOYMENT.md)
- **Environment Variables:** See `.env.*.example` files
- **Migration Guides:** [DOKPLOY_DEPLOYMENT.md - Migration Section](./DOKPLOY_DEPLOYMENT.md#migration-to-external-services)
- **Plane Docs:** https://docs.plane.so
- **Dokploy Docs:** https://docs.dokploy.com

---

**Total Time:** ~30 minutes
**Difficulty:** Intermediate
**Result:** Production-ready Plane instance with auto-deploy! 🎉
