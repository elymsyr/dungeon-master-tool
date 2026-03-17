# Dungeon Master Tool — Monetization Implementation Roadmap

> **Version:** 1.0
> **Date:** March 17, 2026
> **Status:** Draft — Pending founder review
> **Companion documents:**
> - `docs/MONETIZATION_STRATEGY.md` — Pricing strategy and market positioning (Turkish)
> - `docs/SPRINT_MAP.md` — Sprint-by-sprint online development plan
> - `docs/DEVELOPMENT_REPORT.md` — Architecture, security, and deployment specifications
> **Scope:** 12-month phased implementation plan for monetizing the Dungeon Master Tool hosted online service

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Phase 1: Foundation (Months 1-3)](#2-phase-1-foundation-months-1-3)
3. [Phase 2: Closed Alpha (Months 3-5)](#3-phase-2-closed-alpha-months-3-5)
4. [Phase 3: Open Beta (Months 5-8)](#4-phase-3-open-beta-months-5-8)
5. [Phase 4: General Availability (Months 8-10)](#5-phase-4-general-availability-months-8-10)
6. [Phase 5: Growth (Months 10-12+)](#6-phase-5-growth-months-10-12)
7. [Revenue Scenarios](#7-revenue-scenarios)
8. [Decision Log Template](#8-decision-log-template)
9. [Risk Register](#9-risk-register)
10. [Key Dependencies](#10-key-dependencies)

---

## 1. Executive Summary

### 1.1 Purpose

This document translates the Dungeon Master Tool monetization strategy into a concrete, time-bound implementation plan. It maps every monetization milestone to the existing online development sprint timeline, identifies technical prerequisites, establishes decision gates, and provides financial projections under three scenarios.

The core business model is **Open-Core + Hosted SaaS**:

- **Offline Desktop** remains free forever.
- **Self-Hosted Online** is free with community support for technically capable users.
- **Official Hosted Online** is the paid subscription channel and primary revenue stream.

The guiding principle: **charge for comfort, reliability, operations, and time savings — not for creative tools.**

### 1.2 Timeline Overview

| Phase | Period | Key Milestone |
|-------|--------|---------------|
| Phase 1: Foundation | Months 1-3 (Mar - May 2026) | Entitlement data model, feature flags, metering, license audit |
| Phase 2: Closed Alpha | Months 3-5 (May - Jul 2026) | Plan guards, trial system, telemetry dashboard, 50-DM alpha group |
| Phase 3: Open Beta | Months 5-8 (Jul - Oct 2026) | Payment integration, Founding DM program, A/B price testing |
| Phase 4: General Availability | Months 8-10 (Oct - Dec 2026) | Full plan enforcement, annual plans, self-hosted release, support ops |
| Phase 5: Growth | Months 10-12+ (Dec 2026 - Mar 2027+) | Marketplace, creator program, enterprise licensing, Team tier |

### 1.3 Revenue Targets (12-Month)

| Scenario | Month 12 MRR | Month 12 Cumulative Revenue |
|----------|-------------|---------------------------|
| Optimistic | $8,400 - $11,200 | $52,000 - $70,000 |
| Base | $4,200 - $5,600 | $26,000 - $35,000 |
| Pessimistic | $1,400 - $2,100 | $9,000 - $13,000 |

### 1.4 Key Milestones

| Milestone | Target Date | Go/No-Go Gate |
|-----------|-------------|---------------|
| M1: Entitlement schema deployed | End of Month 2 | Schema review + integration test pass |
| M2: First alpha session with plan guard | End of Month 4 | 50-DM alpha cohort recruited |
| M3: First payment processed | End of Month 6 | Stripe/Paddle integration certified |
| M4: Founding DM program launched | Month 7 | Minimum 100 waitlist signups |
| M5: GA pricing enforced | Month 9 | 30-day beta health metrics pass |
| M6: Marketplace beta | Month 11 | Creator SDK documented + 5 launch packs |
| M7: Break-even (base scenario) | Month 10-14 | Infrastructure cost < subscription revenue |

### 1.5 Critical Path

The monetization roadmap has a hard dependency on the online development sprints:

```
Sprint 1-2 (Phase 0)     Sprint 3-4 (Phase 1)     Sprint 5-6 (Phase 2)     Sprint 7-8 (Phase 3-4)
UI + EventManager    -->  Auth + Session Gateway --> Sync + Reconnect    --> Features + Self-Host
                               |                         |                        |
                     Entitlement schema design    Plan guard impl         Payment integration
                     Feature flag infra           Trial system            GA enforcement
                     License audit                Telemetry dashboard     Support operations
```

Phase 0 (Sprints 1-2) must be completed before any monetization infrastructure work begins. This is a non-negotiable prerequisite established in the Development Report.

---

## 2. Phase 1: Foundation (Months 1-3)

**Calendar:** March 2026 - May 2026
**Overlaps with:** Online Sprints 1-4 (Phase 0 + Phase 1)
**Objective:** Build the technical and legal foundation for paid services without impacting the free offline experience.

### 2.1 Entitlement Data Model Design

The entitlement system lives within the `identity` bounded context (as defined in the Development Report, Section 4.2). Five tables form the billing and entitlement backbone:

#### 2.1.1 `plans` Table

Defines available subscription tiers.

```sql
CREATE TABLE plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            VARCHAR(50) UNIQUE NOT NULL,      -- 'free', 'starter', 'pro', 'creator'
    display_name    VARCHAR(100) NOT NULL,
    description     TEXT,
    price_monthly   DECIMAL(10,2),                    -- NULL for free
    price_annual    DECIMAL(10,2),                    -- NULL for free
    currency        VARCHAR(3) DEFAULT 'USD',
    is_active       BOOLEAN DEFAULT TRUE,
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

Seed data for v1:

| slug | display_name | price_monthly | price_annual |
|------|-------------|--------------|-------------|
| `free` | Free (Offline + Community) | NULL | NULL |
| `starter` | Hosted Starter | 6.99 - 8.99 | 71.28 - 91.68 |
| `pro` | Hosted Pro | 11.99 - 14.99 | 122.30 - 152.90 |

Final pricing within the range will be determined during Phase 3 A/B testing.

#### 2.1.2 `subscriptions` Table

Tracks active and historical subscriptions.

```sql
CREATE TABLE subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    plan_id             UUID NOT NULL REFERENCES plans(id),
    status              VARCHAR(20) NOT NULL DEFAULT 'active',
                        -- active, trialing, past_due, canceled, expired
    payment_provider    VARCHAR(20),                  -- 'stripe', 'paddle', NULL
    provider_sub_id     VARCHAR(255),                 -- External subscription ID
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end  TIMESTAMPTZ NOT NULL,
    trial_start         TIMESTAMPTZ,
    trial_end           TIMESTAMPTZ,
    cancel_at           TIMESTAMPTZ,                  -- Scheduled cancellation date
    canceled_at         TIMESTAMPTZ,                  -- Actual cancellation timestamp
    founding_dm         BOOLEAN DEFAULT FALSE,        -- Lifetime discount flag
    founding_discount   DECIMAL(5,2) DEFAULT 0,       -- Percentage discount
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
```

#### 2.1.3 `entitlements` Table

Maps active rights to users based on their subscription.

```sql
CREATE TABLE entitlements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id),
    feature_key     VARCHAR(100) NOT NULL,
                    -- 'hosted_session', 'concurrent_sessions', 'asset_storage_mb',
                    -- 'backup_enabled', 'backup_retention_days', 'priority_support',
                    -- 'advanced_restore', 'session_management_tools'
    value_type      VARCHAR(20) NOT NULL DEFAULT 'boolean',
                    -- 'boolean', 'integer', 'string'
    value_boolean   BOOLEAN,
    value_integer   INTEGER,
    value_string    VARCHAR(255),
    granted_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,                      -- NULL = no expiry (follows subscription)
    UNIQUE(subscription_id, feature_key)
);

CREATE INDEX idx_entitlements_user ON entitlements(user_id);
CREATE INDEX idx_entitlements_feature ON entitlements(feature_key);
```

Entitlement matrix per plan:

| feature_key | Free | Starter | Pro |
|-------------|------|---------|-----|
| `hosted_session` | false | true | true |
| `concurrent_sessions` | 0 | 1 | 3 |
| `asset_storage_mb` | 0 | 500 | 2000 |
| `backup_enabled` | false | true | true |
| `backup_retention_days` | 0 | 7 | 30 |
| `priority_support` | false | false | true |
| `advanced_restore` | false | false | true |
| `session_management_tools` | false | false | true |

#### 2.1.4 `usage_counters` Table

Tracks resource consumption for quota enforcement.

```sql
CREATE TABLE usage_counters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    counter_key     VARCHAR(100) NOT NULL,
                    -- 'active_sessions', 'storage_used_mb', 'bandwidth_used_mb',
                    -- 'backup_count_month', 'api_calls_hour'
    current_value   BIGINT DEFAULT 0,
    limit_value     BIGINT,                           -- NULL = unlimited
    period_start    TIMESTAMPTZ,                      -- For periodic counters
    period_end      TIMESTAMPTZ,
    last_updated    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, counter_key)
);

CREATE INDEX idx_usage_counters_user ON usage_counters(user_id);
```

#### 2.1.5 `billing_events` Table

Immutable audit log for all billing-related actions.

```sql
CREATE TABLE billing_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    subscription_id UUID REFERENCES subscriptions(id),
    event_type      VARCHAR(50) NOT NULL,
                    -- 'subscription_created', 'subscription_renewed',
                    -- 'subscription_canceled', 'subscription_expired',
                    -- 'trial_started', 'trial_ended', 'trial_converted',
                    -- 'payment_succeeded', 'payment_failed',
                    -- 'plan_upgraded', 'plan_downgraded',
                    -- 'founding_dm_applied', 'refund_issued',
                    -- 'entitlement_granted', 'entitlement_revoked',
                    -- 'usage_limit_reached', 'usage_limit_warning'
    provider_event_id VARCHAR(255),                   -- Stripe/Paddle event ID
    metadata        JSONB DEFAULT '{}',               -- Event-specific data
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_billing_events_user ON billing_events(user_id);
CREATE INDEX idx_billing_events_type ON billing_events(event_type);
CREATE INDEX idx_billing_events_created ON billing_events(created_at);
```

#### 2.1.6 Alembic Migration Plan

The entitlement tables should be introduced as a single Alembic migration (e.g., `002_entitlements.py`) after the initial migration that creates `users`, `sessions`, and `participants` (Sprint 3). This keeps the migration chain clean and allows the auth/session foundation to stabilize first.

**Sequencing:**
1. `001_initial.py` — users, sessions, participants (Sprint 3)
2. `002_entitlements.py` — plans, subscriptions, entitlements, usage_counters, billing_events (Phase 1)
3. Future migrations for marketplace, creator program, etc. (Phase 5)

### 2.2 Feature Flag Infrastructure

Feature flags serve two distinct purposes in the monetization system:

1. **Global rollout control** — Enable or disable features across the entire platform.
2. **Per-user entitlement gating** — Allow or deny features based on the user's subscription.

The two-layer system described in the Monetization Strategy (Section 8.3) works as follows:

```
Request arrives
    |
    v
[Feature Flag Check] -- Is the feature globally enabled?
    |                        |
    | YES                    | NO --> Return "feature unavailable"
    v
[Entitlement Check] -- Does this user's subscription grant access?
    |                        |
    | YES                    | NO --> Return 402/403 with upgrade prompt
    v
[Usage Counter Check] -- Is the user within their quota?
    |                        |
    | YES                    | NO --> Return 429 with limit info
    v
[Allow Request]
```

#### 2.2.1 Feature Flag Registry

The following flags must be implemented during Phase 1:

| Flag Key | Type | Default | Description |
|----------|------|---------|-------------|
| `online_session_enabled` | boolean | false | Master switch for online session functionality |
| `hosted_plans_visible` | boolean | false | Show pricing page and plan selection UI |
| `trial_enabled` | boolean | false | Allow 14-day free trial activation |
| `payment_enabled` | boolean | false | Accept real payment transactions |
| `founding_dm_enabled` | boolean | false | Enable Founding DM discount program |
| `marketplace_enabled` | boolean | false | Show marketplace UI (Phase 5) |
| `backup_enabled` | boolean | false | Enable hosted backup/restore endpoints |
| `advanced_session_tools` | boolean | false | Enable Pro-tier session management tools |

#### 2.2.2 Implementation Approach

Feature flags should be stored in a lightweight configuration layer. For the initial implementation:

- Store flags in a `feature_flags` table in PostgreSQL.
- Cache flags in Redis with a 60-second TTL to avoid per-request database queries.
- Expose a `GET /v1/admin/flags` endpoint for the operator to view current states.
- Expose a `PUT /v1/admin/flags/{key}` endpoint for the operator to toggle flags.
- Client-side: fetch active flags on login and cache locally.

```sql
CREATE TABLE feature_flags (
    key         VARCHAR(100) PRIMARY KEY,
    enabled     BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_by  VARCHAR(100)
);
```

#### 2.2.3 Entitlement Service API

The entitlement service exposes a simple internal API consumed by all guard middleware:

```python
# server/billing/entitlement_service.py

class EntitlementService:
    """
    Central service for checking user entitlements.
    Used by API guards and WebSocket middleware.
    """

    async def check_feature(self, user_id: str, feature_key: str) -> bool:
        """Check if user has access to a boolean feature."""
        ...

    async def get_limit(self, user_id: str, feature_key: str) -> int | None:
        """Get the integer limit for a feature. Returns None if unlimited."""
        ...

    async def check_usage(self, user_id: str, counter_key: str) -> UsageStatus:
        """Check current usage against limit. Returns (current, limit, allowed)."""
        ...

    async def increment_usage(self, user_id: str, counter_key: str, amount: int = 1) -> UsageStatus:
        """Increment a usage counter. Returns updated status."""
        ...

    async def get_active_entitlements(self, user_id: str) -> list[Entitlement]:
        """Get all active entitlements for a user."""
        ...

    async def grant_trial(self, user_id: str, plan_slug: str, days: int = 14) -> Subscription:
        """Create a trial subscription with full entitlements."""
        ...
```

### 2.3 Usage Metering Event Design

Usage metering captures resource consumption events for quota enforcement, billing accuracy, and infrastructure cost analysis.

#### 2.3.1 Metered Events

| Event | Counter Key | Measurement | Trigger |
|-------|------------|-------------|---------|
| Session created | `active_sessions` | Count (increment) | `POST /v1/sessions` |
| Session closed | `active_sessions` | Count (decrement) | `POST /v1/sessions/{id}/close` |
| Asset uploaded | `storage_used_mb` | Size in MB (increment) | `POST /v1/assets/presign` confirmation |
| Asset deleted | `storage_used_mb` | Size in MB (decrement) | Asset removal endpoint |
| Backup created | `backup_count_month` | Count (increment, resets monthly) | `POST /v1/sessions/{id}/backup` |
| Bandwidth consumed | `bandwidth_used_mb` | Size in MB (increment) | Asset download via signed URL |
| API calls | `api_calls_hour` | Count (increment, resets hourly) | Any authenticated API request |
| WebSocket events | `ws_events_hour` | Count (increment, resets hourly) | Any WebSocket event emitted |

#### 2.3.2 Metering Architecture

```
API Request / WS Event
    |
    v
[Business Logic] -- Execute the action
    |
    v
[Metering Middleware] -- Emit usage event asynchronously
    |
    v
[Usage Counter Update] -- Redis atomic increment (INCRBY)
    |
    v
[Periodic Flush] -- Flush Redis counters to PostgreSQL (every 5 minutes)
    |
    v
[Quota Check] -- Compare current value to limit_value
    |
    v
[Alert / Throttle] -- If approaching limit: warn. If exceeded: deny.
```

Key design decisions:
- **Redis-first**: Counters are updated atomically in Redis for performance. PostgreSQL is the durable store, synced periodically.
- **Async emission**: Metering events are emitted asynchronously and must never block the main request path.
- **Idempotent updates**: Each metering event carries a unique ID. Duplicate processing must not double-count.
- **Soft limits vs. hard limits**: Storage and bandwidth use soft limits (warn at 80%, deny at 100%). Session count uses hard limits (deny immediately at limit).

#### 2.3.3 Limit Warning Thresholds

| Threshold | Action |
|-----------|--------|
| 80% of limit | In-app notification: "You are approaching your [resource] limit." |
| 95% of limit | Email notification + in-app banner: "Upgrade to continue using [resource]." |
| 100% of limit | Hard deny + upgrade prompt: "You have reached your [resource] limit. Upgrade to [next plan] for more." |

### 2.4 License and Asset Inventory Audit

The repository LICENSE notes indicate that some bundled artistic assets carry `CC BY-NC` (Creative Commons Attribution-NonCommercial) licensing. This creates a legal risk for any paid/hosted service.

#### 2.4.1 Audit Scope

The audit must cover every non-code asset distributed with or referenced by the application:

| Asset Category | Location | Risk Level | Action Required |
|----------------|----------|------------|-----------------|
| Map textures and templates | `assets/maps/` | High | Verify license for each file |
| Token images | `assets/tokens/` | High | Verify license for each file |
| UI icons and graphics | `assets/ui/` | Medium | Verify license; most likely Apache/MIT |
| Sound effects | `assets/sounds/` | High | Verify license for each file |
| Font files | `assets/fonts/` | Medium | Verify OFL/Apache license |
| Sample campaign content | `campaigns/sample/` | High | Verify all included images and PDFs |
| Theme CSS assets | `themes/` | Low | Code-only, no asset risk |

#### 2.4.2 Audit Process

1. **Inventory**: Create a spreadsheet listing every non-code file with: filename, file type, source/origin, current license, commercial use allowed (yes/no).
2. **Classification**: Mark each asset as:
   - `CLEAR` — License explicitly permits commercial use.
   - `BLOCKED` — License prohibits commercial use (CC BY-NC, personal use only, etc.).
   - `UNKNOWN` — License not documented or ambiguous.
3. **Remediation**:
   - `BLOCKED` assets: Replace with commercially licensed alternatives OR remove from the distribution package.
   - `UNKNOWN` assets: Contact the original creator for clarification OR replace preemptively.
4. **Separation**: Establish a clear boundary between:
   - `Core code license` (project's own license) — applies to all Python source code.
   - `Bundled asset licenses` — each asset carries its own license, documented in an `ASSET_LICENSES.md` file.
5. **Attribution**: Add an in-app attribution screen accessible from the About dialog that lists all third-party assets and their licenses.
6. **Distribution packaging**: Ensure the installer/build script (`installer/build.py`) excludes any `BLOCKED` assets from commercial distribution packages.

#### 2.4.3 Blocking Condition

**No paid hosted service may be launched until the license audit is complete and all `BLOCKED`/`UNKNOWN` assets are resolved.** This is a hard prerequisite for Phase 3 (Open Beta) where payment processing begins.

Timeline:
- Month 1: Begin inventory and classification.
- Month 2: Complete remediation for `BLOCKED` assets.
- Month 3: Final audit review and sign-off.

### 2.5 Pricing Page Design and Plan Differentiation Copy

The pricing page is a critical conversion surface. It must clearly communicate the value proposition of each tier without making the free tier feel incomplete.

#### 2.5.1 Positioning Framework

The pricing page messaging follows the strategic principle: "Offline-first power is yours; online convenience is on us."

| Element | Free | Starter | Pro |
|---------|------|---------|-----|
| **Headline** | "Full Creative Power" | "Go Online" | "Run Like a Pro" |
| **Subheadline** | "Everything you need for local campaigns" | "Host sessions with zero setup" | "Unlimited sessions, priority everything" |
| **Target DM** | Solo prep, local projection | Weekly game night DM | Multi-campaign, serious DM |
| **CTA** | "Download Free" | "Start 14-Day Trial" | "Start 14-Day Trial" |

#### 2.5.2 Feature Comparison Table (Pricing Page)

| Feature | Free | Starter | Pro |
|---------|------|---------|-----|
| Offline campaign management | Unlimited | Unlimited | Unlimited |
| Entity types (15 types) | All | All | All |
| Mind map, world map, combat tracker | Full | Full | Full |
| Audio engine (MusicBrain) | Full | Full | Full |
| Self-hosted online (community) | Yes | Yes | Yes |
| **Hosted online sessions** | -- | 1 concurrent | 3 concurrent |
| **Asset cloud storage** | -- | 500 MB | 2 GB |
| **Automated backups** | -- | Daily (7-day retention) | Daily (30-day retention) |
| **Fast restore** | -- | Standard | Priority |
| **Support** | Community (Discord/Issues) | Email (best effort) | Priority email + Discord |
| **Session management tools** | -- | Basic | Advanced |
| **Price** | Free forever | $6.99-$8.99/mo | $11.99-$14.99/mo |
| **Annual price** | -- | ~$5.94-$7.64/mo | ~$10.19-$12.74/mo |

#### 2.5.3 Copy Principles

1. **Never frame free as "limited."** Free is complete for offline use. Online features are additive.
2. **Lead with the DM's pain point.** "Stop juggling Discord screen shares" beats "Get cloud hosting."
3. **"Players join free" must be prominently displayed.** This removes the biggest friction point (convincing 4-6 players to pay).
4. **Show the math.** Compare to alternatives: "Less than the cost of a single battle map pack per month."
5. **Transparent cancellation.** "Cancel anytime. Your offline campaigns are always yours."

#### 2.5.4 Design Deliverables

| Deliverable | Owner | Deadline |
|-------------|-------|----------|
| Wireframe: pricing page layout | UI/UX | End of Month 1 |
| Copy draft: all plan descriptions | Product | End of Month 1 |
| Visual design: pricing cards | UI/UX | End of Month 2 |
| Implementation: in-app pricing view | Desktop Dev | End of Month 3 |
| A/B test variants (2-3 price points) | Product | End of Month 5 |

### 2.6 Phase 1 Deliverables

| # | Deliverable | Format | Owner | Exit Criterion |
|---|-------------|--------|-------|----------------|
| D1.1 | Entitlement data model (SQL + Alembic migration) | Code | Backend | Migration runs cleanly; schema review passed |
| D1.2 | Feature flag table + admin endpoints | Code | Backend | Flags can be toggled via API; cached in Redis |
| D1.3 | EntitlementService with unit tests | Code | Backend | 90%+ test coverage on service methods |
| D1.4 | Usage metering middleware (Redis counters) | Code | Backend | Counters increment/decrement correctly under load |
| D1.5 | License/asset audit spreadsheet | Document | Product | All assets classified; no UNKNOWN remaining |
| D1.6 | Asset remediation plan | Document | Product | Replacement assets identified for all BLOCKED items |
| D1.7 | Pricing page wireframe + copy | Design + Document | UI/UX + Product | Stakeholder sign-off |
| D1.8 | Plan seed data + entitlement matrix | Code + Document | Backend + Product | Plans queryable via API |

### 2.7 Phase 1 Exit Criteria

All of the following must be true before proceeding to Phase 2:

- [ ] Entitlement schema is deployed to staging and passes integration tests.
- [ ] Feature flags can be toggled without deployment (runtime configuration).
- [ ] Usage counters accurately track session creation/closure in automated tests.
- [ ] License audit has zero `UNKNOWN` classifications remaining.
- [ ] All `BLOCKED` assets have identified replacements (even if not yet swapped).
- [ ] Pricing page wireframe and copy are reviewed and approved.
- [ ] Online Sprint 3 (Auth/Session Gateway) is complete or on track.

### 2.8 Phase 1 Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R1.1 | Entitlement schema design requires multiple iterations | Medium | Medium | Time-box schema design to 2 weeks; use feature flags to decouple schema from enforcement |
| R1.2 | License audit reveals widespread NC-licensed assets | Medium | High | Begin audit in Week 1; maintain a replacement asset shortlist proactively |
| R1.3 | Sprint 3 (Auth) delays impact entitlement integration | Low | High | Entitlement schema design can proceed independently; only integration requires auth |
| R1.4 | Feature flag caching creates stale state | Low | Medium | 60-second TTL + manual cache invalidation endpoint |
| R1.5 | Pricing strategy not finalized, blocking page design | Medium | Low | Design with placeholder price ranges; final prices set during Phase 3 A/B tests |

---

## 3. Phase 2: Closed Alpha (Months 3-5)

**Calendar:** May 2026 - July 2026
**Overlaps with:** Online Sprints 4-6 (Phase 1 + Phase 2)
**Objective:** Implement plan enforcement guards, build a trial system, deploy telemetry, and validate with a 50-DM closed alpha group.

### 3.1 Plan Guard Implementation

Plan guards enforce subscription entitlements at the API and WebSocket layers. They are the runtime expression of the entitlement data model built in Phase 1.

#### 3.1.1 Guard Points

| Endpoint / Action | Guard Logic | Deny Response |
|-------------------|-------------|---------------|
| `POST /v1/sessions` (create) | Check `hosted_session` entitlement + `concurrent_sessions` limit | 402: "Upgrade to create hosted sessions" |
| `WS: join_session` (concurrent) | Check `active_sessions` usage counter against `concurrent_sessions` limit | 403: "Session limit reached" |
| `POST /v1/assets/presign` (upload) | Check `storage_used_mb` counter against `asset_storage_mb` limit | 413: "Storage limit reached. Upgrade for more space." |
| `POST /v1/sessions/{id}/backup` | Check `backup_enabled` entitlement + `backup_count_month` counter | 402: "Backup requires Starter plan or higher" |
| `POST /v1/sessions/{id}/restore` | Check `advanced_restore` entitlement for priority queue | 200 with `queue_position` (standard) or immediate (Pro) |
| `GET /v1/sessions/{id}/tools` | Check `session_management_tools` entitlement | 402: "Advanced tools require Pro plan" |

#### 3.1.2 Guard Middleware Architecture

```python
# server/billing/guard.py

from fastapi import HTTPException, Depends, Request
from server.billing.entitlement_service import EntitlementService

def require_entitlement(feature_key: str):
    """
    FastAPI dependency that checks if the authenticated user
    has the specified entitlement.
    """
    async def _check(
        request: Request,
        entitlement_service: EntitlementService = Depends(get_entitlement_service),
        user = Depends(get_current_user),
    ):
        # Step 1: Check global feature flag
        if not await feature_flag_enabled(feature_key):
            raise HTTPException(503, detail={
                "error": {"code": "FEATURE_UNAVAILABLE",
                          "message": "This feature is not yet available."}
            })

        # Step 2: Check user entitlement
        if not await entitlement_service.check_feature(user.id, feature_key):
            raise HTTPException(402, detail={
                "error": {"code": "UPGRADE_REQUIRED",
                          "message": f"This feature requires a paid plan.",
                          "upgrade_url": "/pricing"}
            })

        return user

    return _check


def require_usage_within_limit(counter_key: str):
    """
    FastAPI dependency that checks if the user is within their usage quota.
    """
    async def _check(
        request: Request,
        entitlement_service: EntitlementService = Depends(get_entitlement_service),
        user = Depends(get_current_user),
    ):
        status = await entitlement_service.check_usage(user.id, counter_key)
        if not status.allowed:
            raise HTTPException(429, detail={
                "error": {"code": "USAGE_LIMIT_REACHED",
                          "message": f"You have reached your {counter_key} limit.",
                          "current": status.current,
                          "limit": status.limit,
                          "upgrade_url": "/pricing"}
            })
        return user

    return _check
```

#### 3.1.3 WebSocket Guard Integration

WebSocket events are guarded at the `ws/middleware.py` layer:

```python
# server/ws/middleware.py (addition)

async def check_ws_entitlement(sid, event_type, user_id):
    """
    Called before processing any WebSocket event.
    Returns True if allowed, raises disconnect if not.
    """
    # Map event types to required entitlements
    ENTITLEMENT_MAP = {
        "create_session": "hosted_session",
        "upload_asset": "asset_storage_mb",
        "create_backup": "backup_enabled",
    }

    required = ENTITLEMENT_MAP.get(event_type)
    if required:
        if not await entitlement_service.check_feature(user_id, required):
            await sio.emit("entitlement_error", {
                "code": "UPGRADE_REQUIRED",
                "feature": required,
                "upgrade_url": "/pricing"
            }, room=sid)
            return False
    return True
```

#### 3.1.4 Client-Side Guard UX

When a guard denies a request, the client must handle it gracefully:

1. Display a non-intrusive notification explaining the limitation.
2. Offer a clear path to upgrade (link to pricing page or in-app upgrade dialog).
3. Never crash or show a raw error message.
4. Cache the user's entitlement state locally to avoid unnecessary server round-trips for known limits.

### 3.2 Trial System (14-Day Free Trial)

The trial system allows new users to experience the full Starter or Pro plan for 14 days without providing payment information.

#### 3.2.1 Trial Rules

| Rule | Value |
|------|-------|
| Trial duration | 14 calendar days |
| Credit card required | No (reduces friction; revisit if abuse is detected) |
| Trial plan level | Starter (full Starter entitlements) |
| One trial per account | Yes (enforced by `trial_start` on `subscriptions` table) |
| Trial extension | Not available (creates urgency) |
| Post-trial behavior | Graceful downgrade to Free; hosted sessions become read-only for 7 days, then archived |
| Trial-to-paid conversion | Prompted at day 7, day 12, and day 14 |

#### 3.2.2 Trial Lifecycle

```
User registers
    |
    v
[Trial Available?] -- Has this user ever had a trial?
    |                      |
    | NO                   | YES --> No trial offered; show pricing
    v
[Start Trial] -- Create subscription with status='trialing'
    |
    v
[Day 1-6: Full access, no prompts]
    |
    v
[Day 7: First conversion prompt]
    |  "Your trial is halfway through. Lock in Founding DM pricing."
    v
[Day 8-11: Full access, subtle banner]
    |
    v
[Day 12: Second conversion prompt]
    |  "3 days left. Your sessions and data will be preserved if you upgrade."
    v
[Day 13: Persistent banner]
    |
    v
[Day 14: Trial expires]
    |
    v
[Grace Period: 7 days]
    |  Sessions read-only. Data accessible but not editable.
    |  "Your trial has ended. Upgrade to continue hosting sessions."
    v
[Day 21: Archive]
    |  Hosted session data archived. Offline data unaffected.
    |  "Your hosted data has been archived. Upgrade to restore."
```

#### 3.2.3 Anti-Abuse Measures

| Measure | Implementation |
|---------|---------------|
| One trial per email | Enforce at `subscriptions` table level |
| One trial per device fingerprint | Optional; implement if email abuse detected |
| Rate limiting on registration | 3 registrations per IP per hour |
| Disposable email detection | Optional; implement if abuse detected |

### 3.3 Telemetry Dashboard

The telemetry dashboard provides real-time visibility into conversion, performance, and infrastructure cost.

#### 3.3.1 Dashboard Panels

**Panel 1: Conversion Funnel**

| Metric | Source | Visualization |
|--------|--------|---------------|
| Registrations / day | `billing_events` WHERE type = 'trial_started' | Line chart |
| Trial activations / day | `subscriptions` WHERE status = 'trialing' | Line chart |
| Trial-to-paid conversion rate | `billing_events` WHERE type = 'trial_converted' / trials started | Percentage gauge |
| Paid churn rate (monthly) | Canceled subscriptions / active subscriptions | Percentage gauge |
| Active subscribers by plan | `subscriptions` GROUP BY plan | Stacked bar |
| MRR (Monthly Recurring Revenue) | SUM of active subscription amounts | Single value + trend |
| ARPPU (Avg Revenue Per Paying User) | MRR / paying users | Single value |

**Panel 2: Performance and Reliability**

| Metric | Source | Target | Visualization |
|--------|--------|--------|---------------|
| P95 event latency | Prometheus histogram | < 120ms | Heatmap |
| 5MB map first load time | Prometheus histogram | < 3s | Line chart |
| Reconnect success rate | Server logs | > 95% | Percentage gauge |
| Session drop rate | Server logs | < 2% | Line chart |
| WebSocket connection count | Redis `SCARD` | -- | Real-time gauge |
| Asset CDN hit rate | MinIO/Nginx logs | > 80% | Percentage gauge |

**Panel 3: Infrastructure Cost**

| Metric | Source | Visualization |
|--------|--------|---------------|
| Server compute cost / day | Cloud provider API or manual input | Line chart |
| Storage cost / GB | MinIO metrics | Single value |
| Bandwidth cost / GB | Provider API | Single value |
| Cost per active user | Total infra cost / active users | Single value + trend |
| Gross margin per subscriber | ARPPU - cost per user | Single value + trend |

#### 3.3.2 Technology

- **Metrics collection:** Prometheus (already planned in the tech stack)
- **Dashboards:** Grafana with pre-built panels for each section above
- **Business metrics:** Custom Grafana dashboard querying PostgreSQL directly for billing data
- **Alerting:** Grafana alerting for:
  - P95 latency > 200ms for 5 minutes
  - Session drop rate > 5% for 15 minutes
  - Conversion rate drops > 50% week-over-week
  - Infrastructure cost exceeds budget threshold

### 3.4 50-DM Closed Alpha Test Group

The closed alpha validates the monetization infrastructure under real usage conditions before any payment processing is introduced.

#### 3.4.1 Alpha Cohort Selection Criteria

| Criterion | Rationale |
|-----------|-----------|
| Existing DM Tool user (offline) | Familiar with the product; can compare online vs. offline |
| Runs regular game sessions (weekly or bi-weekly) | Generates realistic usage patterns |
| Willing to provide structured feedback | NPS surveys, bug reports, feature requests |
| Diverse connection quality (broadband, mobile, international) | Tests latency and reconnect under varied conditions |
| Mix of technical and non-technical DMs | Validates that UX is accessible |

Target: 50 DMs, each running at least one session with 2-5 players.

#### 3.4.2 Alpha Program Structure

| Week | Activity |
|------|----------|
| Week 1 | Onboarding: install, register, create first session |
| Week 2 | First live session with players; structured feedback form |
| Week 3 | Second session; focus on reconnect and stability |
| Week 4 | Third session; introduce trial/plan guard (soft enforcement, no real payment) |
| Week 5-6 | Open play; collect telemetry; NPS survey |
| Week 7-8 | Exit interviews with 10 selected DMs; compile findings |

#### 3.4.3 Alpha Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Onboarding completion rate | > 90% | Registration-to-first-session |
| Session stability (no crashes) | > 95% | Sessions completed without fatal error |
| Reconnect success rate | > 90% | Successful reconnects / total disconnects |
| NPS score | > 30 | Post-alpha survey |
| Willingness to pay (self-reported) | > 40% of alpha DMs | Survey question: "Would you pay for this?" |
| Feature request overlap | Top 3 requests from > 30% of DMs | Categorized feedback |

### 3.5 Phase 2 Deliverables

| # | Deliverable | Format | Owner | Exit Criterion |
|---|-------------|--------|-------|----------------|
| D2.1 | Plan guard middleware (REST + WebSocket) | Code | Backend | All guard points tested with mock entitlements |
| D2.2 | Trial system (create, lifecycle, expiry, grace period) | Code | Backend + Desktop | Trial lifecycle passes end-to-end test |
| D2.3 | Client-side guard UX (notifications, upgrade prompts) | Code | Desktop Dev | UX review passed; no raw error messages shown |
| D2.4 | Telemetry dashboard (3 panels) | Grafana config | DevOps | All metrics populated with live or mock data |
| D2.5 | Alpha cohort recruited (50 DMs) | List | Product | 50 confirmed participants with signed NDA/feedback agreement |
| D2.6 | Alpha program run (8 weeks) | Report | Product + QA | Exit report with NPS, stability metrics, top feedback themes |
| D2.7 | Usage metering validated under alpha load | Test report | Backend + DevOps | Counters accurate within 1% after 8-week alpha |

### 3.6 Phase 2 Exit Criteria

All of the following must be true before proceeding to Phase 3:

- [ ] All plan guard points return correct HTTP status codes for free, trial, and paid users.
- [ ] Trial lifecycle (start, warn, expire, grace, archive) works end-to-end.
- [ ] Telemetry dashboard shows real data from the alpha cohort.
- [ ] Alpha NPS score is >= 30.
- [ ] Alpha session stability is >= 95%.
- [ ] Alpha willingness-to-pay is >= 40%.
- [ ] No critical or high-severity bugs remain from alpha feedback.
- [ ] License audit remediation is complete (all BLOCKED assets replaced or removed).
- [ ] Online Sprint 6 (Audio Sync and Performance) is complete or on track.

### 3.7 Phase 2 Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R2.1 | Alpha recruitment falls short of 50 DMs | Medium | Medium | Start recruitment in Month 2; leverage existing community channels; offer exclusive "Alpha Tester" badge |
| R2.2 | Plan guard creates false denials during alpha | Medium | High | Implement "soft enforcement" mode: log denials but allow the action during alpha |
| R2.3 | Trial system abuse (mass account creation) | Low | Medium | Rate limiting + one-trial-per-email constraint |
| R2.4 | Alpha DMs report low willingness to pay | Medium | High | Use alpha feedback to refine value proposition; do not proceed to payment integration until > 40% WTP |
| R2.5 | Telemetry overhead impacts latency | Low | Medium | Async metering; benchmark telemetry overhead < 5ms per request |
| R2.6 | Reconnect stability does not meet alpha targets | Medium | High | Prioritize reconnect fixes in Sprint 5-6; consider alpha extension if needed |

---

## 4. Phase 3: Open Beta (Months 5-8)

**Calendar:** July 2026 - October 2026
**Overlaps with:** Online Sprints 7-8 (Phase 3 + Phase 4)
**Objective:** Integrate payment processing, launch the Founding DM program, run A/B price tests, and prepare self-hosted documentation.

### 4.1 Payment Integration

#### 4.1.1 Provider Comparison: Stripe vs. Paddle

| Criterion | Stripe | Paddle |
|-----------|--------|--------|
| **Transaction fees** | 2.9% + $0.30 per transaction (US) | 5% + $0.50 per transaction |
| **International fees** | Additional 1-1.5% for cross-border | Included (Paddle is merchant of record) |
| **Tax handling** | Developer responsibility (Stripe Tax available at extra cost) | Paddle handles VAT/sales tax globally as MoR |
| **Subscription management** | Stripe Billing (built-in) | Paddle Billing (built-in) |
| **Payout** | Direct to bank account | Monthly payout after reserve |
| **Merchant of Record** | No (you are the MoR) | Yes (Paddle is the MoR) |
| **Integration complexity** | Moderate (well-documented API) | Lower (handles more out of the box) |
| **Desktop app integration** | Checkout via embedded browser/redirect | Checkout via overlay/redirect |
| **Free/open-source discount** | No special program | Potential for small indie discount |
| **Dispute handling** | Developer manages disputes | Paddle manages disputes |
| **Revenue recognition** | Developer responsibility | Paddle handles |
| **Regional pricing** | Manual configuration | Built-in purchasing power parity |
| **Ecosystem maturity** | Largest; extensive documentation | Smaller but growing; good for SaaS |

#### 4.1.2 Recommendation: Paddle (Primary), Stripe (Fallback)

**Rationale:**
1. **Merchant of Record status**: As a small project, handling global VAT/sales tax compliance is a significant operational burden. Paddle eliminates this entirely.
2. **Desktop app fit**: Paddle's overlay checkout works well for desktop applications that cannot embed a full web checkout flow.
3. **Lower operational overhead**: Dispute handling, revenue recognition, and tax filing are managed by Paddle.
4. **Trade-off**: Higher per-transaction fees (5% + $0.50 vs. 2.9% + $0.30). At the expected transaction volume (< 500 subscribers in year 1), the operational savings outweigh the fee difference.

**Migration path**: If transaction volume exceeds 1,000 subscribers, re-evaluate Stripe for its lower fees. The abstraction layer (below) makes this migration feasible.

#### 4.1.3 Payment Abstraction Layer

To avoid vendor lock-in, all payment logic goes through an abstraction:

```python
# server/billing/payment_provider.py

from abc import ABC, abstractmethod

class PaymentProvider(ABC):
    """Abstract payment provider interface."""

    @abstractmethod
    async def create_checkout_session(
        self, user_id: str, plan_slug: str, annual: bool = False
    ) -> CheckoutSession:
        """Create a checkout session and return the URL."""
        ...

    @abstractmethod
    async def cancel_subscription(self, provider_sub_id: str) -> None:
        """Cancel a subscription at period end."""
        ...

    @abstractmethod
    async def handle_webhook(self, payload: bytes, signature: str) -> WebhookEvent:
        """Validate and parse a webhook event from the provider."""
        ...

    @abstractmethod
    async def get_subscription_status(self, provider_sub_id: str) -> SubscriptionStatus:
        """Query the current subscription status from the provider."""
        ...


class PaddleProvider(PaymentProvider):
    """Paddle implementation."""
    ...

class StripeProvider(PaymentProvider):
    """Stripe implementation (fallback/future)."""
    ...
```

#### 4.1.4 Webhook Integration

The payment provider sends webhooks for subscription lifecycle events. These must be processed reliably:

| Webhook Event | Action |
|---------------|--------|
| `subscription.created` | Create `subscriptions` record; grant entitlements; log `billing_event` |
| `subscription.renewed` | Update `current_period_end`; log `billing_event` |
| `subscription.canceled` | Set `cancel_at`; log `billing_event`; schedule entitlement revocation |
| `subscription.past_due` | Set status to `past_due`; send email; log `billing_event` |
| `subscription.expired` | Revoke entitlements; downgrade to Free; log `billing_event` |
| `payment.succeeded` | Log `billing_event` with amount and currency |
| `payment.failed` | Log `billing_event`; retry notification; set `past_due` after 3 failures |
| `refund.issued` | Log `billing_event`; handle pro-rata entitlement adjustment |

Webhook processing must be idempotent (deduplication by `provider_event_id`).

#### 4.1.5 Payment Integration Timeline

| Week | Task |
|------|------|
| Week 1-2 | Payment abstraction layer + Paddle SDK integration |
| Week 3 | Webhook endpoint + event processing |
| Week 4 | Checkout flow in desktop client (Paddle overlay) |
| Week 5 | End-to-end test: register -> trial -> upgrade -> pay -> entitlements granted |
| Week 6 | Sandbox testing with test cards; edge cases (failed payment, refund, cancellation) |

### 4.2 Founding DM Pricing Program

The Founding DM program rewards early adopters with a lifetime discount, creating urgency and building a loyal initial subscriber base.

#### 4.2.1 Program Parameters

| Parameter | Value |
|-----------|-------|
| Program name | "Founding DM" |
| Eligibility | First 200 paying subscribers (not trial-only users) |
| Discount | 30% lifetime discount on monthly or annual plans |
| Duration | Discount applies for the lifetime of the subscription (as long as it remains active) |
| Transferable | No |
| Stack with annual discount | Yes (30% Founding + 15-20% annual = ~40-44% total) |
| Badge | In-app "Founding DM" badge displayed in session participant list |
| Waitlist | Open during alpha; converts to paid during Open Beta |

#### 4.2.2 Founding DM Pricing (with 30% Discount)

| Plan | Standard Monthly | Founding Monthly | Standard Annual (per mo) | Founding Annual (per mo) |
|------|-----------------|-----------------|------------------------|------------------------|
| Starter ($7.99 base) | $7.99 | $5.59 | $6.79 | $4.75 |
| Pro ($12.99 base) | $12.99 | $9.09 | $11.04 | $7.73 |

Note: Exact base prices will be determined by A/B testing. The table uses midpoint estimates.

#### 4.2.3 Founding DM Lifecycle

```
Waitlist signup (during Alpha/Beta)
    |
    v
Open Beta launch announcement
    |  "Founding DM slots are now available. 200 spots. First come, first served."
    v
User upgrades from trial or free to paid plan
    |
    v
[Slots remaining?]
    |              |
    | YES          | NO --> Standard pricing applied
    v
[Apply 30% discount]
    |  Set founding_dm = TRUE, founding_discount = 30.00 on subscription
    |  Log billing_event: 'founding_dm_applied'
    |  Grant "Founding DM" badge
    v
[Subscription active]
    |  Discount persists through renewals as long as subscription is active
    v
[If canceled and re-subscribed within 30 days]
    |  Founding DM status preserved (grace period)
    v
[If canceled and re-subscribed after 30 days]
    |  Founding DM status lost; standard pricing applies
```

#### 4.2.4 Marketing Collateral

| Asset | Description | Deadline |
|-------|-------------|----------|
| Waitlist landing page | Email capture + counter showing remaining spots | Month 5 |
| Email sequence (3 emails) | Waitlist confirmation, Beta launch, Last 50 spots warning | Month 6 |
| In-app banner | "Founding DM: 30% off forever. [X] spots remaining." | Month 6 |
| Discord announcement | Community channel post with FAQ | Month 6 |
| Badge design | Visual asset for Founding DM designation | Month 5 |

### 4.3 A/B Price Testing Methodology

A/B testing determines the optimal price point within the defined ranges (Starter: $6.99-$8.99, Pro: $11.99-$14.99).

#### 4.3.1 Test Design

| Parameter | Value |
|-----------|-------|
| Test type | Between-subjects (each user sees one price) |
| Assignment | Random, stratified by geography (NA, EU, Other) |
| Sample size | Minimum 100 users per variant per plan |
| Duration | 4-6 weeks per test cycle |
| Primary metric | Trial-to-paid conversion rate |
| Secondary metrics | Revenue per user, churn rate at 30 days, upgrade rate (Starter -> Pro) |
| Significance level | p < 0.05 |
| Minimum detectable effect | 5 percentage points in conversion rate |

#### 4.3.2 Test Variants

**Round 1: Starter Plan**

| Variant | Monthly Price | Annual Price (per mo) |
|---------|-------------|---------------------|
| A (Low) | $6.99 | $5.94 |
| B (Mid) | $7.99 | $6.79 |
| C (High) | $8.99 | $7.64 |

**Round 2: Pro Plan (run after Round 1 concludes)**

| Variant | Monthly Price | Annual Price (per mo) |
|---------|-------------|---------------------|
| A (Low) | $11.99 | $10.19 |
| B (Mid) | $12.99 | $11.04 |
| C (High) | $14.99 | $12.74 |

#### 4.3.3 Implementation

- Price variants are stored as plan attributes with a `variant_group` field.
- Users are assigned a variant at registration time (stored on their user record).
- The pricing page renders the assigned variant's prices.
- Telemetry tracks: page views, trial starts, trial conversions, and 30-day churn per variant.
- At test conclusion, the winning variant becomes the default for all new users. Existing users on other variants are grandfathered at their assigned price.

#### 4.3.4 Ethical Guardrails

1. **No price changes for existing subscribers.** Once a user subscribes at a price, that price is locked for them.
2. **Transparent communication.** If a user asks about pricing, support provides their assigned price without mentioning the test.
3. **No deceptive comparisons.** "Was $X, now $Y" is never used with A/B test prices.
4. **Geographic fairness.** Prices do not vary by geography within the same variant (purchasing power parity is a separate, explicit decision).

### 4.4 Self-Hosted Documentation and Community Support

The self-hosted path must be clearly documented to maintain the open-core commitment and prevent community backlash.

#### 4.4.1 Documentation Structure

| Document | Contents | Audience |
|----------|----------|----------|
| `SELF_HOST_GUIDE.md` | Step-by-step: Docker Compose, env vars, Nginx, TLS, DNS | Technical DMs |
| `SELF_HOST_FAQ.md` | Common issues, troubleshooting, performance tuning | Technical DMs |
| `SELF_HOST_ARCHITECTURE.md` | System diagram, component overview, data flow | Contributors |
| `SELF_HOST_UPGRADE.md` | Version upgrade procedures, migration scripts | Self-hosters |

#### 4.4.2 Community Support Model

| Channel | Response Time | Scope |
|---------|---------------|-------|
| GitHub Issues (tagged `self-host`) | Best effort (community) | Bug reports, feature requests |
| Discord `#self-host` channel | Best effort (community + team) | Setup help, troubleshooting |
| Wiki / Knowledge Base | Self-serve | Guides, tutorials, common configurations |

#### 4.4.3 Self-Host vs. Hosted Comparison (for documentation)

| Aspect | Self-Hosted | Official Hosted |
|--------|-------------|-----------------|
| Setup | Manual (Docker + DNS + TLS) | One-click |
| Maintenance | User responsibility | Managed by team |
| Updates | Manual (pull + migrate) | Automatic |
| Backups | User configured | Automated |
| Support | Community only | Email / Priority |
| SLA | None | 99.5% uptime target |
| Cost | Server hosting (~$5-20/mo VPS) | Subscription ($6.99-$14.99/mo) |

### 4.5 Phase 3 Deliverables

| # | Deliverable | Format | Owner | Exit Criterion |
|---|-------------|--------|-------|----------------|
| D3.1 | Payment abstraction layer | Code | Backend | Provider interface + Paddle implementation tested |
| D3.2 | Webhook processing pipeline | Code | Backend | All webhook events processed correctly in sandbox |
| D3.3 | Desktop checkout flow | Code | Desktop Dev | End-to-end: trial -> upgrade -> payment -> entitlements |
| D3.4 | Founding DM system | Code + Config | Backend + Product | Discount applied correctly; slot counter accurate |
| D3.5 | A/B test infrastructure | Code + Config | Backend | Variant assignment + telemetry tracking operational |
| D3.6 | A/B test Round 1 results (Starter) | Report | Product | Statistically significant result (p < 0.05) |
| D3.7 | Self-hosted documentation (4 documents) | Markdown | DevOps + Product | Community review; at least 3 successful external deployments |
| D3.8 | Waitlist landing page | Web page | Product + UI | Live and collecting emails |
| D3.9 | Founding DM marketing materials | Design + Copy | Product + UI | Reviewed and approved |

### 4.6 Phase 3 Exit Criteria

All of the following must be true before proceeding to Phase 4:

- [ ] At least one successful real payment processed through Paddle sandbox.
- [ ] Webhook processing handles all lifecycle events (create, renew, cancel, fail, refund) idempotently.
- [ ] Founding DM discount is correctly applied and persists through renewals.
- [ ] A/B test Round 1 (Starter pricing) has reached statistical significance.
- [ ] Self-hosted documentation has been validated by at least 3 external users.
- [ ] Waitlist has >= 100 signups.
- [ ] License audit remediation is fully complete (no BLOCKED assets remain in distribution).
- [ ] Online Sprint 8 (Self-Hosted Deployment and Beta) is complete or on track.
- [ ] 30-day beta health metrics pass: P95 latency < 120ms, reconnect success > 95%, session stability > 98%.

### 4.7 Phase 3 Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R3.1 | Paddle integration takes longer than expected | Medium | Medium | Start integration in Week 1; Stripe as pre-built fallback |
| R3.2 | Webhook processing drops events under load | Low | High | Idempotent processing; dead letter queue for failed webhooks; alerting on webhook failure rate |
| R3.3 | A/B test does not reach significance in 6 weeks | Medium | Medium | Extend test duration; reduce number of variants from 3 to 2 |
| R3.4 | Founding DM program depletes slots too quickly | Low | Low | Monitor closely; consider expanding to 300 if demand is strong |
| R3.5 | Self-hosted documentation is insufficient | Medium | Medium | Engage 5 technical beta testers specifically for self-host validation |
| R3.6 | Community backlash about paid features | Low | High | Clear communication: offline remains free forever; self-host remains free; pricing page transparency |
| R3.7 | Payment provider compliance requirements delay launch | Low | Medium | Begin compliance review (terms of service, privacy policy) in Month 4 |

---

## 5. Phase 4: General Availability (Months 8-10)

**Calendar:** October 2026 - December 2026
**Follows:** Online Sprint 8 completion
**Objective:** Launch paid plans publicly, enforce pricing, release the self-hosted server, and establish support operations.

### 5.1 Full Plan Enforcement

#### 5.1.1 GA Pricing (Final)

Final prices are determined by Phase 3 A/B test results. The table below uses midpoint estimates:

| Plan | Monthly | Annual (per month) | Annual Total | Savings |
|------|---------|-------------------|-------------|---------|
| Free | $0 | $0 | $0 | -- |
| Starter | $7.99 | $6.79 | $81.48 | 15% |
| Pro | $12.99 | $11.04 | $132.48 | 15% |

#### 5.1.2 Enforcement Rules

At GA, all plan guards transition from "soft enforcement" (log + allow) to "hard enforcement" (deny + upgrade prompt).

| Rule | Pre-GA | GA |
|------|--------|-----|
| Session creation without subscription | Allowed (alpha/beta) | Denied with 402 |
| Exceeding storage quota | Warning only | Denied with 413 |
| Backup without entitlement | Allowed (beta) | Denied with 402 |
| Trial expiry | Grace period (lenient) | Strict 7-day grace period |
| Past-due subscription | Access maintained | Access suspended after 7 days past due |

#### 5.1.3 Migration for Beta Users

Beta users who have been using the service for free must be transitioned gracefully:

1. **30-day notice**: Email and in-app notification 30 days before GA enforcement.
2. **Exclusive offer**: Beta users receive a one-time 20% discount on their first 3 months (stacks with Founding DM if applicable).
3. **Data preservation**: All beta user data is preserved for 90 days after GA, regardless of subscription status.
4. **Easy upgrade**: One-click upgrade from the notification banner.

### 5.2 Annual Plan Option

#### 5.2.1 Annual Plan Benefits

| Benefit | Value |
|---------|-------|
| Discount | 15-20% compared to monthly billing |
| Billing simplicity | One charge per year |
| Churn reduction | Longer commitment period |
| Cash flow | Upfront annual revenue |

#### 5.2.2 Annual Plan Implementation

- Annual plans are separate `plan` records with `price_annual` set.
- The checkout flow presents both monthly and annual options side by side.
- Annual discount is highlighted: "Save $X per year with annual billing."
- Annual subscriptions can be canceled but refunds follow a pro-rata policy (configurable).
- Founding DM discount stacks with annual discount (applied to the already-discounted annual price).

#### 5.2.3 Annual Plan Pricing Table

| Plan | Monthly | Annual/mo (15% discount) | Annual/mo (20% discount) |
|------|---------|-------------------------|-------------------------|
| Starter ($7.99) | $7.99 | $6.79 | $6.39 |
| Pro ($12.99) | $12.99 | $11.04 | $10.39 |

Decision gate: Annual discount percentage (15% vs. 20%) to be finalized at GA based on projected churn rates from beta data.

### 5.3 Self-Hosted Server Release

#### 5.3.1 Release Package

| Component | Contents |
|-----------|----------|
| `docker-compose.yml` | Pre-configured stack: FastAPI, PostgreSQL, Redis, MinIO, Nginx |
| `env.example` | Template for all environment variables with documentation |
| `SELF_HOST_GUIDE.md` | Updated from Phase 3 with GA-specific instructions |
| Alembic migrations | All database migrations up to GA version |
| Health check endpoint | `GET /health` returns service status for monitoring |
| Backup/restore scripts | CLI tools for manual backup and restore |

#### 5.3.2 Self-Hosted vs. Official Hosted Feature Parity

| Feature | Self-Hosted | Official Hosted |
|---------|-------------|-----------------|
| Core session functionality | Full | Full |
| Authentication / JWT | Full | Full |
| Asset management | Full | Full + CDN |
| Backup automation | Manual scripts | Automated daily |
| Monitoring | Bring your own | Included (Grafana) |
| TLS certificates | Certbot (manual) | Managed |
| Updates | Manual pull + migrate | Automatic |
| Plan enforcement / billing | Disabled (no billing needed) | Full |
| Subscription entitlements | All features unlocked | Based on plan |

Key principle: **Self-hosted users get all features unlocked.** Billing and entitlement enforcement only apply to the official hosted service.

#### 5.3.3 Release Cadence

- **Stable releases**: Monthly, following semantic versioning.
- **Changelog**: Published with each release, documenting breaking changes and migration steps.
- **Support window**: Current release + one previous release.
- **Compatibility**: Self-hosted and hosted share the same client; client auto-detects server capabilities.

### 5.4 Support Operations

#### 5.4.1 Support Tiers

| Tier | Plan | Channel | Target Response Time |
|------|------|---------|---------------------|
| Community | Free + Self-Hosted | GitHub Issues, Discord | Best effort (no SLA) |
| Standard | Starter | Email | 48 hours (business days) |
| Priority | Pro | Email + Discord DM | 24 hours (business days) |

#### 5.4.2 SLA Definition

| Metric | Starter | Pro |
|--------|---------|-----|
| Uptime target | 99.0% | 99.5% |
| Planned maintenance window | Saturdays 02:00-06:00 UTC | Saturdays 02:00-04:00 UTC |
| Incident communication | Status page | Status page + email notification |
| Data durability | Daily backups, 7-day retention | Daily backups, 30-day retention |
| Maximum data loss (RPO) | 24 hours | 24 hours |
| Maximum downtime (RTO) | 4 hours | 2 hours |

#### 5.4.3 Response Templates

Pre-built response templates for common support scenarios:

| Template | Use Case |
|----------|----------|
| `TRIAL_EXPIRED` | User asks why they lost hosted access after trial |
| `UPGRADE_GUIDE` | Step-by-step upgrade instructions |
| `BILLING_ISSUE` | Payment failed, subscription not activating |
| `SESSION_UNSTABLE` | Reporting connectivity/latency issues |
| `SELF_HOST_SETUP` | Redirect to self-hosted documentation |
| `BUG_REPORT_ACK` | Acknowledge bug report and set expectations |
| `FEATURE_REQUEST` | Acknowledge feature request and explain prioritization |
| `CANCELLATION` | Confirm cancellation and offer feedback survey |
| `REFUND_REQUEST` | Refund policy explanation and processing steps |
| `DATA_EXPORT` | Instructions for exporting user data |

#### 5.4.4 Escalation Path

```
Tier 1: Template response (automated or support agent)
    |
    v (if unresolved after 48 hours or user escalates)
Tier 2: Technical investigation (developer on rotation)
    |
    v (if infrastructure issue or security concern)
Tier 3: Founder / Tech Lead direct involvement
```

### 5.5 Phase 4 Deliverables

| # | Deliverable | Format | Owner | Exit Criterion |
|---|-------------|--------|-------|----------------|
| D4.1 | Hard plan enforcement across all guard points | Code | Backend | Zero "soft" guards remaining; all return correct HTTP codes |
| D4.2 | Annual plan support in checkout flow | Code | Backend + Desktop | Annual subscription created and renewed correctly |
| D4.3 | Beta-to-GA user migration (30-day notice + discount) | Code + Email | Backend + Product | Migration email sent; discount applied correctly |
| D4.4 | Self-hosted release package (Docker Compose + docs) | Package | DevOps | 5 successful external deployments validated |
| D4.5 | Support operations handbook | Document | Product | Templates, escalation path, SLA definitions reviewed |
| D4.6 | Status page | Web page | DevOps | Live and showing real uptime data |
| D4.7 | A/B test Round 2 results (Pro pricing) | Report | Product | Statistically significant result |
| D4.8 | GA launch announcement | Blog post + Email | Product | Reviewed and approved |

### 5.6 Phase 4 Exit Criteria

All of the following must be true before proceeding to Phase 5:

- [ ] All plan guards are in hard enforcement mode.
- [ ] Annual plans are purchasable and renew correctly.
- [ ] Beta users have been migrated with 30-day notice.
- [ ] Self-hosted release is publicly available with validated documentation.
- [ ] Support templates and escalation path are documented and tested.
- [ ] Status page is live and reflects real service health.
- [ ] A/B test Round 2 (Pro pricing) has reached statistical significance.
- [ ] First 30 days of GA show: uptime > 99%, support response within SLA, no critical billing errors.

### 5.7 Phase 4 Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R4.1 | GA launch exposes scaling issues | Medium | High | Load testing before GA; auto-scaling configuration ready |
| R4.2 | Beta users churn during migration | Medium | Medium | Generous discount + 90-day data preservation + clear communication |
| R4.3 | Support volume overwhelms small team | Medium | Medium | Comprehensive FAQ and self-serve knowledge base; automate common responses |
| R4.4 | Self-hosted deployment issues create negative community sentiment | Low | High | Extensive testing; dedicated Discord support channel; quick-fix release cadence |
| R4.5 | Annual plan refund requests create accounting complexity | Low | Medium | Clear refund policy; pro-rata calculation tool; test with sandbox before GA |
| R4.6 | Competitor launches aggressive pricing during our GA | Low | Medium | Focus on unique value (offline-first, self-host option); adjust Founding DM slots if needed |

---

## 6. Phase 5: Growth (Months 10-12+)

**Calendar:** December 2026 - March 2027 and beyond
**Objective:** Diversify revenue beyond subscriptions through marketplace, creator program, enterprise licensing, and an expanded plan tier.

### 6.1 Marketplace Launch

#### 6.1.1 Marketplace Vision

The marketplace allows creators to sell digital content packs that enhance the DM Tool experience. This creates a second revenue stream (commission) and increases platform stickiness.

#### 6.1.2 Content Categories

| Category | Examples | Expected Price Range |
|----------|----------|---------------------|
| Sound Packs | Ambient soundscapes, combat music, NPC voices | $2.99 - $9.99 |
| Map Packs | Battle maps, world maps, dungeon tiles | $4.99 - $14.99 |
| Template Worlds | Pre-built campaigns with entities, maps, sessions | $9.99 - $24.99 |
| Entity Packs | Monster collections, NPC libraries, item databases | $2.99 - $7.99 |
| Handout Packs | Player handout templates, letter props, journal pages | $1.99 - $4.99 |

#### 6.1.3 Marketplace Architecture

```
Creator uploads pack
    |
    v
[Review Queue] -- Content review for quality, licensing, appropriateness
    |
    v
[Approval] -- Pack listed on marketplace
    |
    v
Buyer browses marketplace
    |
    v
[Purchase] -- Payment processed via Paddle
    |
    v
[Commission Split] -- Platform takes 30%, Creator receives 70%
    |
    v
[Delivery] -- Pack added to buyer's library and available in-app
```

#### 6.1.4 Marketplace Technical Requirements

| Requirement | Description |
|-------------|-------------|
| Creator upload portal | Web or in-app interface for pack submission |
| Content review system | Queue + approval workflow (manual initially, automated later) |
| Pack format specification | Standardized `.dmtpack` format (ZIP with manifest) |
| Licensing enforcement | All marketplace content must be commercially licensed |
| Preview system | Thumbnails, audio samples, description for each pack |
| Rating and reviews | 5-star rating + text reviews from verified buyers |
| Creator analytics | Sales, revenue, download counts, ratings dashboard |
| Buyer library | In-app library management for purchased packs |

#### 6.1.5 Marketplace Timeline

| Month | Milestone |
|-------|-----------|
| Month 10 | Pack format specification finalized; Creator SDK documented |
| Month 11 | Creator upload portal; review workflow; 5 launch packs from internal team |
| Month 12 | Marketplace beta with 10-20 packs; 5 external creators onboarded |
| Month 13+ | Public marketplace; creator program open to all; marketing push |

### 6.2 Creator Program

The creator program formalizes the relationship between the platform and content creators.

#### 6.2.1 Revenue Share Model

| Tier | Threshold | Creator Share | Platform Share |
|------|-----------|---------------|----------------|
| Standard | 0 - 100 sales | 70% | 30% |
| Established | 101 - 500 sales | 75% | 25% |
| Premium | 501+ sales | 80% | 20% |

Sales thresholds are cumulative across all packs by a single creator.

#### 6.2.2 Creator Benefits

| Benefit | Standard | Established | Premium |
|---------|----------|-------------|---------|
| Revenue share | 70% | 75% | 80% |
| Featured placement | No | Quarterly | Monthly |
| Early access to new features | No | Yes | Yes |
| Creator badge (in-app) | Basic | Silver | Gold |
| Direct support channel | No | No | Yes |
| Analytics dashboard | Basic | Full | Full + API |

#### 6.2.3 Creator Onboarding

1. Creator applies through the website/in-app form.
2. Application reviewed (portfolio, content quality, licensing compliance).
3. Approved creators receive Creator SDK access and documentation.
4. First pack submitted goes through enhanced review (feedback provided).
5. After 3 approved packs, creator enters self-serve publishing (spot-checked).

### 6.3 Enterprise and Education Licensing

#### 6.3.1 Target Segments

| Segment | Use Case | Pricing Model |
|---------|----------|---------------|
| Game stores / cafes | In-store D&D events; multiple concurrent sessions | Site license: flat monthly fee for X concurrent sessions |
| Education institutions | After-school D&D clubs; classroom RPG activities | Education discount: 50% off Pro plan per facilitator |
| Content creators / streamers | Live-streamed D&D sessions | Creator plan: Pro features + streaming integrations |
| Corporate team building | Corporate RPG events | Per-event licensing |

#### 6.3.2 Enterprise Plan Structure

| Feature | Pro (Individual) | Enterprise |
|---------|-----------------|------------|
| Concurrent sessions | 3 | 10-50 (configurable) |
| Storage | 2 GB | 10-50 GB (configurable) |
| User accounts | 1 DM | Multiple DM accounts |
| Shared library | No | Shared entity/asset library across DMs |
| Centralized billing | No | Single invoice |
| Admin dashboard | No | User management, usage reporting |
| SLA | 99.5% | 99.9% |
| Support | Priority email | Dedicated account manager |
| Custom branding | No | Optional (white-label elements) |

#### 6.3.3 Education Program

| Element | Detail |
|---------|--------|
| Eligibility | Verified educational institution (school, library, after-school program) |
| Discount | 50% off Pro plan per facilitator account |
| Verification | Manual review of institution credentials |
| Special features | Student-safe mode (content filtering), class management tools |
| Reporting | Session activity reports for educators |

### 6.4 Hosted Creator / Team Tier

The Creator/Team tier is the fourth plan, introduced after the marketplace establishes content creation as a user activity.

#### 6.4.1 Creator/Team Tier Features

| Feature | Pro | Creator/Team |
|---------|-----|-------------|
| Concurrent sessions | 3 | 5 |
| Storage | 2 GB | 10 GB |
| Backup retention | 30 days | 90 days |
| Multi-campaign workspace | No | Yes (up to 10 workspaces) |
| Shared entity library | No | Yes (across workspaces) |
| Team roles | No | DM + Assistant DM + Librarian |
| Audit log | No | Full audit trail |
| Marketplace creator tools | Basic | Full (analytics, bulk upload, scheduling) |
| API access | No | Yes (read-only initially) |

#### 6.4.2 Pricing Estimate

| Billing | Price |
|---------|-------|
| Monthly | $19.99 - $24.99 |
| Annual (per month) | $16.99 - $21.24 |

Final pricing subject to market research and customer feedback during the Growth phase.

### 6.5 Phase 5 Deliverables

| # | Deliverable | Format | Owner | Exit Criterion |
|---|-------------|--------|-------|----------------|
| D5.1 | Pack format specification (`.dmtpack`) | Document | Backend + Product | Specification reviewed; sample pack created |
| D5.2 | Creator SDK and documentation | Code + Document | Backend | SDK enables pack creation; 3 internal packs built with it |
| D5.3 | Creator upload portal | Code (Web) | Full Stack | Creators can upload, preview, and submit packs |
| D5.4 | Content review workflow | Code + Process | Backend + Product | Review queue operational; approval/rejection flow tested |
| D5.5 | Marketplace storefront (in-app) | Code | Desktop Dev | Browse, search, purchase, download flow works end-to-end |
| D5.6 | Creator program terms and onboarding | Legal + Process | Product | Terms reviewed by legal; onboarding flow tested |
| D5.7 | Enterprise licensing proposal | Document | Product | Proposal reviewed; pricing validated with 3 potential customers |
| D5.8 | Education program terms | Document | Product | Terms and verification process defined |
| D5.9 | Creator/Team tier implementation | Code | Backend + Desktop | All tier-specific features operational |
| D5.10 | Marketplace launch (beta) | Launch | All | 10-20 packs available; 5 external creators onboarded |

### 6.6 Phase 5 Exit Criteria

The Growth phase is ongoing, but the following milestones mark successful execution:

- [ ] Marketplace has >= 20 packs from >= 5 creators.
- [ ] At least 50 marketplace transactions completed.
- [ ] Creator program has >= 10 active creators.
- [ ] Enterprise licensing has >= 1 signed customer.
- [ ] Education program has >= 3 participating institutions.
- [ ] Creator/Team tier has >= 10 subscribers.
- [ ] Marketplace commission revenue covers marketplace operating costs.

### 6.7 Phase 5 Risks

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| R5.1 | Low creator adoption | Medium | High | Seed marketplace with internal content; offer revenue share bonus for first 20 creators |
| R5.2 | Marketplace content quality issues | Medium | Medium | Manual review for first 100 packs; quality guidelines; community reporting |
| R5.3 | Enterprise sales cycle too long | High | Medium | Focus on small/indie game stores first; self-serve enterprise sign-up |
| R5.4 | Creator/Team tier cannibalizes Pro subscriptions | Low | Medium | Ensure clear feature differentiation; Pro remains the "sweet spot" for individual DMs |
| R5.5 | Licensing disputes on marketplace content | Medium | High | Require creator attestation of licensing; DMCA takedown process; platform insurance |
| R5.6 | Education market requires features beyond current scope | Medium | Medium | Start with a simple "education discount on Pro" before building education-specific features |

---

## 7. Revenue Scenarios

All scenarios use the following shared assumptions:

### 7.1 Shared Assumptions

| Assumption | Value | Source |
|------------|-------|--------|
| Total registered users (Month 12) | 2,000 - 5,000 | Based on community growth projections |
| Average users who try online features | 40% of registered | Industry benchmark for online feature adoption |
| Trial-to-paid conversion rate (range) | 5% - 15% | VTT industry range |
| Monthly churn rate | 3% - 8% | SaaS industry range for < $20/mo products |
| Starter : Pro subscriber ratio | 65:35 | Assumption based on VTT market |
| Average monthly ARPU (blended) | $9.50 | Weighted average of Starter ($7.99) and Pro ($12.99) at 65:35 |
| Annual plan adoption | 30% of subscribers | SaaS industry average |
| Founding DM discount impact on ARPU | -15% (blended) | 200 Founding DMs at 30% discount |
| Infrastructure cost per active user | $1.50 - $2.50/mo | Estimated hosting + storage + bandwidth |
| Payment processing fees | 5% + $0.50 (Paddle) | Paddle standard fees |

### 7.2 Optimistic Scenario

Assumes strong community adoption, viral growth from the open-source audience, and effective conversion.

| Month | Registered Users | Online Users (40%) | Trial Starts | Paid Subscribers | MRR | Cumulative Revenue |
|-------|-----------------|-------------------|-------------|-----------------|-----|-------------------|
| 1-3 | 500 | 0 | 0 | 0 | $0 | $0 |
| 4 | 800 | 320 | 48 | 0 | $0 | $0 |
| 5 | 1,200 | 480 | 72 | 7 | $67 | $67 |
| 6 | 1,800 | 720 | 108 | 36 | $342 | $409 |
| 7 | 2,500 | 1,000 | 150 | 105 | $998 | $1,407 |
| 8 | 3,200 | 1,280 | 192 | 210 | $1,995 | $3,402 |
| 9 | 3,800 | 1,520 | 228 | 350 | $3,325 | $6,727 |
| 10 | 4,200 | 1,680 | 252 | 500 | $4,750 | $11,477 |
| 11 | 4,700 | 1,880 | 282 | 650 | $6,175 | $17,652 |
| 12 | 5,000 | 2,000 | 300 | 800 | $7,600 | $25,252 |

**Key assumptions:** 15% trial-to-paid conversion, 3% monthly churn, strong word-of-mouth from open-source community.

**Month 12 MRR range:** $7,600 - $11,200 (upper bound assumes higher ARPU from Pro adoption + marketplace revenue).

### 7.3 Base Scenario

Assumes moderate growth, average conversion rates, and steady but not exceptional adoption.

| Month | Registered Users | Online Users (40%) | Trial Starts | Paid Subscribers | MRR | Cumulative Revenue |
|-------|-----------------|-------------------|-------------|-----------------|-----|-------------------|
| 1-3 | 300 | 0 | 0 | 0 | $0 | $0 |
| 4 | 500 | 200 | 30 | 0 | $0 | $0 |
| 5 | 700 | 280 | 42 | 4 | $38 | $38 |
| 6 | 1,000 | 400 | 60 | 18 | $171 | $209 |
| 7 | 1,400 | 560 | 84 | 52 | $494 | $703 |
| 8 | 1,800 | 720 | 108 | 100 | $950 | $1,653 |
| 9 | 2,200 | 880 | 132 | 165 | $1,568 | $3,221 |
| 10 | 2,600 | 1,040 | 156 | 240 | $2,280 | $5,501 |
| 11 | 2,900 | 1,160 | 174 | 320 | $3,040 | $8,541 |
| 12 | 3,200 | 1,280 | 192 | 400 | $3,800 | $12,341 |

**Key assumptions:** 10% trial-to-paid conversion, 5% monthly churn, organic growth from existing community.

**Month 12 MRR range:** $3,800 - $5,600 (upper bound includes annual plan upfront and marketplace commission).

### 7.4 Pessimistic Scenario

Assumes slow adoption, low conversion, higher churn, and community resistance to paid features.

| Month | Registered Users | Online Users (40%) | Trial Starts | Paid Subscribers | MRR | Cumulative Revenue |
|-------|-----------------|-------------------|-------------|-----------------|-----|-------------------|
| 1-3 | 200 | 0 | 0 | 0 | $0 | $0 |
| 4 | 300 | 120 | 18 | 0 | $0 | $0 |
| 5 | 400 | 160 | 24 | 1 | $10 | $10 |
| 6 | 550 | 220 | 33 | 5 | $48 | $58 |
| 7 | 700 | 280 | 42 | 14 | $133 | $191 |
| 8 | 900 | 360 | 54 | 28 | $266 | $457 |
| 9 | 1,100 | 440 | 66 | 50 | $475 | $932 |
| 10 | 1,300 | 520 | 78 | 75 | $713 | $1,645 |
| 11 | 1,500 | 600 | 90 | 100 | $950 | $2,595 |
| 12 | 1,700 | 680 | 102 | 130 | $1,235 | $3,830 |

**Key assumptions:** 5% trial-to-paid conversion, 8% monthly churn, limited organic growth.

**Month 12 MRR range:** $1,235 - $2,100 (upper bound assumes some annual plan revenue).

### 7.5 Break-Even Analysis

Break-even is defined as the point where monthly subscription revenue exceeds monthly infrastructure costs.

#### 7.5.1 Cost Structure

| Cost Category | Monthly Estimate | Notes |
|---------------|-----------------|-------|
| Server hosting (VPS/cloud) | $50 - $150 | Scales with user count |
| Database hosting | $20 - $50 | PostgreSQL managed or self-hosted |
| Object storage (MinIO/S3) | $10 - $30 | Scales with storage consumption |
| CDN / bandwidth | $10 - $40 | Scales with asset downloads |
| Domain + TLS | $5 | Fixed cost |
| Monitoring (Grafana Cloud or self-hosted) | $0 - $30 | Free tier initially |
| Payment processing (Paddle) | 5% + $0.50/txn | Variable with revenue |
| Support tooling | $0 - $20 | Free tier initially |
| **Total fixed baseline** | **$95 - $325/mo** | |
| **Variable per active user** | **$1.50 - $2.50/mo** | |

#### 7.5.2 Break-Even Points

| Scenario | Break-Even Month | Subscribers at Break-Even | Monthly Cost at Break-Even |
|----------|-----------------|--------------------------|---------------------------|
| Optimistic | Month 7-8 | ~50-80 subscribers | ~$170 - $325 |
| Base | Month 9-10 | ~80-120 subscribers | ~$215 - $425 |
| Pessimistic | Month 12-15 | ~80-120 subscribers | ~$215 - $425 |

Break-even requires approximately 50-120 paying subscribers, depending on infrastructure efficiency and ARPU.

#### 7.5.3 Path to Profitability

| Milestone | Description | Target |
|-----------|-------------|--------|
| Break-even | Revenue >= infrastructure cost | Month 8-10 (base) |
| Sustainability | Revenue >= infrastructure + basic support labor | Month 12-14 (base) |
| Growth investment | Revenue enables marketing/content investment | Month 14-18 (base) |
| Marketplace contribution | Marketplace commission adds 15-20% to revenue | Month 15+ |

---

## 8. Decision Log Template

All monetization decisions must be documented using this template to maintain an auditable decision history.

### 8.1 Template

```markdown
## Decision: [DEC-XXXX] [Brief Title]

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Rejected | Superseded by DEC-XXXX
**Decision Maker:** [Name / Role]
**Stakeholders:** [Names / Roles consulted]

### Context

[What situation or question prompted this decision? What constraints exist?]

### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| Option A | ... | ... |
| Option B | ... | ... |
| Option C | ... | ... |

### Decision

[Which option was chosen and why?]

### Consequences

- **Positive:** [Expected benefits]
- **Negative:** [Expected trade-offs or costs]
- **Risks:** [What could go wrong with this decision?]

### Review Date

[When should this decision be revisited? What trigger would cause reconsideration?]

### Related Decisions

- [DEC-XXXX] [Related decision title]
```

### 8.2 Initial Decisions to Document

| Decision ID | Title | Phase | Status |
|-------------|-------|-------|--------|
| DEC-0001 | Self-hosted online remains free (no paid features gated) | Phase 1 | Pending founder decision |
| DEC-0002 | Starter plan base price ($6.99 / $7.99 / $8.99) | Phase 3 | Pending A/B test results |
| DEC-0003 | Pro plan base price ($11.99 / $12.99 / $14.99) | Phase 3 | Pending A/B test results |
| DEC-0004 | Trial duration (7 days vs. 14 days) | Phase 2 | Recommended: 14 days |
| DEC-0005 | Founding DM limit (200 vs. 300 slots) | Phase 3 | Recommended: 200 |
| DEC-0006 | Founding DM discount percentage (25% vs. 30% vs. 35%) | Phase 3 | Recommended: 30% |
| DEC-0007 | Payment provider (Stripe vs. Paddle) | Phase 3 | Recommended: Paddle |
| DEC-0008 | Annual discount percentage (15% vs. 20%) | Phase 4 | Pending churn data |
| DEC-0009 | Marketplace commission split (70/30 vs. 75/25 vs. 80/20) | Phase 5 | Recommended: tiered (70/75/80) |
| DEC-0010 | Marketplace launch timing (Month 11 vs. Month 13) | Phase 5 | Pending GA stability assessment |
| DEC-0011 | Credit card required for trial (yes vs. no) | Phase 2 | Recommended: no |
| DEC-0012 | Enterprise pricing model (per-seat vs. per-session vs. flat) | Phase 5 | Pending market research |

### 8.3 Decision Governance

- All pricing decisions require founder sign-off.
- Technical architecture decisions require tech lead review.
- Decisions with revenue impact > $500/month require documented analysis.
- Decisions are reviewed quarterly; any decision older than 6 months without review is flagged.

---

## 9. Risk Register

This section consolidates all monetization risks across all phases into a single register with consistent scoring.

### 9.1 Risk Scoring Methodology

**Probability:**
- Low (L): < 20% chance of occurring
- Medium (M): 20-50% chance of occurring
- High (H): > 50% chance of occurring

**Impact:**
- Low (L): Minor inconvenience; < 1 week delay; < $500 revenue impact
- Medium (M): Significant setback; 1-4 week delay; $500-$5,000 revenue impact
- High (H): Critical issue; > 4 week delay; > $5,000 revenue impact or reputational damage

**Risk Score:** Probability x Impact (H/H = Critical, H/M or M/H = High, M/M = Medium, all others = Low)

### 9.2 Full Risk Register

| ID | Risk | Phase | Prob | Impact | Score | Mitigation | Owner | Status |
|----|------|-------|------|--------|-------|------------|-------|--------|
| R01 | CC BY-NC licensed assets block commercial launch | 1 | M | H | High | Begin audit Week 1; maintain replacement shortlist; hard-block launch until resolved | Product | Open |
| R02 | Entitlement schema requires multiple design iterations | 1 | M | M | Medium | Time-box design to 2 weeks; use feature flags to decouple schema from enforcement | Backend | Open |
| R03 | Auth/Session sprint delays impact entitlement integration | 1 | L | H | Medium | Entitlement schema can be designed independently; only integration requires auth sprint | Backend | Open |
| R04 | Feature flag caching creates stale authorization state | 1 | L | M | Low | 60-second TTL; manual invalidation endpoint; fallback to DB on cache miss | Backend | Open |
| R05 | Pricing strategy not finalized, blocking page design | 1 | M | L | Low | Design with placeholder ranges; final prices determined by Phase 3 A/B tests | Product | Open |
| R06 | Alpha recruitment falls short of 50 DMs | 2 | M | M | Medium | Start recruitment in Month 2; leverage community; offer Alpha Tester badge | Product | Open |
| R07 | Plan guards create false denials during alpha | 2 | M | H | High | "Soft enforcement" mode during alpha; log denials but allow action | Backend | Open |
| R08 | Trial system abuse (mass account creation) | 2 | L | M | Low | Rate limiting; one-trial-per-email; device fingerprinting if needed | Backend | Open |
| R09 | Alpha DMs report low willingness to pay (< 40%) | 2 | M | H | High | Use feedback to refine value prop; do not proceed to payment until > 40% WTP | Product | Open |
| R10 | Telemetry overhead impacts session latency | 2 | L | M | Low | Async metering; benchmark overhead < 5ms per request | Backend | Open |
| R11 | Reconnect stability does not meet alpha targets | 2 | M | H | High | Prioritize reconnect in Sprint 5-6; consider alpha extension | Backend | Open |
| R12 | Payment provider integration takes longer than expected | 3 | M | M | Medium | Start early in Phase 3; Stripe as pre-built fallback | Backend | Open |
| R13 | Webhook processing drops events under load | 3 | L | H | Medium | Idempotent processing; dead letter queue; alerting on failure rate | Backend | Open |
| R14 | A/B test does not reach statistical significance | 3 | M | M | Medium | Extend test duration; reduce variants from 3 to 2 | Product | Open |
| R15 | Community backlash about paid features | 3 | L | H | Medium | Clear communication: offline free forever; self-host free; transparent pricing | Product | Open |
| R16 | Payment provider compliance requirements delay launch | 3 | L | M | Low | Begin compliance review (ToS, privacy policy) in Month 4 | Product | Open |
| R17 | GA launch exposes scaling issues | 4 | M | H | High | Load testing before GA; auto-scaling ready; gradual rollout | DevOps | Open |
| R18 | Beta users churn during GA migration | 4 | M | M | Medium | 30-day notice; exclusive discount; 90-day data preservation | Product | Open |
| R19 | Support volume overwhelms team | 4 | M | M | Medium | Comprehensive FAQ; self-serve KB; automate common responses | Product | Open |
| R20 | Self-hosted deployment issues harm community sentiment | 4 | L | H | Medium | Extensive testing; dedicated Discord channel; quick-fix release cadence | DevOps | Open |
| R21 | Annual plan refund complexity | 4 | L | M | Low | Clear refund policy; pro-rata calculator; sandbox testing | Backend | Open |
| R22 | Low creator adoption for marketplace | 5 | M | H | High | Seed with internal content; revenue share bonus for first 20 creators | Product | Open |
| R23 | Marketplace content quality issues | 5 | M | M | Medium | Manual review for first 100 packs; quality guidelines; community reporting | Product | Open |
| R24 | Licensing disputes on marketplace content | 5 | M | H | High | Creator attestation; DMCA process; content insurance | Product | Open |
| R25 | Enterprise sales cycle too long for small team | 5 | H | M | Medium | Focus on self-serve small businesses first; defer enterprise sales | Product | Open |
| R26 | Creator/Team tier cannibalizes Pro subscriptions | 5 | L | M | Low | Clear feature differentiation; monitor upgrade/downgrade patterns | Product | Open |
| R27 | Competitor launches aggressive pricing during our GA | 4 | L | M | Low | Focus on unique value (offline-first + self-host); adjust Founding DM if needed | Product | Open |
| R28 | Currency fluctuations impact international pricing | 3-5 | M | L | Low | Paddle handles regional pricing; monitor quarterly | Product | Open |
| R29 | Infrastructure costs exceed projections | 3-5 | M | M | Medium | Monthly cost review; optimize asset caching; set budget alerts | DevOps | Open |
| R30 | GDPR/data privacy requirements for billing data | 3 | M | M | Medium | Data retention policy; deletion pipeline; privacy policy update before payment launch | Backend | Open |

### 9.3 Risk Review Cadence

- **Weekly** during active phase transitions (last 2 weeks of each phase).
- **Bi-weekly** during steady-state execution within a phase.
- **Immediately** when a new risk is identified or an existing risk's probability/impact changes.

Risks scored as "Critical" or "High" require a documented mitigation plan within 48 hours of identification.

---

## 10. Key Dependencies

### 10.1 Online Development Sprint Dependencies

The monetization roadmap depends directly on the online development sprint timeline. Any delay in the sprint schedule cascades to the monetization timeline.

| Monetization Milestone | Depends On Sprint | Sprint Dates | Dependency Type |
|------------------------|-------------------|-------------|-----------------|
| Entitlement schema integration | Sprint 3 (Auth/Session Gateway) | Apr 6-17, 2026 | Hard: entitlements extend the user/session model |
| Plan guard implementation | Sprint 3 + Sprint 4 (Asset Proxy) | Apr 6 - May 1, 2026 | Hard: guards wrap session create and asset upload endpoints |
| Usage metering (session count) | Sprint 3 (Session creation endpoint) | Apr 6-17, 2026 | Hard: must intercept session lifecycle |
| Usage metering (storage) | Sprint 4 (Asset proxy + MinIO) | Apr 20 - May 1, 2026 | Hard: must measure asset uploads |
| Trial system activation | Sprint 3 (User registration) | Apr 6-17, 2026 | Hard: trial attaches to user account |
| Telemetry dashboard | Sprint 5-6 (Reconnect + Performance) | May 4-29, 2026 | Soft: telemetry can start with Sprint 3 data |
| Alpha test group | Sprint 4 (First functional online session) | Apr 20 - May 1, 2026 | Hard: alpha requires working online sessions |
| Payment integration | Sprint 7-8 (Feature complete) | Jun 1-26, 2026 | Soft: can start Paddle integration before Sprint 7 |
| Self-hosted release | Sprint 8 (Self-Hosted Deployment) | Jun 15-26, 2026 | Hard: Docker Compose stack from Sprint 8 |
| GA enforcement | All sprints complete | Jun 26, 2026 | Hard: cannot enforce paid plans on incomplete product |

### 10.2 Pre-Online Task Dependencies

Several pre-online tasks (referenced in `TODO.md` and the Development Report) must be completed before monetization work can begin:

| Pre-Online Task | Blocks | Status |
|-----------------|--------|--------|
| UI consolidation (single-window flow) | Professional appearance for pricing page integration | Sprint 1 |
| EventManager skeleton | Event-driven metering and guard notifications | Sprint 1 |
| Socket client integration | Online session functionality | Sprint 2 |
| Event schema v1 | Metering event format | Sprint 2 |
| Player window standardization | Consistent experience for paying customers | Sprint 1-2 |
| Style token standardization | Professional UI for upgrade prompts and pricing | Sprint 1 |

### 10.3 External Dependencies

| Dependency | Description | Risk if Unavailable | Mitigation |
|------------|-------------|--------------------|-----------|
| Paddle account approval | Merchant of Record account setup | Payment integration blocked | Apply in Month 4; Stripe as fallback |
| Domain and DNS setup | `api.<domain>`, `ws.<domain>`, `assets.<domain>` | Hosted service unreachable | Secure domain in Month 1 |
| TLS certificates (Let's Encrypt) | HTTPS for all public endpoints | Security requirement unmet | Automated via Certbot; fallback to paid cert |
| PostgreSQL hosting | Durable data store for billing | Billing data at risk | Self-managed initially; managed service as backup |
| Redis hosting | Session state and counter cache | Performance degradation | Self-managed; can fall back to PostgreSQL for counters |
| MinIO / S3-compatible storage | Asset hosting for paying customers | Asset delivery broken | MinIO self-hosted; fallback to local filesystem |
| Grafana / Prometheus | Telemetry dashboard | Blind to operational metrics | Self-hosted stack; low external dependency risk |
| Legal review (ToS, Privacy Policy) | Terms for paid service | Legal exposure | Begin in Month 4; template-based initially |

### 10.4 Cross-Phase Dependency Chain

```
Phase 1 (Foundation)
  |
  |- Entitlement schema ---------> Phase 2 (Guard implementation)
  |- Feature flags ---------------> Phase 2 (Trial system) + Phase 4 (GA enforcement)
  |- License audit ---------------> Phase 3 (Payment integration) [BLOCKING]
  |- Pricing page design ---------> Phase 3 (A/B testing)
  |
Phase 2 (Closed Alpha)
  |
  |- Plan guards -----------------> Phase 4 (Hard enforcement)
  |- Trial system ----------------> Phase 3 (Founding DM conversion)
  |- Telemetry dashboard ---------> Phase 3 (A/B test analysis) + Phase 4 (GA monitoring)
  |- Alpha feedback --------------> Phase 3 (Value proposition refinement)
  |
Phase 3 (Open Beta)
  |
  |- Payment integration ---------> Phase 4 (GA revenue collection)
  |- A/B test results ------------> Phase 4 (Final pricing)
  |- Founding DM program ---------> Phase 4 (GA migration discounts)
  |- Self-hosted docs ------------> Phase 4 (Self-hosted release)
  |
Phase 4 (General Availability)
  |
  |- Stable subscriber base ------> Phase 5 (Marketplace launch)
  |- Annual plan data ------------> Phase 5 (Creator/Team tier pricing)
  |- Support operations ----------> Phase 5 (Enterprise support)
  |
Phase 5 (Growth)
  |
  |- Marketplace revenue ---------> Long-term sustainability
  |- Creator program -------------> Content ecosystem
  |- Enterprise licensing --------> Revenue diversification
```

### 10.5 Go/No-Go Decision Gates

Each phase transition requires a formal go/no-go decision based on the exit criteria defined in each phase section.

| Gate | Decision Point | Decision Maker | Key Criteria |
|------|---------------|---------------|-------------|
| G1: Foundation -> Alpha | End of Month 3 | Tech Lead + Founder | Schema deployed; flags operational; audit underway |
| G2: Alpha -> Open Beta | End of Month 5 | Founder | Alpha NPS >= 30; WTP >= 40%; stability >= 95% |
| G3: Open Beta -> GA | End of Month 8 | Founder | Payment tested; A/B Round 1 significant; 100+ waitlist; license audit complete |
| G4: GA -> Growth | End of Month 10 | Founder | 30 days GA health pass; support operational; self-host released |
| G5: Marketplace Launch | Month 11 | Product + Founder | Creator SDK ready; 5+ launch packs; review workflow operational |

**No-go criteria (any of these blocks progression):**
- Critical or high-severity bugs in billing/entitlement system.
- License audit has unresolved `BLOCKED` assets.
- Alpha/Beta stability < 90%.
- Payment provider integration not certified (for G3).
- Infrastructure costs exceeding 2x projected budget.

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| ARPU | Average Revenue Per User (including free users) |
| ARPPU | Average Revenue Per Paying User |
| Churn | Rate at which subscribers cancel their subscription |
| Entitlement | A specific feature or capability granted to a user by their subscription |
| Feature Flag | A runtime toggle that enables or disables a feature globally |
| GA | General Availability — public launch of paid plans |
| LTV | Lifetime Value — total revenue expected from a subscriber over their lifetime |
| MoR | Merchant of Record — the entity legally responsible for the transaction |
| MRR | Monthly Recurring Revenue |
| NPS | Net Promoter Score — measure of customer satisfaction and loyalty |
| RPO | Recovery Point Objective — maximum acceptable data loss in a disaster |
| RTO | Recovery Time Objective — maximum acceptable downtime in a disaster |
| SLA | Service Level Agreement — contractual uptime and response time commitments |
| WTP | Willingness To Pay — percentage of users who would pay for the service |

## Appendix B: Sprint-to-Phase Mapping

| Sprint | Sprint Period | Sprint Phase | Monetization Phase | Monetization Activity |
|--------|-------------|-------------|-------------------|----------------------|
| Sprint 1 | Mar 9-20, 2026 | Phase 0 | Phase 1 (prep) | Begin license audit; pricing page wireframe |
| Sprint 2 | Mar 23 - Apr 3, 2026 | Phase 0 | Phase 1 (prep) | Continue audit; entitlement schema design (paper) |
| Sprint 3 | Apr 6-17, 2026 | Phase 1 | Phase 1 (build) | Deploy entitlement schema; feature flag table; begin metering |
| Sprint 4 | Apr 20 - May 1, 2026 | Phase 1 | Phase 1 (build) + Phase 2 (prep) | Storage metering; begin guard implementation |
| Sprint 5 | May 4-15, 2026 | Phase 2 | Phase 2 (build) | Plan guards; trial system; alpha recruitment |
| Sprint 6 | May 18-29, 2026 | Phase 2 | Phase 2 (build) | Telemetry dashboard; alpha launch |
| Sprint 7 | Jun 1-12, 2026 | Phase 3 | Phase 2 (alpha running) + Phase 3 (prep) | Alpha data collection; payment integration start |
| Sprint 8 | Jun 15-26, 2026 | Phase 4 | Phase 3 (build) | Self-hosted prep; payment integration; Founding DM system |
| Post-Sprint | Jul 2026+ | Post-Sprint | Phase 3-5 | Open Beta; GA; Growth |

## Appendix C: Financial Model Sensitivity Analysis

The following table shows how MRR at Month 12 varies with changes in key assumptions:

| Variable Changed | Pessimistic | Base | Optimistic |
|-----------------|-------------|------|-----------|
| **Base case MRR** | **$1,235** | **$3,800** | **$7,600** |
| Conversion rate +5pp | $2,100 | $5,700 | $11,400 |
| Conversion rate -5pp | $400 | $1,900 | $3,800 |
| Churn rate +3pp | $800 | $2,600 | $5,300 |
| Churn rate -3pp | $1,800 | $5,200 | $10,200 |
| ARPU +$2 (more Pro adoption) | $1,500 | $4,600 | $9,200 |
| ARPU -$2 (more Starter adoption) | $950 | $3,000 | $6,000 |
| User growth 2x | $2,470 | $7,600 | $15,200 |
| User growth 0.5x | $620 | $1,900 | $3,800 |

The model is most sensitive to:
1. **Trial-to-paid conversion rate** — each percentage point represents approximately $380/mo in the base scenario at Month 12.
2. **User growth rate** — directly proportional to all revenue metrics.
3. **Churn rate** — compounds over time; a 3pp increase reduces Month 12 MRR by approximately 30%.

ARPU is the least sensitive variable because the Starter/Pro price difference is relatively small.

## Appendix D: Competitive Pricing Reference (As of March 2026)

| Platform | Free Tier | Entry Paid | Mid Paid | Top Paid | Model |
|----------|----------|-----------|---------|---------|-------|
| Roll20 | Basic (limited) | $5.99/mo Plus | $10.99/mo Pro | $14.99/mo Elite | Subscription |
| The Forge | No | $3.99/mo GM | Higher tiers available | -- | Hosting subscription |
| Foundry VTT | N/A | $50 one-time | -- | -- | Perpetual license |
| Alchemy RPG | Core (free) | Supporter tiers | -- | -- | Freemium + Marketplace |
| **DM Tool (proposed)** | **Full offline** | **$6.99-$8.99/mo** | **$11.99-$14.99/mo** | **$19.99-$24.99/mo** | **Open-Core + SaaS** |

DM Tool's positioning: **most generous free tier** (full offline functionality) with competitive hosted pricing. The self-hosted option is unique in the market and serves as a strong differentiator for the technical/privacy-conscious audience.

---

*This document should be reviewed and updated at each phase transition gate. All revenue projections are estimates and should be revised as actual data becomes available.*
