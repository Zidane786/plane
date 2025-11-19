# Plane Enterprise Features Analysis & Implementation Guide

## Executive Summary

This document provides a comprehensive analysis of **Plane Enterprise features**, comparing what exists in the current Community Edition (CE) codebase versus what's available in Plane's commercial offerings (One, Pro, Business, Enterprise). Based on web research and codebase analysis, this guide outlines implementation complexity and a recommended implementation roadmap.

> [!IMPORTANT]
> **Key Finding**: The current codebase is the **Community Edition** which lacks most enterprise features. However, the codebase contains infrastructure for licensing and tiered features, with OIDC and SAML explicitly marked as "unavailable" in the CE admin panel.

---

## Feature Comparison Matrix

### ✅ Features Present in Community Edition

| Feature | Description | Status |
|---------|-------------|--------|
| **Core Project Management** | Projects, work items, cycles, modules, comments | ✅ Present |
| **Multiple Views** | Kanban, List, Gantt, Calendar, Spreadsheet | ✅ Present |
| **Basic Pages** | Knowledge base without real-time collaboration | ✅ Present |
| **Self-Hosting** | Docker/Kubernetes deployment | ✅ Present |
| **Basic Authentication** | Email/Password, Magic Links/Codes | ✅ Present |
| **OAuth Integration** | Google, GitHub, GitLab, Gitea | ✅ Present |
| **God Mode** | Instance admin interface for self-hosted | ✅ Present |
| **Basic Importers** | Jira, GitHub (without custom props) | ✅ Present |

### ❌ Features Missing (Enterprise Only)

#### 🔐 **1. Security & Authentication** (Priority: CRITICAL)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **SAML SSO** | One+ | High | 3-4 weeks |
| **OIDC SSO** | One+ (Self-hosted) | High | 3-4 weeks |
| **SCIM User Provisioning** | One+ | Very High | 4-6 weeks |
| **LDAP Support** | Enterprise | Very High | 4-6 weeks |
| **Two-Factor Authentication** | Pro+ | Medium | 2-3 weeks |
| **Password Policies** | Pro+ | Low | 1 week |
| **Domain Security** | Pro+ | Medium | 2 weeks |

#### 👥 **2. Access Control & User Management** (Priority: HIGH)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **RBAC (Role-Based Access Control)** | Business+ | High | 3-4 weeks |
| **GAC (Granular Access Control)** | Enterprise | Very High | 6-8 weeks |
| **Custom Roles** | Business+ | High | 3 weeks |
| **Guest Users (5 per member)** | One+ | Medium | 2 weeks |
| **Approvals System** | Business+ | High | 4 weeks |

#### 📊 **3. Analytics & Audit** (Priority: HIGH)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **Workspace Activity Logs** | Business+ | Medium | 2-3 weeks |
| **API-Enabled Audit Logs** | Business+ | High | 3-4 weeks |
| **Custom Reports** | Business+ | High | 4-5 weeks |
| **Advanced Analytics** | Business+ | Medium-High | 3-4 weeks |
| **Time Capsule (Point-in-time)** | Business+ | Very High | 6+ weeks |

#### 🔧 **4. Advanced Project Management** (Priority: MEDIUM)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **Project Templates** | Business+ | Medium | 2-3 weeks |
| **Work Item Types (Custom)** | Pro+ | High | 3-4 weeks |
| **Custom Properties** | Pro+ | Medium-High | 3 weeks |
| **Epics** | Pro+ | Medium | 2-3 weeks |
| **Initiatives** | Pro+ | Medium | 2-3 weeks |
| **Baselines & Deviations** | Business+ | High | 4 weeks |
| **Intake Forms** | Business+ | Medium | 2-3 weeks |
| **Custom SLAs** | Business+ | Medium | 2-3 weeks |

#### ⚡ **5. Automation & Workflows** (Priority: MEDIUM)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **Trigger & Action Automation** | Pro+ | High | 4-5 weeks |
| **Decision & Loops Automation** | Business+ | Very High | 6+ weeks |
| **Unlimited Automations** | Enterprise | N/A | Licensing only |
| **Scheduled Communications** | Business+ | Medium | 2-3 weeks |

#### 📝 **6. Knowledge Management** (Priority: MEDIUM)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **Real-time Collaboration** | One+ | High | 4-5 weeks |
| **Nested Pages** | Business+ | Medium | 2-3 weeks |
| **Page Templates** | Pro+ | Low-Medium | 1-2 weeks |
| **Page Versions** | Pro+ | Medium-High | 3-4 weeks |
| **Databases + Formulas** | Enterprise | Very High | 8+ weeks |
| **Advanced Page Analytics** | Business+ | Medium | 2-3 weeks |

#### 🔗 **7. Integrations** (Priority: LOW-MEDIUM)

| Feature | Tier | Complexity | Implementation Effort |
|---------|------|------------|----------------------|
| **GitHub Sync** | Pro+ | High | 4 weeks |
| **Slack Integration** | Pro+ | Medium | 2-3 weeks |
| **Zapier** | Pro+ | Medium | 2-3 weeks |
| **Zendesk** | Pro+ | Medium | 2 weeks |
| **Freshdesk** | Pro+ | Medium | 2 weeks |

---

## Codebase Analysis Findings

### 📂 Existing Infrastructure

1. **License Module** (`apps/api/plane/license/`)
   - ✅ Base license framework exists
   - ✅ Instance admin permissions structure
   - ✅ License API serializers and views
   - ⚠️ No actual license validation logic visible

2. **Subscription Tiers** (`packages/constants/src/subscription.ts`)
   ```typescript
   ENTERPRISE_PLAN_FEATURES: ["GAC", "LDAP support", "Databases + Formulas", ...]
   BUSINESS_PLAN_FEATURES: ["RBAC", "Project Templates", "Workflows + Approvals", ...]
   PRO_PLAN_FEATURES: ["Dashboards + Reports", "Full Time Tracking", "Teamspaces", ...]
   ONE_PLAN_FEATURES: ["OIDC + SAML for SSO", "Active Cycles", "Real-time collab", ...]
   ```

3. **Authentication Infrastructure**
   - ✅ OAuth providers (Google, GitHub, GitLab, Gitea) fully implemented
   - ❌ SAML/OIDC marked as "unavailable" in CE (`authentication-modes.tsx:97-107`)
   - ✅ Email/password and magic code authentication
   - ✅ Base authentication adapter pattern

4. **Admin Interface** (`apps/admin/`)
   - ✅ God Mode for instance configuration
   - ✅ Authentication method configuration UI
   - ✅ "Upgrade" buttons for enterprise features

### 🔍 Evidence of Enterprise Feature Markers

The codebase contains clear tier separation:

```tsx
// From authentication-modes.tsx (lines 92-107)
{
  key: "oidc",
  name: "OIDC",
  config: <UpgradeButton />,
  unavailable: true,  // ❌ Not implemented in CE
},
{
  key: "saml",
  name: "SAML", 
  config: <UpgradeButton />,
  unavailable: true,  // ❌ Not implemented in CE
}
```

---

## Implementation Roadmap

### 🎯 Recommended Implementation Order

> [!TIP]
> Focus on foundational security and access control features first, as they provide the most enterprise value and are prerequisites for other advanced features.

#### **Phase 1: Security Foundation** (12-16 weeks)
*Essential for enterprise adoption*

1. **SAML SSO** (3-4 weeks)
   - Setup: IdP configuration, Entity ID, ACS endpoints
   - Backend: SAML assertion parsing, signature verification
   - Frontend: Login flow integration
   - Testing: Integration with common IdPs (Okta, Azure AD, OneLogin)

2. **OIDC SSO** (3-4 weeks)
   - Setup: Discovery endpoint, client credentials
   - Backend: Token validation, userinfo endpoint
   - Frontend: Authorization code flow
   - Testing: Integration with major providers

3. **Two-Factor Authentication** (2-3 weeks)
   - TOTP implementation (Google Authenticator compatible)
   - Backup codes generation
   - Frontend: Setup and verification flows

4. **Password Policies** (1 week)
   - Configurable requirements (length, complexity, expiration)
   - Admin interface for policy management

5. **Domain Security** (2 weeks)
   - Email domain whitelisting/blacklisting
   - Workspace-level domain restrictions

#### **Phase 2: Access Control** (10-14 weeks)
*Critical for multi-team organizations*

1. **RBAC Foundation** (3-4 weeks)
   - Permission matrix design
   - Custom role creation UI
   - Backend permission checks across all endpoints
   - Migration of existing roles

2. **Workspace Activity Logs** (2-3 weeks)
   - Event tracking infrastructure
   - Filterable activity log UI
   - Export capabilities

3. **Guest Users** (2 weeks)
   - Limited permission set
   - Per-member quota enforcement
   - Invitation workflow

4. **GAC (Granular Access Control)** (6-8 weeks)
   - Resource-level permissions
   - Inheritance model
   - Performance optimization

#### **Phase 3: Advanced Project Management** (8-12 weeks)
*Enhances productivity for power users*

1. **Custom Work Item Types** (3-4 weeks)
   - Type creation and management
   - Custom field system
   - Migration tools

2. **Project Templates** (2-3 weeks)
   - Template creation from existing projects
   - Template library
   - Instantiation workflow

3. **Epics & Initiatives** (2-3 weeks each)
   - Hierarchical work item structure
   - Rollup calculations
   - Visualization improvements

4. **Intake Forms** (2-3 weeks)
   - Public form builder
   - Workflow integration
   - Approval system

#### **Phase 4: Automation & Analytics** (12-16 weeks)
*Reduces manual work and provides insights*

1. **Trigger & Action Automation** (4-5 weeks)
   - Automation engine
   - Trigger definitions (status change, assignment, etc.)
   - Action handlers (notifications, updates, etc.)
   - Visual automation builder

2. **API-Enabled Audit Logs** (3-4 weeks)
   - Comprehensive event logging
   - REST API for log access
   - Compliance reporting

3. **Custom Reports** (4-5 weeks)
   - Report builder UI
   - Data aggregation engine
   - Scheduled report generation

4. **Decision & Loops Automation** (6+ weeks)
   - Conditional logic in automation
   - Loop constructs
   - Complex workflow orchestration

#### **Phase 5: Advanced Features** (16+ weeks)
*Nice-to-have for specialized use cases*

1. **SCIM User Provisioning** (4-6 weeks)
   - SCIM 2.0 server implementation
   - User/group sync
   - IdP-specific connectors

2. **LDAP Support** (4-6 weeks)
   - LDAP client implementation
   - Directory sync
   - Nested group support

3. **Real-time Collaboration** (4-5 weeks)
   - WebSocket infrastructure
   - Operational Transform (OT) or CRDT for conflict resolution
   - Presence indicators

4. **Databases + Formulas** (8+ weeks)
   - Database schema within pages
   - Formula language parser
   - Computed fields

---

## Implementation Complexity Ratings

### 🟢 Low Complexity (1-2 weeks each)
- Password Policies
- Page Templates
- Domain Security (basic)

### 🟡 Medium Complexity (2-4 weeks each)
- Two-Factor Authentication
- Guest Users
- Project Templates
- Workspace Activity Logs
- Intake Forms
- Custom SLAs
- Nested Pages
- Most Integrations (Slack, Zapier, etc.)

### 🟠 High Complexity (4-6 weeks each)
- SAML SSO
- OIDC SSO
- RBAC
- Custom Work Item Types
- Custom Properties
- Trigger & Action Automation
- API-Enabled Audit Logs
- Custom Reports
- Real-time Collaboration
- GitHub Sync

### 🔴 Very High Complexity (6+ weeks each)
- SCIM User Provisioning
- LDAP Support
- GAC (Granular Access Control)
- Decision & Loops Automation
- Time Capsule (Point-in-time snapshots)
- Databases + Formulas

---

## Technical Architecture Considerations

### 🏗️ Required Infrastructure Changes

#### 1. **Licensing & Feature Gating System**
```python
# Proposed structure
class FeatureGate:
    @staticmethod
    def check_feature(workspace_id: str, feature: str) -> bool:
        """Check if workspace has access to feature"""
        license = License.get_for_workspace(workspace_id)
        return license.plan.has_feature(feature)
    
    @staticmethod
    def require_feature(feature: str):
        """Decorator for views requiring specific features"""
        def decorator(func):
            def wrapper(self, request, *args, **kwargs):
                workspace_id = kwargs.get('workspace_id')
                if not FeatureGate.check_feature(workspace_id, feature):
                    return Response(
                        {"error": "This feature requires an upgrade"},
                        status=403
                    )
                return func(self, request, *args, **kwargs)
            return wrapper
        return decorator
```

#### 2. **Authentication Abstraction Layer**
- Extend existing `authentication/adapter/base.py`
- Add SAML and OIDC providers
- Implement common `AuthProvider` interface
- Support provider-specific configurations

#### 3. **Permission System Overhaul**
For RBAC/GAC:
- Current: Basic workspace/project-level roles
- Needed: Resource-level permissions with inheritance
- Database: Permission matrix tables
- Caching: Redis for permission lookups

#### 4. **Event Tracking Infrastructure**
For audit logs:
- Event sourcing pattern
- Centralized event bus
- Structured logging
- Long-term storage strategy

#### 5. **Automation Engine**
- Event-driven architecture
- Trigger registry
- Action queue (Celery/RabbitMQ)
- Retry and error handling

---

## Dependencies & Prerequisites

### External Services/Libraries Needed

| Feature | Dependencies | Notes |
|---------|-------------|-------|
| SAML SSO | `python3-saml`, `xmlsec1` | Complex XML signature verification |
| OIDC SSO | `authlib`, `jose` | JWT validation |
| SCIM | `scim2-server` or custom | SCIM 2.0 protocol implementation |
| LDAP | `python-ldap`, `ldap3` | Directory access |
| 2FA | `pyotp`, `qrcode` | TOTP implementation |
| Real-time Collab | `websockets`, `yjs` or `automerge` | CRDT library |
| Automation | `celery`, `redis` | Task queue (already in codebase) |

### Database Schema Changes

Many features require new tables:

- **Audit Logs**: `audit_events` table with JSON payload
- **Custom Roles**: `custom_roles`, `role_permissions` tables
- **Automation**: `automation_rules`, `automation_runs` tables
- **SCIM**: `scim_tokens`, `scim_sync_logs` tables
- **Templates**: `project_templates`, `page_templates` tables

---

## Testing & Verification Strategy

### 🧪 Recommended Testing Approach

1. **Unit Tests**: 80%+ coverage for new backend logic
2. **Integration Tests**: IdP integrations (SAML/OIDC/LDAP)
3. **End-to-End Tests**: Critical user flows (authentication, automation)
4. **Load Testing**: Audit logs, real-time collaboration
5. **Security Audit**: Third-party review for auth features

### Mock Enterprise Environment Setup

```yaml
# docker-compose.override.yml for testing
services:
  keycloak:  # For SAML/OIDC testing
    image: quay.io/keycloak/keycloak:latest
    ports:
      - "8080:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
  
  openldap:  # For LDAP testing
    image: osixia/openldap:latest
    ports:
      - "389:389"
```

---

## Licensing Considerations

> [!WARNING]
> **Legal & Business Implications**
> 
> Implementing enterprise features in an open-source fork raises important questions:
> 
> 1. **License Compatibility**: Check if Plane's license (likely AGPL) allows this
> 2. **Trademark**: Cannot use "Plane" branding for commercial offering
> 3. **Support Burden**: Enterprise features require ongoing maintenance
> 4. **Competition**: Consider relationship with official Plane team

### Alternative Approaches

1. **Contribute Upstream**: Submit features as open-source contributions
2. **Plugin Architecture**: Build features as optional plugins
3. **Fork & Rebrand**: Create separate product if license permits
4. **Partner with Plane**: Official partnership for enterprise features

---

## Estimated Total Implementation Time

| Phase | Duration | Team Size |
|-------|----------|-----------|
| Phase 1: Security Foundation | 12-16 weeks | 2-3 developers |
| Phase 2: Access Control | 10-14 weeks | 2 developers |
| Phase 3: Advanced PM | 8-12 weeks | 2 developers |
| Phase 4: Automation & Analytics | 12-16 weeks | 2-3 developers |
| Phase 5: Advanced Features | 16+ weeks | 2-3 developers |

**Total: 58-74 weeks (14-18 months) with full team**

For a single developer: **3-4 years of full-time work**

---

## Quick Start: Easiest Wins

If you want to start small, these features provide good ROI with lower complexity:

1. **Password Policies** (1 week) - Immediate security improvement
2. **Workspace Activity Logs** (2-3 weeks) - Basic audit trail
3. **Two-Factor Authentication** (2-3 weeks) - Critical security feature
4. **Project Templates** (2-3 weeks) - High user value
5. **Page Templates** (1-2 weeks) - Easy knowledge management improvement

---

## Additional Resources

### Official Plane Documentation
- [SAML Setup Guide](https://plane.so/docs) - Reference for expected functionality
- [API Documentation](https://plane.so/api) - For automation and integrations
- [Deployment Guide](https://plane.so/deploy) - Self-hosting best practices

### Open Source Examples
- **Keycloak**: SAML/OIDC implementation reference
- **GitLab**: Comprehensive RBAC example
- **Linear**: Automation and workflow inspiration

---

## Conclusion

The Plane Community Edition codebase is **well-architected** with clear separation between tiers, making enterprise feature implementation **feasible but time-intensive**. The licensing infrastructure exists, but actual enterprise features require substantial development.

**Recommended Path Forward:**
1. ✅ Start with **Phase 1 (Security)** - highest enterprise value
2. ✅ Implement basic **licensing/feature gate system** first
3. ✅ Build **SAML** before OIDC (more common in enterprises)
4. ✅ Add **RBAC** before GAC (80% of use cases)
5. ⚠️ Consider legal/business model before full implementation

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-20  
**Author**: Gemini Analysis  
**Codebase Analyzed**: Plane Community Edition (Self-hosted)
