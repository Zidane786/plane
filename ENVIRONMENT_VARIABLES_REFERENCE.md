# Plane Environment Variables - Complete Reference

Comprehensive guide to all environment variables used across Plane services.

## Table of Contents
1. [Overview](#overview)
2. [Infrastructure (.env.infra)](#infrastructure-envinfra)
3. [API Backend (.env.api)](#api-backend-envapi)
4. [Frontend Apps (.env.frontend)](#frontend-apps-envfrontend)
5. [Live Server (.env.live)](#live-server-envlive)
6. [Worker (.env.worker)](#worker-envworker)
7. [Beat Worker (.env.beat-worker)](#beat-worker-envbeat-worker)
8. [Variable Cross-Reference](#variable-cross-reference)
9. [Troubleshooting](#troubleshooting)

---

## Overview

### File Structure

```
plane/
├── .env.infra           # Infrastructure services (Postgres, Redis, RabbitMQ, MinIO)
├── .env.api             # API backend (Django)
├── .env.frontend        # Frontend apps (Web, Admin, Space)
├── .env.live            # Live server (WebSocket)
├── .env.worker          # Celery worker
└── .env.beat-worker     # Celery beat scheduler
```

### Variable Categories

| Category | Description | Used In |
|----------|-------------|---------|
| **Database** | PostgreSQL connection | Infrastructure, API, Worker, Beat |
| **Cache** | Redis configuration | Infrastructure, API, Worker, Live |
| **Queue** | RabbitMQ + Celery | Infrastructure, API, Worker, Beat |
| **Storage** | MinIO/S3 | Infrastructure, API, Worker |
| **URLs** | Application domains | API, Frontend, Live, Worker |
| **Authentication** | JWT secrets | API, Live, Worker, Beat |
| **Security** | CORS, cookies, HTTPS | API, Frontend, Live |
| **Features** | AI, email, analytics | API, Worker |

### Legend

- 🔴 **REQUIRED** - Must be set for application to function
- 🟡 **IMPORTANT** - Should be set for production use
- 🟢 **OPTIONAL** - Can be omitted (falls back to default)
- 🔵 **CRITICAL** - Sensitive credential (NEVER commit to git!)

---

## Infrastructure (.env.infra)

Environment variables for infrastructure services deployed in `docker-compose.infra.yml`.

### PostgreSQL Database

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `POSTGRES_USER` | 🔴 | `plane` | PostgreSQL database username |
| `POSTGRES_PASSWORD` | 🔴🔵 | *(generated)* | PostgreSQL database password - **MUST MATCH** API/Worker |
| `POSTGRES_DB` | 🔴 | `plane` | PostgreSQL database name |
| `PGDATA` | 🟢 | `/var/lib/postgresql/data` | PostgreSQL data directory path |
| `POSTGRES_HOST` | 🟢 | `plane-postgres` | PostgreSQL hostname (Docker service name) |
| `POSTGRES_PORT` | 🟢 | `5432` | PostgreSQL port number |
| `POSTGRES_MAX_CONNECTIONS` | 🟢 | `1000` | Maximum concurrent database connections |

**Example:**
```bash
POSTGRES_USER=plane
POSTGRES_PASSWORD=ajMeB9eLtQSBfZS_vz4R1ELZE9n34KL3RzhhoK4EqJg
POSTGRES_DB=plane
POSTGRES_MAX_CONNECTIONS=1000
```

### Redis Cache

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `REDIS_HOST` | 🟢 | `plane-redis` | Redis hostname (Docker service name) |
| `REDIS_PORT` | 🟢 | `6379` | Redis port number |
| `REDIS_PASSWORD` | 🟢🔵 | *(none)* | Redis password (optional but recommended) |

**Example:**
```bash
REDIS_HOST=plane-redis
REDIS_PORT=6379
# REDIS_PASSWORD=strong-redis-password  # Uncomment to enable auth
```

### RabbitMQ Message Broker

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RABBITMQ_USER` | 🔴 | `plane` | RabbitMQ username |
| `RABBITMQ_PASSWORD` | 🔴🔵 | *(generated)* | RabbitMQ password - **MUST MATCH** API/Worker |
| `RABBITMQ_VHOST` | 🟢 | `plane` | RabbitMQ virtual host |
| `RABBITMQ_HOST` | 🟢 | `plane-rabbitmq` | RabbitMQ hostname (Docker service name) |
| `RABBITMQ_PORT` | 🟢 | `5672` | RabbitMQ AMQP port |
| `RABBITMQ_MANAGEMENT_PORT` | 🟢 | `15672` | RabbitMQ management UI port |

**Example:**
```bash
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=lnI5L_985_Ikx6w6l73D9_XeS9m361SCetuBp_UwjBU
RABBITMQ_VHOST=plane
```

### MinIO S3-Compatible Storage

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | 🔴🔵 | *(generated)* | MinIO access key - **MUST MATCH** API/Worker |
| `AWS_SECRET_ACCESS_KEY` | 🔴🔵 | *(generated)* | MinIO secret key - **MUST MATCH** API/Worker |
| `AWS_REGION` | 🟢 | `us-east-1` | AWS region (for S3 compatibility) |
| `AWS_S3_BUCKET_NAME` | 🔴 | `uploads` | S3 bucket name for file storage |
| `MINIO_HOST` | 🟢 | `plane-minio` | MinIO hostname (Docker service name) |
| `MINIO_PORT` | 🟢 | `9000` | MinIO API port |
| `MINIO_CONSOLE_PORT` | 🟢 | `9001` | MinIO console (web UI) port |

**Example:**
```bash
AWS_ACCESS_KEY_ID=fHr_yxVxIsgYxs479hf_Tzf74cM
AWS_SECRET_ACCESS_KEY=Cg28nyvS0HVe6Ph7ovUmx2xBPQi3NrW56oOVQcbw5Y27RsTHI81tTw
AWS_REGION=us-east-1
AWS_S3_BUCKET_NAME=uploads
```

### Docker Volumes

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `POSTGRES_VOLUME` | 🟢 | `plane-postgres-data` | PostgreSQL data volume name |
| `REDIS_VOLUME` | 🟢 | `plane-redis-data` | Redis data volume name |
| `RABBITMQ_VOLUME` | 🟢 | `plane-rabbitmq-data` | RabbitMQ data volume name |
| `MINIO_VOLUME` | 🟢 | `plane-minio-data` | MinIO data volume name |

### Networking

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PLANE_NETWORK` | 🟢 | `plane-network` | Docker network name for all services |

---

## API Backend (.env.api)

Environment variables for Django API backend deployed in `docker-compose.api.yml`.

### Traefik Routing (Dokploy)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `API_DOMAIN` | 🔴 | `plane-api.mohdop.com` | API domain for Traefik routing (used in labels) |

### Django Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SECRET_KEY` | 🔴🔵 | *(generated)* | Django secret key (50+ chars) - **MUST MATCH** Worker/Beat/Live |
| `DEBUG` | 🔴 | `0` | Debug mode (0=production, 1=debug) - **MUST be 0 in production!** |
| `DJANGO_SETTINGS_MODULE` | 🔴 | `plane.settings.production` | Django settings module to use |

**Example:**
```bash
SECRET_KEY=LtBkbgDqp-ZUlhkBjoO3kH6ftJpj6TcXR_w5HhKVsezQ_qK52pxAAUXokyJlwOUUh_U
DEBUG=0
DJANGO_SETTINGS_MODULE=plane.settings.production
```

### Database Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `POSTGRES_USER` | 🔴 | `plane` | Must match `.env.infra` |
| `POSTGRES_PASSWORD` | 🔴🔵 | *(from infra)* | Must match `.env.infra` |
| `POSTGRES_DB` | 🔴 | `plane` | Must match `.env.infra` |
| `PGUSER` | 🔴 | `${POSTGRES_USER}` | PostgreSQL user (referenced from POSTGRES_USER) |
| `PGPASSWORD` | 🔴 | `${POSTGRES_PASSWORD}` | PostgreSQL password (referenced) |
| `PGHOST` | 🔴 | `plane-postgres` | PostgreSQL host (Docker service name) |
| `PGDATABASE` | 🔴 | `${POSTGRES_DB}` | PostgreSQL database (referenced) |
| `DATABASE_URL` | 🔴 | *(constructed)* | Full database connection string |

**Example:**
```bash
POSTGRES_USER=plane
POSTGRES_PASSWORD=ajMeB9eLtQSBfZS_vz4R1ELZE9n34KL3RzhhoK4EqJg
POSTGRES_DB=plane
PGHOST=plane-postgres
DATABASE_URL=postgresql://plane:ajMeB9eLtQSBfZS_vz4R1ELZE9n34KL3RzhhoK4EqJg@plane-postgres:5432/plane
```

### Redis Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `REDIS_HOST` | 🔴 | `plane-redis` | Redis host (Docker service name) |
| `REDIS_PORT` | 🔴 | `6379` | Redis port |
| `REDIS_URL` | 🔴 | `redis://plane-redis:6379/` | Full Redis connection string |

### RabbitMQ & Celery Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RABBITMQ_USER` | 🔴 | `plane` | Must match `.env.infra` |
| `RABBITMQ_PASSWORD` | 🔴🔵 | *(from infra)* | Must match `.env.infra` |
| `RABBITMQ_VHOST` | 🔴 | `plane` | Must match `.env.infra` |
| `RABBITMQ_HOST` | 🔴 | `plane-rabbitmq` | RabbitMQ host (Docker service name) |
| `RABBITMQ_PORT` | 🔴 | `5672` | RabbitMQ AMQP port |
| `CELERY_BROKER_URL` | 🔴 | *(constructed)* | Full Celery broker connection string |

**Example:**
```bash
RABBITMQ_USER=plane
RABBITMQ_PASSWORD=lnI5L_985_Ikx6w6l73D9_XeS9m361SCetuBp_UwjBU
RABBITMQ_VHOST=plane
RABBITMQ_HOST=plane-rabbitmq
CELERY_BROKER_URL=amqp://plane:lnI5L_985_Ikx6w6l73D9_XeS9m361SCetuBp_UwjBU@plane-rabbitmq:5672/plane
```

### Application URLs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `WEB_URL` | 🔴 | `https://plane.mohdop.com` | Frontend web app URL |
| `API_BASE_URL` | 🔴 | `https://plane-api.mohdop.com` | API backend URL (external) |
| `ADMIN_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Admin app base URL |
| `ADMIN_BASE_PATH` | 🟢 | `/god-mode` | Admin app path |
| `SPACE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Space app base URL |
| `SPACE_BASE_PATH` | 🟢 | `/spaces` | Space app path |
| `LIVE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Live server base URL |
| `LIVE_BASE_PATH` | 🟢 | `/live` | Live server path |

### CORS Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CORS_ALLOWED_ORIGINS` | 🔴 | `https://plane.mohdop.com` | Allowed origins for CORS (comma-separated, NO trailing slash) |

**Example:**
```bash
# Single origin
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com

# Multiple origins
CORS_ALLOWED_ORIGINS=https://plane.mohdop.com,https://app.example.com
```

### File Storage (MinIO/S3)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `USE_MINIO` | 🔴 | `1` | Use MinIO (1) or AWS S3 (0) |
| `AWS_ACCESS_KEY_ID` | 🔴🔵 | *(from infra)* | Must match `.env.infra` |
| `AWS_SECRET_ACCESS_KEY` | 🔴🔵 | *(from infra)* | Must match `.env.infra` |
| `AWS_REGION` | 🔴 | `us-east-1` | Must match `.env.infra` |
| `AWS_S3_ENDPOINT_URL` | 🔴 | `http://plane-minio:9000` | MinIO endpoint (internal Docker URL) |
| `AWS_S3_BUCKET_NAME` | 🔴 | `uploads` | Must match `.env.infra` |
| `FILE_SIZE_LIMIT` | 🟢 | `5242880` | Max file upload size in bytes (5MB default) |
| `MINIO_ENDPOINT_SSL` | 🟢 | `0` | Use SSL for MinIO endpoint (0=HTTP, 1=HTTPS) |

### Gunicorn Web Server

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `GUNICORN_WORKERS` | 🟡 | `2` | Number of Gunicorn workers (recommended: 2-4 × CPU cores) |

### Security Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ALLOWED_HOSTS` | 🔴 | `plane-api.mohdop.com,localhost` | Django allowed hosts (comma-separated) |
| `SESSION_COOKIE_SECURE` | 🔴 | `1` | Require HTTPS for session cookies (1=yes, 0=no) |
| `CSRF_COOKIE_SECURE` | 🔴 | `1` | Require HTTPS for CSRF cookies (1=yes, 0=no) |

### Email Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `EMAIL_BACKEND` | 🟡 | `django.core.mail.backends.smtp.EmailBackend` | Email backend class |
| `EMAIL_HOST` | 🟡 | `smtp.gmail.com` | SMTP server hostname |
| `EMAIL_PORT` | 🟡 | `587` | SMTP server port (587=TLS, 465=SSL) |
| `EMAIL_USE_TLS` | 🟡 | `1` | Use TLS encryption (1=yes, 0=no) |
| `EMAIL_HOST_USER` | 🟡🔵 | *(your email)* | SMTP username/email address |
| `EMAIL_HOST_PASSWORD` | 🟡🔵 | *(app password)* | SMTP password (use app-specific password for Gmail) |
| `DEFAULT_FROM_EMAIL` | 🟡 | `noreply@mohdop.com` | Default "From" email address |

**Example (Gmail):**
```bash
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-16-char-app-password
DEFAULT_FROM_EMAIL=noreply@mohdop.com
```

### AI Integration (OpenAI)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `OPENAI_API_KEY` | 🟡🔵 | *(your key)* | OpenAI API key for AI features (get from platform.openai.com) |
| `GPT_ENGINE` | 🟡 | `gpt-4` | GPT model to use (gpt-3.5-turbo, gpt-4, gpt-4-turbo, gpt-4o) |

**Example:**
```bash
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GPT_ENGINE=gpt-4
```

### Analytics & Monitoring

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SCOUT_MONITOR` | 🟢 | `0` | Enable Scout APM monitoring (0=disabled, 1=enabled) |
| `SCOUT_KEY` | 🟢🔵 | *(empty)* | Scout APM key |
| `SCOUT_NAME` | 🟢 | `Plane-API` | Scout application name |
| `ANALYTICS_BASE_API` | 🟢 | *(empty)* | Analytics API endpoint |
| `SENTRY_DSN` | 🟢🔵 | *(empty)* | Sentry error tracking DSN |
| `SENTRY_ENVIRONMENT` | 🟢 | `production` | Sentry environment name |

### Feature Flags

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ENABLE_SIGNUP` | 🟢 | `1` | Allow user self-registration (1=yes, 0=no) |
| `ENABLE_EMAIL_PASSWORD` | 🟢 | `1` | Allow email/password authentication (1=yes, 0=no) |
| `ENABLE_MAGIC_LINK_LOGIN` | 🟢 | `0` | Allow magic link authentication (1=yes, 0=no) |

### Rate Limiting

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `API_KEY_RATE_LIMIT` | 🟢 | `60/minute` | API rate limit (requests per time period) |

### Data Retention

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `HARD_DELETE_AFTER_DAYS` | 🟢 | `60` | Days before soft-deleted items are permanently deleted |

### Third-Party Integrations

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `LICENSE_ENGINE_BASE_URL` | 🟢 | *(empty)* | License engine URL (for enterprise features) |
| `INSTANCE_KEY` | 🟢 | *(empty)* | Instance key for telemetry |
| `UNSPLASH_ACCESS_KEY` | 🟢🔵 | *(empty)* | Unsplash API key for image features |

### Python Environment

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PORT` | 🔴 | `8000` | Port for Gunicorn server |
| `PYTHONUNBUFFERED` | 🟢 | `1` | Disable Python output buffering (better logging) |
| `PYTHONDONTWRITEBYTECODE` | 🟢 | `1` | Don't create .pyc files |

---

## Frontend Apps (.env.frontend)

Environment variables for frontend applications (Web, Admin, Space) built with Nixpacks.

**Note**: Frontend env vars are **build-time** variables embedded into JavaScript bundles.

### API Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_API_BASE_URL` | 🔴 | `https://plane-api.mohdop.com` | API endpoint for React Router apps |
| `VITE_API_BASE_URL` | 🔴 | `https://plane-api.mohdop.com` | API endpoint for Vite apps |

### Web App Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_WEB_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Web app base URL |
| `VITE_WEB_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Web app base URL (Vite) |

### Admin App Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_ADMIN_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Admin app base URL |
| `VITE_ADMIN_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Admin app base URL (Vite) |
| `NEXT_PUBLIC_ADMIN_BASE_PATH` | 🔴 | `/god-mode` | Admin app path |
| `VITE_ADMIN_BASE_PATH` | 🔴 | `/god-mode` | Admin app path (Vite) |

### Space App Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_SPACE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Space app base URL |
| `VITE_SPACE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Space app base URL (Vite) |
| `NEXT_PUBLIC_SPACE_BASE_PATH` | 🔴 | `/spaces` | Space app path |
| `VITE_SPACE_BASE_PATH` | 🔴 | `/spaces` | Space app path (Vite) |

### Live Server Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_LIVE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Live server base URL |
| `VITE_LIVE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | Live server base URL (Vite) |
| `NEXT_PUBLIC_LIVE_BASE_PATH` | 🔴 | `/live` | Live server path |
| `VITE_LIVE_BASE_PATH` | 🔴 | `/live` | Live server path (Vite) |

### Build Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NODE_ENV` | 🔴 | `production` | Node environment (production/development) |
| `PORT` | 🔴 | `3000` | Port for Nginx server |

### Feature Flags

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_ENABLE_SENTRY` | 🟢 | `0` | Enable Sentry error tracking (0=disabled, 1=enabled) |
| `VITE_ENABLE_SENTRY` | 🟢 | `0` | Enable Sentry error tracking (Vite) |
| `NEXT_PUBLIC_ENABLE_SESSION_RECORDER` | 🟢 | `0` | Enable session recording (0=disabled, 1=enabled) |
| `VITE_ENABLE_SESSION_RECORDER` | 🟢 | `0` | Enable session recording (Vite) |

### Analytics

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_GA_TRACKING_ID` | 🟢 | *(empty)* | Google Analytics tracking ID |
| `VITE_GA_TRACKING_ID` | 🟢 | *(empty)* | Google Analytics tracking ID (Vite) |
| `NEXT_PUBLIC_POSTHOG_KEY` | 🟢🔵 | *(empty)* | PostHog analytics key |
| `VITE_POSTHOG_KEY` | 🟢🔵 | *(empty)* | PostHog analytics key (Vite) |
| `NEXT_PUBLIC_POSTHOG_HOST` | 🟢 | *(empty)* | PostHog host URL |
| `VITE_POSTHOG_HOST` | 🟢 | *(empty)* | PostHog host URL (Vite) |

### Error Monitoring

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_SENTRY_DSN` | 🟢🔵 | *(empty)* | Sentry DSN for error tracking |
| `VITE_SENTRY_DSN` | 🟢🔵 | *(empty)* | Sentry DSN (Vite) |
| `NEXT_PUBLIC_SENTRY_ENVIRONMENT` | 🟢 | `production` | Sentry environment name |
| `VITE_SENTRY_ENVIRONMENT` | 🟢 | `production` | Sentry environment name (Vite) |

### Deployment Platform

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `NEXT_PUBLIC_DEPLOY_WITH` | 🟢 | `DOKPLOY` | Deployment platform identifier |
| `VITE_DEPLOY_WITH` | 🟢 | `DOKPLOY` | Deployment platform identifier (Vite) |

---

## Live Server (.env.live)

Environment variables for real-time collaboration WebSocket server.

### Traefik Routing

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `FRONTEND_DOMAIN` | 🔴 | `plane.mohdop.com` | Frontend domain for path-based routing (/live) |

### Server Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PORT` | 🔴 | `3000` | WebSocket server port |
| `NODE_ENV` | 🔴 | `production` | Node environment |

### Base URLs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `API_BASE_URL` | 🔴 | `http://plane-api:8000` | **Internal** API URL for JWT validation (Docker network) |
| `WEB_BASE_URL` | 🔴 | `https://plane.mohdop.com` | **External** frontend URL (for CORS) |
| `LIVE_BASE_URL` | 🔴 | `https://plane.mohdop.com` | **External** live server URL |
| `LIVE_BASE_PATH` | 🔴 | `/live` | Live server path |

### Authentication

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `LIVE_SERVER_SECRET_KEY` | 🔴🔵 | *(from API)* | **CRITICAL: MUST match API SECRET_KEY exactly!** |

### Redis Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `REDIS_HOST` | 🔴 | `plane-redis` | Redis host (Docker service name) |
| `REDIS_PORT` | 🔴 | `6379` | Redis port |
| `REDIS_URL` | 🔴 | `redis://plane-redis:6379/` | Full Redis connection string |

### CORS Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ALLOWED_ORIGINS` | 🔴 | `https://plane.mohdop.com` | Allowed origins for WebSocket connections (comma-separated) |

### WebSocket Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `WS_HEARTBEAT_INTERVAL` | 🟢 | `30000` | WebSocket heartbeat interval in milliseconds |
| `WS_HEARTBEAT_TIMEOUT` | 🟢 | `90000` | WebSocket heartbeat timeout in milliseconds |
| `MAX_CONNECTIONS_PER_ROOM` | 🟢 | `100` | Maximum concurrent connections per room |

### Collaboration Engine

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `GC_INTERVAL` | 🟢 | `300000` | Garbage collection interval in milliseconds (5 minutes) |
| `PERSIST_INTERVAL` | 🟢 | `10000` | State persistence interval in milliseconds (10 seconds) |

### Monitoring

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SENTRY_DSN` | 🟢🔵 | *(empty)* | Sentry error tracking DSN |
| `SENTRY_ENVIRONMENT` | 🟢 | `production` | Sentry environment name |
| `DEBUG` | 🟢 | `0` | Debug mode (0=production, 1=debug) |

### Performance Tuning

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `MAX_PAYLOAD_SIZE` | 🟢 | `10485760` | Maximum WebSocket payload size in bytes (10MB) |
| `CONNECTION_TIMEOUT` | 🟢 | `30000` | Connection timeout in milliseconds |

---

## Worker (.env.worker)

Environment variables for Celery background worker.

**Note**: Worker uses same Django codebase as API, so many variables are identical.

### Django Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SECRET_KEY` | 🔴🔵 | *(from API)* | **MUST match `.env.api`** |
| `DEBUG` | 🔴 | `0` | Debug mode (0=production, 1=debug) |
| `DJANGO_SETTINGS_MODULE` | 🔴 | `plane.settings.production` | Django settings module |

### Database Configuration

All database variables **MUST match `.env.api`** and `.env.infra`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `POSTGRES_USER` | 🔴 | `plane` | Must match infra/API |
| `POSTGRES_PASSWORD` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `POSTGRES_DB` | 🔴 | `plane` | Must match infra/API |
| `PGUSER` | 🔴 | `${POSTGRES_USER}` | Referenced from POSTGRES_USER |
| `PGPASSWORD` | 🔴 | `${POSTGRES_PASSWORD}` | Referenced |
| `PGHOST` | 🔴 | `plane-postgres` | Docker service name |
| `PGDATABASE` | 🔴 | `${POSTGRES_DB}` | Referenced |
| `DATABASE_URL` | 🔴 | *(constructed)* | Full database connection string |

### Redis Configuration

All Redis variables **MUST match `.env.api`**:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `REDIS_HOST` | 🔴 | `plane-redis` | Must match API |
| `REDIS_PORT` | 🔴 | `6379` | Must match API |
| `REDIS_URL` | 🔴 | `redis://plane-redis:6379/` | Must match API |

### RabbitMQ & Celery Configuration

All RabbitMQ variables **MUST match `.env.api`** and `.env.infra`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RABBITMQ_USER` | 🔴 | `plane` | Must match infra/API |
| `RABBITMQ_PASSWORD` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `RABBITMQ_VHOST` | 🔴 | `plane` | Must match infra/API |
| `RABBITMQ_HOST` | 🔴 | `plane-rabbitmq` | Must match API |
| `RABBITMQ_PORT` | 🔴 | `5672` | Must match API |
| `CELERY_BROKER_URL` | 🔴 | *(constructed)* | Must match API |

### File Storage

All storage variables **MUST match `.env.api`** and `.env.infra`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `USE_MINIO` | 🔴 | `1` | Must match API |
| `AWS_ACCESS_KEY_ID` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `AWS_SECRET_ACCESS_KEY` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `AWS_REGION` | 🔴 | `us-east-1` | Must match infra/API |
| `AWS_S3_ENDPOINT_URL` | 🔴 | `http://plane-minio:9000` | Must match API |
| `AWS_S3_BUCKET_NAME` | 🔴 | `uploads` | Must match infra/API |
| `MINIO_ENDPOINT_SSL` | 🟢 | `0` | Must match API |

### Email Configuration

**Required for worker to send emails**:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `EMAIL_BACKEND` | 🟡 | `django.core.mail.backends.smtp.EmailBackend` | Same as API |
| `EMAIL_HOST` | 🟡 | `smtp.gmail.com` | Same as API |
| `EMAIL_PORT` | 🟡 | `587` | Same as API |
| `EMAIL_USE_TLS` | 🟡 | `1` | Same as API |
| `EMAIL_HOST_USER` | 🟡🔵 | *(your email)* | Same as API |
| `EMAIL_HOST_PASSWORD` | 🟡🔵 | *(app password)* | Same as API |
| `DEFAULT_FROM_EMAIL` | 🟡 | `noreply@mohdop.com` | Same as API |

### Application URLs

**Required for generating links in emails**:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `WEB_URL` | 🔴 | `https://plane.mohdop.com` | Same as API |
| `API_BASE_URL` | 🔴 | `https://plane-api.mohdop.com` | Same as API |

### AI Integration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `OPENAI_API_KEY` | 🟡🔵 | *(your key)* | Same as API (if using AI features in background tasks) |
| `GPT_ENGINE` | 🟡 | `gpt-4` | Same as API |

### Monitoring

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SENTRY_DSN` | 🟢🔵 | *(empty)* | Same as API |
| `SENTRY_ENVIRONMENT` | 🟢 | `production` | Same as API |

### Python Environment

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PYTHONUNBUFFERED` | 🟢 | `1` | Disable output buffering |
| `PYTHONDONTWRITEBYTECODE` | 🟢 | `1` | Don't create .pyc files |

---

## Beat Worker (.env.beat-worker)

Environment variables for Celery Beat scheduler (scheduled tasks).

**Note**: Simpler than worker - doesn't need email or storage config.

### Django Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SECRET_KEY` | 🔴🔵 | *(from API)* | **MUST match `.env.api`** |
| `DEBUG` | 🔴 | `0` | Debug mode (0=production, 1=debug) |
| `DJANGO_SETTINGS_MODULE` | 🔴 | `plane.settings.production` | Django settings module |

### Database Configuration

All database variables **MUST match `.env.api`**:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `POSTGRES_USER` | 🔴 | `plane` | Must match infra/API |
| `POSTGRES_PASSWORD` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `POSTGRES_DB` | 🔴 | `plane` | Must match infra/API |
| `PGUSER` | 🔴 | `${POSTGRES_USER}` | Referenced |
| `PGPASSWORD` | 🔴 | `${POSTGRES_PASSWORD}` | Referenced |
| `PGHOST` | 🔴 | `plane-postgres` | Docker service name |
| `PGDATABASE` | 🔴 | `${POSTGRES_DB}` | Referenced |
| `DATABASE_URL` | 🔴 | *(constructed)* | Full database connection string |

### Redis Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `REDIS_HOST` | 🔴 | `plane-redis` | Must match API |
| `REDIS_PORT` | 🔴 | `6379` | Must match API |
| `REDIS_URL` | 🔴 | `redis://plane-redis:6379/` | Must match API |

### RabbitMQ & Celery Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RABBITMQ_USER` | 🔴 | `plane` | Must match infra/API |
| `RABBITMQ_PASSWORD` | 🔴🔵 | *(from infra)* | Must match infra/API |
| `RABBITMQ_VHOST` | 🔴 | `plane` | Must match infra/API |
| `RABBITMQ_HOST` | 🔴 | `plane-rabbitmq` | Must match API |
| `RABBITMQ_PORT` | 🔴 | `5672` | Must match API |
| `CELERY_BROKER_URL` | 🔴 | *(constructed)* | Must match API |

### Python Environment

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `PYTHONUNBUFFERED` | 🟢 | `1` | Disable output buffering |
| `PYTHONDONTWRITEBYTECODE` | 🟢 | `1` | Don't create .pyc files |

---

## Variable Cross-Reference

### Critical Variables That MUST Match

#### 1. **SECRET_KEY**
**Must be IDENTICAL in:**
- `.env.api` → `SECRET_KEY`
- `.env.worker` → `SECRET_KEY`
- `.env.beat-worker` → `SECRET_KEY`
- `.env.live` → `LIVE_SERVER_SECRET_KEY`

**Why**: JWT token validation requires same secret key across all services.

#### 2. **PostgreSQL Credentials**
**Must be IDENTICAL in:**
- `.env.infra` → `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `.env.api` → Same variables
- `.env.worker` → Same variables
- `.env.beat-worker` → Same variables

**Why**: All services connect to same database.

#### 3. **RabbitMQ Credentials**
**Must be IDENTICAL in:**
- `.env.infra` → `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `RABBITMQ_VHOST`
- `.env.api` → Same variables
- `.env.worker` → Same variables
- `.env.beat-worker` → Same variables

**Why**: Celery tasks require same message broker connection.

#### 4. **MinIO/S3 Credentials**
**Must be IDENTICAL in:**
- `.env.infra` → `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET_NAME`
- `.env.api` → Same variables
- `.env.worker` → Same variables

**Why**: File storage accessed by API and worker.

#### 5. **CORS Origins**
**Must be CONSISTENT:**
- `.env.api` → `CORS_ALLOWED_ORIGINS=https://plane.mohdop.com`
- `.env.live` → `ALLOWED_ORIGINS=https://plane.mohdop.com`
- `.env.frontend` → `VITE_API_BASE_URL=https://plane-api.mohdop.com`

**Why**: Frontend must be allowed to make API requests.

---

## Troubleshooting

### Common Issues

#### Issue: "CORS policy blocked"

**Check:**
```bash
# Verify CORS origin in API
grep CORS_ALLOWED_ORIGINS .env.api

# Must match frontend domain (NO trailing slash!)
# Correct: https://plane.mohdop.com
# Wrong: https://plane.mohdop.com/
```

#### Issue: "JWT token invalid" (Live Server)

**Check:**
```bash
# Verify SECRET_KEY matches
grep SECRET_KEY .env.api
grep LIVE_SERVER_SECRET_KEY .env.live

# Both should output the same value
```

#### Issue: "Database connection failed"

**Check:**
```bash
# Verify credentials match across files
grep POSTGRES_PASSWORD .env.infra .env.api .env.worker .env.beat-worker

# All should show the same password
```

#### Issue: "File upload fails"

**Check:**
```bash
# Verify MinIO credentials match
grep AWS_ACCESS_KEY_ID .env.infra .env.api .env.worker
grep AWS_SECRET_ACCESS_KEY .env.infra .env.api .env.worker

# All should match
```

### Validation Script

```bash
#!/bin/bash
# validate-env.sh - Check environment variable consistency

echo "=== Checking SECRET_KEY consistency ==="
API_SECRET=$(grep "^SECRET_KEY=" .env.api | cut -d= -f2)
WORKER_SECRET=$(grep "^SECRET_KEY=" .env.worker | cut -d= -f2)
BEAT_SECRET=$(grep "^SECRET_KEY=" .env.beat-worker | cut -d= -f2)
LIVE_SECRET=$(grep "^LIVE_SERVER_SECRET_KEY=" .env.live | cut -d= -f2)

if [ "$API_SECRET" = "$WORKER_SECRET" ] && [ "$API_SECRET" = "$BEAT_SECRET" ] && [ "$API_SECRET" = "$LIVE_SECRET" ]; then
  echo "✅ SECRET_KEY consistent across all services"
else
  echo "❌ SECRET_KEY mismatch!"
fi

echo
echo "=== Checking PostgreSQL credentials ==="
INFRA_PG_PASS=$(grep "^POSTGRES_PASSWORD=" .env.infra | cut -d= -f2)
API_PG_PASS=$(grep "^POSTGRES_PASSWORD=" .env.api | cut -d= -f2)

if [ "$INFRA_PG_PASS" = "$API_PG_PASS" ]; then
  echo "✅ PostgreSQL credentials match"
else
  echo "❌ PostgreSQL password mismatch!"
fi

echo
echo "=== Checking MinIO credentials ==="
INFRA_MINIO_KEY=$(grep "^AWS_ACCESS_KEY_ID=" .env.infra | cut -d= -f2)
API_MINIO_KEY=$(grep "^AWS_ACCESS_KEY_ID=" .env.api | cut -d= -f2)

if [ "$INFRA_MINIO_KEY" = "$API_MINIO_KEY" ]; then
  echo "✅ MinIO credentials match"
else
  echo "❌ MinIO credentials mismatch!"
fi
```

---

## Summary

### Total Environment Variables

| File | Count | Purpose |
|------|-------|---------|
| `.env.infra` | ~20 | Infrastructure services configuration |
| `.env.api` | ~50 | API backend configuration |
| `.env.frontend` | ~30 | Frontend apps configuration |
| `.env.live` | ~20 | Live server configuration |
| `.env.worker` | ~40 | Worker configuration |
| `.env.beat-worker` | ~15 | Beat worker configuration |

### Priority Checklist

Before deployment, ensure these are configured:

- [ ] `SECRET_KEY` - Generated and consistent across all services
- [ ] `POSTGRES_PASSWORD` - Strong and consistent
- [ ] `RABBITMQ_PASSWORD` - Strong and consistent
- [ ] `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` - Strong and consistent
- [ ] `OPENAI_API_KEY` - Valid if using AI features
- [ ] `EMAIL_HOST_*` - Configured if sending emails
- [ ] `CORS_ALLOWED_ORIGINS` - Correct domain (no trailing slash!)
- [ ] `DEBUG=0` - In all production .env files
- [ ] Domain names - Updated to your actual domains

---

**References:**
- API Communication Guide: `API_COMMUNICATION_GUIDE.md`
- Deployment Guide: `DOKPLOY_DEPLOYMENT_GUIDE.md`
- Security Checklist: `SECURITY_CHECKLIST.md`
