# Plane Deployment - Quick Start

**Choose your deployment strategy in 2 minutes.**

---

## 🎯 Quick Decision

```
┌─────────────────────────────────────────────────┐
│  Is this a production deployment?              │
├─────────────────────────────────────────────────┤
│  ✅ YES → Use 6 Services                       │
│  ❌ NO  → Continue...                          │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Do you need independent scaling?              │
│  (e.g., scale workers without restarting API)  │
├─────────────────────────────────────────────────┤
│  ✅ YES → Use 6 Services                       │
│  ❌ NO  → Continue...                          │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│  Will you have > 100 active users?              │
├─────────────────────────────────────────────────┤
│  ✅ YES → Use 6 Services                       │
│  ❌ NO  → Use 3 Services (Consolidated)        │
└─────────────────────────────────────────────────┘
```

---

## Option 1: 6 Services (Recommended ⭐)

**Best For**: Production, teams, scalability

```bash
cd deployment/6-services

# Read the guide
cat DEPLOYMENT_GUIDE.md

# Files you'll deploy:
# 1. docker-compose.infra.yml       (.env.infra)
# 2. docker-compose.migrator.yml     (.env.migrator) - ONE-TIME
# 3. docker-compose.api.yml          (.env.api)
# 4. docker-compose.worker.yml       (.env.worker)
# 5. docker-compose.beat-worker.yml  (.env.beat-worker)
# 6. docker-compose.live.yml         (.env.live)
# 7. nixpacks.frontend.toml          (.env.frontend)
```

**Setup Time**: 15-20 minutes
**Complexity**: Medium
**Control**: Maximum ✅
**Scalability**: Excellent ✅

---

## Option 2: Consolidated (3 Services)

**Best For**: Personal projects, demos, small deployments

```bash
cd deployment/consolidated

# Read the guide
cat DEPLOYMENT_GUIDE.md

# Files you'll deploy:
# 1. docker-compose.infra.yml      (.env.infra)
# 2. docker-compose.migrator.yml    (.env.migrator) - ONE-TIME
# 3. docker-compose.backend.yml    (.env.backend)
# 4. nixpacks.frontend.toml        (.env.frontend)
```

**Setup Time**: 10-15 minutes
**Complexity**: Low
**Control**: Good
**Scalability**: Limited

---

## 📚 Additional Resources

| Document | Purpose |
|----------|---------|
| `README.md` | Compare both approaches |
| `MONOREPO_TO_SERVICES_GUIDE.md` | Understand how monorepo maps to services |
| `6-services/DEPLOYMENT_GUIDE.md` | Step-by-step for 6 services |
| `consolidated/DEPLOYMENT_GUIDE.md` | Step-by-step for 3 services |

---

## 🚀 After Reading This

1. Choose 6-services or consolidated
2. `cd` into the folder
3. Read `DEPLOYMENT_GUIDE.md`
4. Follow the steps
5. Deploy to Dokploy!

---

## ❓ Still Unsure?

**Use 6 services if**:
- ✅ Production environment
- ✅ Need high availability
- ✅ Want to scale parts independently
- ✅ Have a team managing it
- ✅ >100 users expected

**Use consolidated (3 services) if**:
- ✅ Personal project
- ✅ Demo/testing environment
- ✅ <100 users
- ✅ Want simplest setup
- ✅ Solo developer

**When in doubt → Go with 6 services** (you can always consolidate later, but splitting is harder)

---

## 🎓 Learn More

- **Monorepo vs Micro-repos**: `MONOREPO_TO_SERVICES_GUIDE.md`
- **Service communication**: `../API_COMMUNICATION_GUIDE.md`
- **Security**: `../SECURITY_CHECKLIST.md`
- **Environment variables**: `../ENVIRONMENT_VARIABLES_REFERENCE.md`
