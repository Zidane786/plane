# Plane Dokploy Deployment Options

This folder contains **two deployment approaches** for Plane on Dokploy. Choose based on your needs.

---

## 📋 Quick Comparison

| Aspect | 6 Services (Recommended) | Consolidated (3 Services) |
|--------|-------------------------|---------------------------|
| **Dokploy Apps** | 6 apps + 1 migrator | 3 apps + 1 migrator |
| **Complexity** | Medium | Low |
| **Control** | Maximum | Good |
| **Scaling** | Independent per service | Limited |
| **Debugging** | Easiest (isolated logs) | Moderate |
| **Resource Allocation** | Granular | Grouped |
| **Best For** | Production, Teams | Small deployments, Solo |

---

## Option 1: 6 Services (RECOMMENDED) ⭐

**Location**: `deployment/6-services/`

### Architecture

```
┌──────────────────────────────────────────────────────┐
│            6 Dokploy Apps + 1 Migrator                │
├──────────────────────────────────────────────────────┤
│  1. Infrastructure (Postgres, Redis, RabbitMQ)       │
│  2. Migrator (DB migrations - ONE-TIME, then delete) │
│  3. API Backend (Django REST API)                    │
│  4. Worker (Celery background tasks)                 │
│  5. Beat Worker (Celery scheduler)                   │
│  6. Live Server (WebSocket collaboration)            │
│  7. Frontend (Web + Admin + Space apps)              │
└──────────────────────────────────────────────────────┘
```

### Why 6 Services?

**✅ Advantages:**
1. **Independent Scaling**
   - Scale workers without restarting API
   - Add more worker instances under heavy load
   - Live server can scale independently for WebSocket connections

2. **Isolated Deployments**
   - Update frontend without touching backend
   - Restart API without affecting background jobs
   - Workers continue processing during API updates

3. **Better Resource Management**
   - Assign 2GB to API, 4GB to workers
   - Different CPU allocations per service
   - Live server gets dedicated resources

4. **Easier Debugging**
   - Each service has separate logs
   - Identify issues faster (is it API or worker?)
   - Monitor each service individually

5. **Production Best Practice**
   - Follows microservices architecture
   - Easier disaster recovery
   - Better observability

**❌ Disadvantages:**
- More applications to manage in Dokploy (6 vs 3)
- Slightly more complex initial setup
- More environment variable files to maintain

### When to Use
- ✅ Production deployments
- ✅ Team environments
- ✅ High-traffic applications
- ✅ When you need independent scaling
- ✅ When you want maximum control

### Files Included

```
6-services/
├── docker-compose.infra.yml          # Infrastructure services
├── docker-compose.migrator.yml       # Database migrations (ONE-TIME)
├── docker-compose.api.yml            # API backend
├── docker-compose.worker.yml         # Celery worker
├── docker-compose.beat-worker.yml    # Celery beat
├── docker-compose.live.yml           # Live server
├── nixpacks.frontend.toml            # Frontend build config (Nixpacks)
│                                      # Note: Backend uses Docker Compose
├── .env.infra
├── .env.migrator                     # Migrator env (minimal)
├── .env.api
├── .env.worker
├── .env.beat-worker
├── .env.live
├── .env.frontend
└── (see root DOKPLOY_DEPLOYMENT_GUIDE.md for full instructions)
```

---

## Option 2: Consolidated (3 Services)

**Location**: `deployment/consolidated/`

### Architecture

```
┌──────────────────────────────────────────────────────┐
│            3 Dokploy Apps + 1 Migrator                │
├──────────────────────────────────────────────────────┤
│  1. Infrastructure (Postgres, Redis, RabbitMQ)       │
│  2. Migrator (DB migrations - ONE-TIME, then delete) │
│  3. Backend (API + Worker + Beat Worker + Live)      │
│  4. Frontend (Web + Admin + Space apps)              │
└──────────────────────────────────────────────────────┘
```

### Why 3 Services?

**✅ Advantages:**
1. **Simplicity**
   - Only 3 Dokploy applications to manage
   - Fewer environment files
   - Easier initial setup

2. **Easier Management**
   - Less configuration to maintain
   - Single backend deployment
   - Good for small teams

3. **Faster Deployment**
   - Fewer steps to deploy
   - Less time to set up

**❌ Disadvantages:**
- Can't scale workers independently from API
- Restarting API also restarts workers (interrupts background jobs)
- All backend services share same resource limits
- Less granular control
- Harder to debug (mixed logs)

### When to Use
- ✅ Small deployments (< 1000 users)
- ✅ Solo developer projects
- ✅ Testing/staging environments
- ✅ When simplicity is priority
- ✅ Limited resources (small VPS)

### Files Included

```
consolidated/
├── docker-compose.infra.yml          # Infrastructure services
├── docker-compose.migrator.yml       # Database migrations (ONE-TIME)
├── docker-compose.backend.yml        # All backend services combined
├── nixpacks.frontend.toml            # Frontend build config
├── .env.infra
├── .env.migrator                     # Migrator env (minimal)
├── .env.backend                      # Single backend env file
├── .env.frontend
└── (see root DOKPLOY_DEPLOYMENT_GUIDE.md for full instructions)
```

---

## 📊 Detailed Comparison

### Resource Usage

**6 Services:**
```
Infrastructure: 2GB RAM, 1 CPU
API:            1GB RAM, 1 CPU
Worker:         2GB RAM, 1 CPU  ← Can allocate more for heavy processing
Beat Worker:    512MB RAM, 0.5 CPU
Live Server:    1GB RAM, 1 CPU  ← Dedicated for WebSocket
Frontend:       512MB RAM, 0.5 CPU
─────────────────────────────────
Total:          7GB RAM, 5 CPUs (allocated granularly)
```

**3 Services (Consolidated):**
```
Infrastructure: 2GB RAM, 1 CPU
Backend:        4GB RAM, 2 CPUs  ← All backend services share this
Frontend:       512MB RAM, 0.5 CPU
─────────────────────────────────
Total:          6.5GB RAM, 3.5 CPUs (less flexible allocation)
```

### Scaling Example

**Scenario**: Heavy background processing load (imports, exports)

**6 Services:**
```bash
# In Dokploy: Scale worker service to 3 instances
# API continues running normally
# Users don't experience any interruption
```

**3 Services (Consolidated):**
```bash
# Can't scale just workers
# Must scale entire backend (API + Workers + Live)
# Wastes resources (API doesn't need scaling)
# OR manually reconfigure to split services
```

### Deployment Speed

| Task | 6 Services | 3 Services |
|------|------------|------------|
| **Initial Setup** | 15-20 minutes | 10-15 minutes |
| **Update API Only** | 2 minutes (restart API) | 5 minutes (restart all backend) |
| **Update Workers** | 1 minute (restart worker) | 5 minutes (restart all backend) |
| **Update Frontend** | 3 minutes | 3 minutes |
| **Add More Workers** | 30 seconds (scale worker) | Must reconfigure |

### Real-World Scenario

**You have 1000 active users and need to import 10,000 issues from Jira:**

**With 6 Services:**
1. Trigger import job (goes to Worker)
2. Worker processes in background (takes 30 minutes)
3. API serves users normally
4. Users don't notice anything
5. If Worker is slow, scale to 2-3 worker instances

**With 3 Services (Consolidated):**
1. Trigger import job (goes to Worker, same container as API)
2. Worker uses CPU/RAM, affecting API performance
3. Users experience slow API responses
4. Can't scale just workers
5. Must wait for job to finish or restart entire backend

---

## 🎯 My Recommendation

### Use 6 Services If:
- ✅ Production environment
- ✅ > 50 users
- ✅ Heavy background processing
- ✅ Need high availability
- ✅ Want to scale in the future
- ✅ Have a team managing it

### Use 3 Services (Consolidated) If:
- ✅ Personal project / demo
- ✅ < 50 users
- ✅ Limited VPS resources (2GB RAM)
- ✅ Want simplest setup
- ✅ Testing/development environment
- ✅ Solo developer

---

## 🚀 Getting Started

### Choose Your Approach:

#### Option 1: 6 Services (Recommended)
```bash
cd deployment/6-services
# Read the deployment guide
cat DEPLOYMENT_GUIDE.md
```

#### Option 2: Consolidated
```bash
cd deployment/consolidated
# Read the deployment guide
cat DEPLOYMENT_GUIDE.md
```

---

## 📝 Migration Path

**Start with 3 Services, migrate to 6 Services later?**

Yes! You can start simple and migrate:

1. **Start**: Deploy with 3 services (consolidated)
2. **Grow**: When you hit performance issues or need scaling
3. **Migrate**:
   - Deploy worker as separate service
   - Update API to remove worker process
   - Deploy beat-worker separately
   - Deploy live separately
4. **Result**: Now running 6 services with zero downtime

**Migration Guide**: See `deployment/MIGRATION_GUIDE.md`

---

## 🆘 Quick Decision Tree

```
Do you have < 50 users?
├─ YES → Use 3 Services (Consolidated)
└─ NO  → Continue...
    │
    Do you need to scale workers independently?
    ├─ YES → Use 6 Services
    └─ NO  → Continue...
        │
        Is this a production deployment?
        ├─ YES → Use 6 Services (future-proof)
        └─ NO  → Use 3 Services (simpler)
```

---

## 📞 Support

- **6 Services Guide**: `deployment/6-services/DEPLOYMENT_GUIDE.md`
- **Consolidated Guide**: `deployment/consolidated/DEPLOYMENT_GUIDE.md`
- **Environment Variables**: `ENVIRONMENT_VARIABLES_REFERENCE.md`
- **Security**: `SECURITY_CHECKLIST.md`
- **API Communication**: `API_COMMUNICATION_GUIDE.md`

---

**Bottom Line**: For production, use **6 services**. For demos/personal projects, use **3 services consolidated**.
