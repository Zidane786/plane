# Plane Telemetry & Analytics Analysis

**Date**: 2025-11-20  
**Analysis Type**: Privacy & Data Collection Review  
**Codebase**: Plane Community Edition (Self-Hosted)

---

## 🔍 Executive Summary

**YES, the Plane codebase contains telemetry** that sends data to external services. However, **it can be disabled** and is controlled by configuration settings.

### Key Findings

| Telemetry Type | Status | Default | Destination | Can Disable? |
|----------------|--------|---------|-------------|--------------|
| **OpenTelemetry Traces** | ✅ Active | ✅ Enabled | `telemetry.plane.so` | ✅ Yes |
| **PostHog Analytics** | ⚠️ Conditional | ❌ Disabled | PostHog (if configured) | ✅ Yes |
| **Instance Metrics** | ✅ Active | ✅ Enabled | `telemetry.plane.so` | ✅ Yes |

> [!WARNING]
> **Telemetry is ENABLED by default** (`is_telemetry_enabled = True`). You must explicitly disable it during setup or via God Mode.

---

## 📊 Telemetry Systems Found

### 1. **OpenTelemetry Tracing** (Backend)

**File**: `apps/api/plane/utils/telemetry.py`

**What it does**:
- Uses OpenTelemetry Protocol (OTLP) to send performance traces
- Sends data to: `https://telemetry.plane.so` (default endpoint)
- Auto-instruments Django requests

**Data sent**:
```python
service_name = "plane-ce-api"  # Service identifier
endpoint = "https://telemetry.plane.so"  # Plane's telemetry server
# Sends: Request traces, performance metrics, Django instrumentation data
```

**Control**: Set `OTLP_ENDPOINT` environment variable to change destination, but telemetry continues unless disabled in instance settings.

---

### 2. **Instance Usage Statistics** (Scheduled Task)

**File**: `apps/api/plane/license/bgtasks/tracer.py`

**What it does**:
- **Runs as a Celery scheduled task** (defined in `apps/api/plane/celery.py`)
- Collects aggregate statistics about your self-hosted instance
- Sends to `telemetry.plane.so` via OpenTelemetry

**Data collected and sent**:

#### Instance-Level Metrics:
```python
- instance_id              # Unique instance identifier
- instance_name            # Your instance name
- current_version          # Plane version you're running
- latest_version           # Latest available Plane version
- is_telemetry_enabled     # Whether telemetry is on
- is_support_required      # Support flag
- is_setup_done            # Setup completion status
- is_signup_screen_visited # Onboarding status
- is_verified              # Instance verification status
- edition                  # "PLANE_COMMUNITY"
- domain                   # Your instance domain
- is_test                  # Test instance flag
- user_count               # Total users
- workspace_count          # Total workspaces
- project_count            # Total projects
- issue_count              # Total issues
- module_count             # Total modules
- cycle_count              # Total cycles
- cycle_issue_count        # Total cycle issues
- module_issue_count       # Total module issues
- page_count               # Total pages
```

#### Per-Workspace Metrics:
```python
- workspace_id             # Workspace UUID
- workspace_slug           # Workspace slug
- project_count            # Projects in workspace
- issue_count              # Issues in workspace
- module_count             # Modules in workspace
- cycle_count              # Cycles in workspace
- member_count             # Members in workspace
# ... and more aggregate counts
```

**Frequency**: Runs on a schedule (defined in Celery Beat)

**Important**: This task checks `instance.is_telemetry_enabled` before sending, so disabling telemetry stops this data collection.

---

### 3. **PostHog Product Analytics** (Frontend)

**Files**:
- `apps/web/core/lib/posthog-provider.tsx`
- `apps/web/helpers/event-tracker.helper.ts`
- `apps/api/plane/bgtasks/event_tracking_task.py`

**What it does**:
- Tracks user interactions, clicks, page views
- Sends authentication events (login, signup, workspace invites)
- **Only active if configured** with PostHog credentials

**Data sent**:

#### Frontend Events:
```typescript
// User identification
{
  id: user.id,
  email: user.email,
  first_name: user.first_name,
  last_name: user.last_name,
  workspace_role: "Admin/Member/...",
  project_role: "Admin/Member/..."
}

// UI interactions
{
  element_type: "button_clicked",
  timestamp: "2025-11-20T...",
  workspace_id: "uuid",
  // ... context about where the click happened
}

// Workspace grouping
{
  workspace_id: "uuid",
  date: "2025-11-20"
}
```

#### Backend Events (via Celery):
```python
# Authentication events
{
  event_id: uuid,
  user: {email, id},
  device_ctx: {ip, user_agent},
  medium: "email/google/github/...",
  first_time: true/false
}

# Workspace invite events
{
  event_id: uuid,
  user: {email, id},
  device_ctx: {ip, user_agent},
  accepted_from: "email/link"
}
```

**Control**: 
- Requires `NEXT_PUBLIC_POSTHOG_KEY` and `NEXT_PUBLIC_POSTHOG_HOST` environment variables
- **Also** requires `instance.is_telemetry_enabled = True`
- **By default, these env vars are EMPTY**, so PostHog is disabled unless you configure it

```tsx
// From posthog-provider.tsx:38-40
const is_telemetry_enabled = instance?.is_telemetry_enabled || false;
const is_posthog_enabled =
  process.env.NEXT_PUBLIC_POSTHOG_KEY && process.env.NEXT_PUBLIC_POSTHOG_HOST && is_telemetry_enabled;
```

---

## 🎛️ How to Disable Telemetry

### Method 1: During Initial Setup (Recommended)

When you first set up your Plane instance via God Mode (`/god-mode`), you'll see a checkbox:

**File**: `apps/admin/core/components/instance/setup-form.tsx:325-330`

```tsx
<input
  type="checkbox"
  id="is_telemetry_enabled"
  onChange={() => handleFormChange("is_telemetry_enabled", !formData.is_telemetry_enabled)}
  checked={formData.is_telemetry_enabled}  // Default: TRUE
/>
<label htmlFor="is_telemetry_enabled">
  Enable anonymized telemetry to help us improve Plane
</label>
```

**Action**: **Uncheck this box** during setup.

---

### Method 2: After Setup (God Mode Settings)

1. Go to `/god-mode` in your Plane instance
2. Navigate to **General Settings**
3. Toggle off "Enable Telemetry"
4. Save

**File**: `apps/admin/app/(all)/(dashboard)/general/form.tsx`

---

### Method 3: Database Direct Edit (Advanced)

If you can't access the UI:

```sql
-- Connect to your PostgreSQL database
psql -U plane -d plane

-- Disable telemetry
UPDATE instances SET is_telemetry_enabled = false;

-- Verify
SELECT instance_name, is_telemetry_enabled FROM instances;
```

---

### Method 4: Environment Variable Override (Partial)

Change the telemetry endpoint to nowhere:

```bash
# In .env.api
OTLP_ENDPOINT=http://localhost:9999  # Non-existent endpoint
```

**Note**: This only blocks OpenTelemetry, not the instance metrics task. The task will still run, just fail to send data.

---

## 🔐 Privacy Considerations

### What is **NOT** Sent

✅ **Personal/Sensitive Data**:
- ❌ Issue content/descriptions
- ❌ Page content
- ❌ Comments
- ❌ User passwords
- ❌ API keys
- ❌ File attachments
- ❌ Project details beyond counts

### What **IS** Sent (When Enabled)

⚠️ **Aggregate Metrics**:
- ✅ Instance metadata (version, domain, edition)
- ✅ Usage statistics (counts of users, projects, issues, etc.)
- ✅ Workspace slugs (but not project names or sensitive content)
- ✅ User emails and names (for PostHog, if configured)
- ✅ IP addresses and user agents (for auth events via PostHog)

### Data Destination

All telemetry goes to:
- **Primary**: `https://telemetry.plane.so` (Plane's official telemetry server)
- **Secondary**: PostHog (only if you configure `NEXT_PUBLIC_POSTHOG_HOST`)

**No third-party tracking** by default (no Google Analytics, Sentry, etc. unless you configure them).

---

## 📋 Telemetry Code Locations

| Component | Files | Purpose |
|-----------|-------|---------|
| **OpenTelemetry** | `apps/api/plane/utils/telemetry.py` | Trace exporter setup |
| **Instance Metrics** | `apps/api/plane/license/bgtasks/tracer.py` | Usage statistics collection |
| **Celery Task** | `apps/api/plane/celery.py:32` | Scheduled task registration |
| **PostHog Frontend** | `apps/web/core/lib/posthog-provider.tsx` | User event tracking |
| **PostHog Backend** | `apps/api/plane/bgtasks/event_tracking_task.py` | Auth event tracking |
| **Event Helpers** | `apps/web/helpers/event-tracker.helper.ts` | Event capture utilities |
| **Instance Model** | `apps/api/plane/license/models/instance.py:31` | `is_telemetry_enabled` field |

---

## 🧪 Verification Steps

### 1. Check Current Telemetry Status

```bash
# Access your Plane database
docker exec -it plane-postgres psql -U plane -d plane

# Query telemetry status
SELECT instance_name, is_telemetry_enabled, domain FROM instances;
```

### 2. Monitor Network Traffic

```bash
# Check if data is being sent to telemetry.plane.so
docker logs plane-api 2>&1 | grep telemetry.plane.so

# Or monitor with tcpdump
sudo tcpdump -i any -A 'host telemetry.plane.so'
```

### 3. Check Environment Variables

```bash
# Frontend
grep -r "POSTHOG" .env*
# Should be empty if not configured

# Backend
grep "OTLP_ENDPOINT" .env.api
# Default: https://telemetry.plane.so
```

---

## 🚫 Complete Telemetry Removal (Nuclear Option)

If you want to **completely remove** telemetry code from your fork:

### 1. Remove OpenTelemetry

```bash
# Delete telemetry utility
rm apps/api/plane/utils/telemetry.py

# Remove from requirements
grep -v "opentelemetry" apps/api/requirements/base.txt > temp && mv temp apps/api/requirements/base.txt

# Remove imports (search codebase for)
grep -r "from plane.utils.telemetry" apps/api/
# Delete those lines
```

### 2. Remove Instance Tracing Task

```bash
# Delete the tracer
rm apps/api/plane/license/bgtasks/tracer.py

# Edit celery.py to remove scheduled task
# Remove lines 31-35 in apps/api/plane/celery.py
```

### 3. Remove PostHog

```bash
# Delete PostHog files
rm apps/web/core/lib/posthog-provider.tsx
rm apps/web/core/lib/posthog-view.tsx
rm apps/web/helpers/event-tracker.helper.ts

# Remove PostHog package
# Edit apps/web/package.json, remove:
# "posthog-js": "...",
# "posthog-js/react": "..."

# Remove imports (search for posthog)
grep -r "posthog" apps/web/
```

### 4. Remove from Docker

```bash
# Edit Dockerfiles to remove telemetry packages
# apps/space/Dockerfile.space:56
# apps/web/Dockerfile.web:56
# apps/live/Dockerfile.live:56
# apps/admin/Dockerfile.admin:56

# Remove: ARG NEXT_PUBLIC_ENABLE_TELEMETRY=0
```

---

## 📄 Environment Variables Related to Telemetry

| Variable | Location | Purpose | Default |
|----------|----------|---------|---------|
| `OTLP_ENDPOINT` | API | OpenTelemetry endpoint | `https://telemetry.plane.so` |
| `NEXT_PUBLIC_POSTHOG_KEY` | Frontend | PostHog API key | *(empty)* |
| `NEXT_PUBLIC_POSTHOG_HOST` | Frontend | PostHog host | *(empty)* |
| `VITE_POSTHOG_KEY` | Frontend (Vite) | PostHog API key | *(empty)* |
| `VITE_POSTHOG_HOST` | Frontend (Vite) | PostHog host | *(empty)* |
| `POSTHOG_API_KEY` | API (backend events) | PostHog API key | *(from config)* |
| `POSTHOG_HOST` | API (backend events) | PostHog host | *(from config)* |
| `INSTANCE_KEY` | API | Instance identifier | *(empty)* |

**Note**: PostHog variables are empty by default, so PostHog telemetry is disabled unless you explicitly configure it.

---

## ✅ Recommendations

### For Privacy-Conscious Users

1. **Disable during setup**: Uncheck telemetry during initial God Mode setup
2. **Verify**: Check database to confirm `is_telemetry_enabled = false`
3. **Monitor**: Periodically check logs for connections to `telemetry.plane.so`
4. **Block at firewall**: Optionally block `telemetry.plane.so` at your firewall level

### For Plane Supporters

If you want to help Plane improve:
- **Keep telemetry enabled**: It only sends aggregate usage stats
- **No personal data** is sent (issue content, passwords, etc.)
- Helps Plane team understand:
  - Which features are used
  - Performance bottlenecks
  - Version adoption rates
  - Community Edition usage patterns

---

## 🔗 Additional Context

### Why Does Plane Collect Telemetry?

From the codebase, it appears Plane collects telemetry to:
1. **Version tracking**: Know which versions are deployed
2. **Feature usage**: Understand which features in CE are popular
3. **Support needs**: Identify instances that need help (`is_support_required`)
4. **Product analytics**: General usage patterns for product development

### Is This Common?

Yes, many self-hosted open-source tools include **opt-in** or **opt-out** telemetry:
- **GitLab**: Collects usage statistics (opt-out)
- **Sentry**: Telemetry enabled by default
- **Grafana**: Usage analytics (can disable)
- **VS Code**: Telemetry enabled by default

Plane's approach is **better than average** because:
- ✅ Can be disabled via UI (not just config files)
- ✅ No third-party analytics by default
- ✅ Only aggregate data, no content
- ✅ OpenTelemetry is industry standard (not proprietary)

---

## Conclusion

**Telemetry exists and is enabled by default**, but:
- ✅ **Can be easily disabled** via God Mode UI
- ✅ **No sensitive data** (issue content, files, etc.) is sent
- ✅ **Transparent**: All code is visible in the repository
- ✅ **Controlled**: Requires `is_telemetry_enabled = True` to function

**Action Items**:
1. Go to `/god-mode` → General Settings
2. Toggle off "Enable Telemetry"
3. Save changes
4. Verify with: `SELECT is_telemetry_enabled FROM instances;`

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-20  
**Author**: Gemini Analysis
