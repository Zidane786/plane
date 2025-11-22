# Plane Local Development Setup

Run the entire Plane backend locally with Docker Compose.

## Quick Start

```bash
cd deployment/local

# Start all services
docker-compose -f docker-compose.local.yml --env-file .env.local up -d

# View logs
docker-compose -f docker-compose.local.yml logs -f

# Stop all services
docker-compose -f docker-compose.local.yml down
```

## What's Included

| Service | Port | Description |
|---------|------|-------------|
| **PostgreSQL** | 5432 | Database |
| **Redis** | 6379 | Cache |
| **RabbitMQ** | 5672, 15672 | Message broker (15672 = Management UI) |
| **MinIO** | 9000, 9001 | Local S3 storage (9001 = Console) |
| **API** | 8000 | Django REST API |
| **Worker** | - | Celery background tasks |
| **Beat Worker** | - | Celery scheduler |
| **Live Server** | 3005 | WebSocket server |

## Access Points

| Service | URL |
|---------|-----|
| **API** | http://localhost:8000 |
| **API Health** | http://localhost:8000/api/health/ |
| **Live Server** | http://localhost:3005 |
| **RabbitMQ UI** | http://localhost:15672 (plane_local / local_dev_rabbitmq_password_2024) |
| **MinIO Console** | http://localhost:9001 (plane_local_minio / local_dev_minio_secret_key_2024) |

## Local vs Production Credentials

| Credential | Local | Production |
|------------|-------|------------|
| **SECRET_KEY** | `local-dev-secret-key-...` | Different (generated) |
| **POSTGRES_PASSWORD** | `local_dev_postgres_password_2024` | Different (generated) |
| **RABBITMQ_PASSWORD** | `local_dev_rabbitmq_password_2024` | Different (generated) |
| **MINIO credentials** | `plane_local_minio` / `local_dev_minio_secret_key_2024` | Uses DO Spaces |

## Running Frontend Locally

The backend is set up to work with a locally running frontend:

```bash
# In a separate terminal, from project root
cd apps/web
pnpm install
pnpm dev
```

Frontend will be available at http://localhost:3000

## Common Commands

### View Logs
```bash
# All services
docker-compose -f docker-compose.local.yml logs -f

# Specific service
docker-compose -f docker-compose.local.yml logs -f api
docker-compose -f docker-compose.local.yml logs -f worker
```

### Restart Services
```bash
# Restart API only
docker-compose -f docker-compose.local.yml restart api

# Restart all
docker-compose -f docker-compose.local.yml restart
```

### Run Migrations Manually
```bash
docker-compose -f docker-compose.local.yml exec api python manage.py migrate
```

### Create Superuser
```bash
docker-compose -f docker-compose.local.yml exec api python manage.py createsuperuser
```

### Access Django Shell
```bash
docker-compose -f docker-compose.local.yml exec api python manage.py shell
```

### Reset Database
```bash
# Stop services
docker-compose -f docker-compose.local.yml down

# Remove volumes (WARNING: deletes all data!)
docker volume rm plane-local-postgres-data plane-local-redis-data plane-local-rabbitmq-data plane-local-minio-data

# Start fresh
docker-compose -f docker-compose.local.yml --env-file .env.local up -d
```

## Rebuild After Code Changes

```bash
# Rebuild API image
docker-compose -f docker-compose.local.yml build api

# Rebuild and restart
docker-compose -f docker-compose.local.yml up -d --build api worker beat-worker live
```

## Troubleshooting

### "Database connection refused"
Wait for PostgreSQL to be healthy:
```bash
docker-compose -f docker-compose.local.yml logs postgres
```

### "Migrations not applied"
Run migrator manually:
```bash
docker-compose -f docker-compose.local.yml up migrator
```

### "MinIO bucket doesn't exist"
```bash
docker-compose -f docker-compose.local.yml up minio-setup
```

### Check service health
```bash
docker-compose -f docker-compose.local.yml ps
```

## Environment Variables

All configuration is in `.env.local`. Key differences from production:

- `DEBUG=1` - Django debug mode enabled
- `USE_MINIO=1` - Uses local MinIO instead of DO Spaces
- `SESSION_COOKIE_SECURE=0` - HTTP allowed (no HTTPS locally)
- `GUNICORN_WORKERS=1` - Single worker for faster restarts

## File Structure

```
deployment/local/
├── docker-compose.local.yml   # All services configuration
├── .env.local                 # Environment variables
└── README.md                  # This file
```
