# Monetization Strategy — Dungeon Master Tool

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Supersedes:** `docs/archive/MONETIZATION_STRATEGY.md`
> **Scope:** Complete revenue strategy, pricing model, legal compliance, marketing, and growth roadmap

---

## Table of Contents

1. [Business Model Overview](#1-business-model-overview)
2. [Pricing Tiers](#2-pricing-tiers)
3. [Paywall Principles](#3-paywall-principles)
4. [Competitive Analysis](#4-competitive-analysis)
5. [Phased Revenue Roadmap](#5-phased-revenue-roadmap)
6. [Legal and License Compliance](#6-legal-and-license-compliance)
7. [Analytics and KPIs](#7-analytics-and-kpis)
8. [Community and Growth](#8-community-and-growth)
9. [Marketing Strategy](#9-marketing-strategy)
10. [Risk Register](#10-risk-register)

---

## 1. Business Model Overview

### Model: Open-Core + Hosted SaaS

The Dungeon Master Tool operates on an **Open-Core** model with a hosted **Software-as-a-Service** offering. The distinction is critical:

| Layer | Status | Revenue |
|---|---|---|
| Offline desktop application | Always free, always open | None (lead gen, trust building) |
| Self-hosted online server | Free code, DM runs own server | None |
| **Hosted online server** | **Paid service** | **Subscription revenue** |
| Premium marketplace content | Paid per item | Transaction revenue |
| Enterprise / education licenses | Custom pricing | Contract revenue |

### Why This Model Works for TTRPGs

1. **DMs are value-maximizers, not price-minimizers.** The TTRPG community invests heavily in their hobby — books, dice, miniatures, battlemaps. A $7–$15/month tool that improves the session experience is a low-cost upgrade compared to a $50 sourcebook.

2. **The free tier is genuinely excellent.** An offline-capable, feature-rich desktop tool at no cost builds goodwill and a large community base. Conversion happens when DMs want to go online — a natural expansion of their use case.

3. **Self-hosting preserves the trust of power users.** Technical DMs who refuse to pay for hosting can still run their own server. This community becomes advocates, not detractors. Their engagement enriches the community wiki and package ecosystem.

4. **Hosted SaaS solves the real pain point.** Most DMs are not system administrators. Running a server, managing TLS, handling updates — these are friction points that the hosted service removes. The price is for convenience and reliability, not for the features themselves.

---

## 2. Pricing Tiers

### Tier Structure

```
┌──────────────────────────────────────────────────────────────────────┐
│  FREE                                                                 │
│  ─────────────────────────────────────────────────────────────────   │
│  • Full offline desktop application (all features)                   │
│  • Self-hosted online server (bring your own infrastructure)         │
│  • Community support (Discord, GitHub Issues)                        │
│  • All future offline features included                              │
│  • All security patches included                                     │
│  • Data portability: export campaign at any time                     │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  HOSTED STARTER             $7.99 / month  ($6.99/mo if annual)      │
│  ─────────────────────────────────────────────────────────────────   │
│  Everything in Free, plus:                                           │
│  • 1 active session at a time (up to 6 players)                      │
│  • 5 GB asset storage (maps, images, audio, PDFs)                    │
│  • Daily automated backups (7-day retention)                         │
│  • One-click restore                                                  │
│  • Email support (48-hour response)                                  │
│  • DM Tool hosted server — no setup required                         │
│  • Automatic updates (server-side)                                   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  HOSTED PRO                $13.99 / month  ($11.99/mo if annual)     │
│  ─────────────────────────────────────────────────────────────────   │
│  Everything in Starter, plus:                                        │
│  • 3 active sessions simultaneously (multiple campaigns)             │
│  • 20 GB asset storage                                               │
│  • Daily backups (30-day retention)                                  │
│  • Priority restore (< 2-hour SLA)                                   │
│  • Priority email support (24-hour response)                         │
│  • Custom subdomain: yourcampaign.dmtool.app                         │
│  • Session analytics (session duration, player retention)            │
│  • Advanced event log export (CSV, JSON)                             │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  HOSTED CREATOR / TEAM (v2 — planned)     Pricing TBD               │
│  ─────────────────────────────────────────────────────────────────   │
│  For content creators, game store groups, streamed campaigns:        │
│  • Unlimited sessions                                                 │
│  • 100 GB asset storage                                              │
│  • Team workspace (shared campaign library)                          │
│  • Custom roles (head DM, co-DM, player)                             │
│  • Analytics dashboard (viewers, session frequency, engagement)      │
│  • White-label option (custom branding)                              │
│  • Dedicated support                                                  │
└──────────────────────────────────────────────────────────────────────┘
```

### Annual vs. Monthly Pricing

| Tier | Monthly | Annual (per month) | Annual Savings |
|---|---|---|---|
| Hosted Starter | $7.99 | $6.99 | ~13% |
| Hosted Pro | $13.99 | $11.99 | ~14% |

Annual billing is strongly encouraged — it improves cash flow predictability and reduces churn.

### Price Anchoring

The core pricing logic:
- **Starter < 2 cappuccinos/month** — removes friction for impulse conversion
- **Pro < a single D&D sourcebook per year** — frames the annual cost in terms DMs already accept
- **Free tier is genuinely complete** — no feature-paywalling of core DM workflow

---

## 3. Paywall Principles

### What Is NEVER Behind a Paywall

These items must always be free, regardless of tier. Paywall violations here would destroy community trust:

| Item | Reason |
|---|---|
| Offline desktop application (all current features) | Core product promise; DMs should never fear losing their tools |
| All offline feature additions (generators, advanced battlemap, etc.) | Growth of offline capability is a community investment, not a revenue gate |
| User data access and portability | DMs own their campaign data; full export is a right, not a premium |
| Security patches for offline + self-hosted | Unpatched security vulnerabilities cannot be held behind a paywall |
| Self-hosted server code and documentation | Preserves trust with the technical community |
| Open5e API access (external service) | We don't control this; cannot paywall external data |

### What Is Behind a Paywall

| Item | Tier | Rationale |
|---|---|---|
| Hosted server infrastructure | Starter+ | Real operational cost: compute, storage, bandwidth |
| Automated backup and restore | Starter+ | Storage + automation labor cost |
| Asset storage beyond local disk | Starter+ | Direct MinIO storage cost |
| Email support | Starter+ | Labor cost |
| Custom subdomain | Pro+ | Management overhead |
| Multi-session concurrency | Pro+ | Server resource cost per active session |
| Session analytics | Pro+ | Compute + storage for aggregation |
| Team features, white-labeling | Creator+ | Development + operational cost |

### The Fairness Test

Before adding anything to the paywall, apply this test:

> *"Would a DM who has paid for the app feel cheated if this feature were paywalled?"*

If yes — it belongs in the free tier or must be grandfathered for existing users. If no (it's clearly an operational service cost) — paywalling is legitimate.

---

## 4. Competitive Analysis

### TTRPG VTT Market Overview

| Product | Type | Free Tier | Paid Tiers | Key Differentiator |
|---|---|---|---|---|
| **Roll20** | Hosted web VTT | Limited (free campaigns) | Plus $5.99/mo, Pro $10.99/mo, Elite $14.99/mo | Largest community, D&D 5e integration |
| **Foundry VTT** | Self-hosted / desktop | None | $50 one-time purchase | Highly extensible, mod ecosystem |
| **The Forge** | Foundry hosting | None | $5–$15/mo (storage-based) | Foundry without server management |
| **Alchemy** | Hosted web VTT | Limited | $5–$10/mo | Modern UI, easy onboarding |
| **Owlbear Rodeo** | Hosted web | Full free | $10/mo (legacy room persistence) | Minimal friction, no account needed |
| **DM Tool** | Desktop + hosted | **Full offline** | $7.99–$13.99/mo | **Offline-first power + online simplicity** |

### Positioning

**vs. Roll20:** Roll20's free tier restricts campaigns and paywalls key features. DM Tool's free tier is the full desktop product — a stronger value proposition for DMs who run long campaigns. We win on feature depth for the DM.

**vs. Foundry:** Foundry is more powerful but requires technical setup and a $50 upfront cost. DM Tool is free to start. Foundry appeals to modders; DM Tool appeals to DMs who want a polished out-of-box experience.

**vs. The Forge:** The Forge is Foundry hosting, not a standalone product. Our hosted service is simpler because we control the full stack — no mismatch between client and server versions.

**vs. Owlbear Rodeo:** Owlbear is minimal by design. DM Tool has significantly deeper features (audio, mind map, entity management). We target DMs who want more, not less.

**Our Unique Position:**
- The only TTRPG tool with a **full-featured offline desktop client** as the foundation
- System-agnostic but D&D 5e-ready out of the box
- Offline-first makes it **viable for groups with unreliable internet or privacy requirements**
- Native desktop performance (PyQt6) vs. browser-based competitors

---

## 5. Phased Revenue Roadmap

### Phase 0 — Closed Alpha (Now through Jun 2026)

**Revenue: $0**

Focus: Build product quality. No subscription required.

- Closed invite-only beta for select DMs
- Collect structured feedback via post-session surveys
- Identify deal-breaker bugs before public launch
- Build the waitlist: blog posts, Reddit community, Discord server
- Target waitlist size: 500+ DMs before public beta

---

### Phase 1 — Public Beta (Jul 2026 – Sep 2026)

**Revenue: $0 initially → Early Adopter pricing**

**"Founding DM" Early Adopter Program:**
- First 200 DMs who sign up get **lifetime 50% discount** on the Hosted Starter tier ($3.99/mo instead of $7.99/mo)
- First 50 DMs who sign up for Pro get **lifetime 30% discount** ($9.79/mo instead of $13.99/mo)
- Founding DMs get a permanent "Founding DM" badge in the community + Discord role
- Founding DM slots are limited and publicly visible ("48 of 200 Founding DM slots remaining")

**Rationale:** Early pricing validates willingness to pay without committing to a business model before product-market fit is confirmed.

---

### Phase 2 — Monetization Launch (Oct 2026)

**Revenue: Subscription begins**

- Standard pricing goes live for all new subscribers
- Annual billing option introduced
- Hosted Starter and Hosted Pro fully operational
- Payment processing: Stripe (recurring billing, webhook-based subscription lifecycle)
- Self-serve cancellation, plan upgrade/downgrade
- Invoice generation for Pro users who need receipts

**Target MRR at end of Phase 2: $1,000 – $5,000**

---

### Phase 3 — Marketplace (Q1 2027)

**Revenue: Subscription + Marketplace commission**

- Community Wiki + Package marketplace goes live
- **Creator monetization:** Package creators set their own price ($1–$20 per download)
- **Platform commission:** 20% of each paid download (80% to creator)
- Free packages are always free
- Paid packages require a Hosted Starter or Pro subscription to install (community gatekeeping)

**Target MRR at end of Phase 3: $5,000 – $20,000**

**Additional Revenue Stream: Premium Content Packs**
- Official premium packages released by the DM Tool team: curated monster packs, soundtrack packs, premium world templates
- Priced at $5–$15 per pack
- One-time purchase (not subscription)

---

### Phase 4 — Scale (2027+)

**Revenue: Subscription + Marketplace + Enterprise**

- **Hosted Creator/Team tier** launches
- **Education licenses:** Game clubs, universities, TTRPG therapy programs
- **Content creator affiliate program:** YouTube DM content creators get a referral commission (15–20% of first year subscription)
- **Patron/supporter tier:** Community members who want to directly support development ($5–$25/mo voluntary contribution with cosmetic acknowledgment only)
- **Enterprise/Publisher licensing:** Paid licensing for publishers (Kobold Press, MCDM, etc.) to distribute official content through the marketplace
- **API access tier:** For third-party apps that want to integrate with DM Tool session data

---

### Revenue Projections (Conservative)

| Period | Subscribers | ARPU/mo | MRR | ARR |
|---|---|---|---|---|
| Oct 2026 launch | 100 | $8 | $800 | $9,600 |
| Q1 2027 | 300 | $9 | $2,700 | $32,400 |
| Q2 2027 | 600 | $9.50 | $5,700 | $68,400 |
| Q4 2027 | 1,200 | $10 | $12,000 | $144,000 |
| 2028+ | 3,000+ | $10.50 | $31,500+ | $378,000+ |

*ARPU increases as more Pro users convert and marketplace adds transaction revenue.*

---

## 6. Legal and License Compliance

This section is **mandatory reading before any commercial launch**. Violations could result in takedown notices, loss of assets, or legal liability.

### 6.1 Asset License Audit

Before commercial launch, every asset shipped with or available through the DM Tool must be audited for commercial use rights.

**Categories to audit:**

| Category | Audit Status | Action Required |
|---|---|---|
| Application icons and UI artwork | Pending | Verify commercial license or commission custom artwork |
| Bundled audio files (ambient sounds, music) | **CRITICAL** | Many free audio assets are CC BY-NC (NonCommercial) — incompatible with commercial use |
| SRD monster artwork / card artwork | Pending | Check Open5e asset licenses; replace NonCommercial assets |
| Font files (UI fonts) | Pending | Verify OFL or commercial license |
| Community wiki package assets | Ongoing | Require creators to declare license; filter NonCommercial from paid marketplace |

**Audit process:**

1. Enumerate every asset file shipped with the installer
2. For each asset, identify the original source and license
3. Mark as: ✅ Commercial OK / ⚠️ Requires attribution / ❌ NonCommercial — must replace
4. For ❌ assets: find a commercially-licensed replacement before launch

**Recommended replacement sources for audio:**
- [Incompetech (Kevin MacLeod)](https://incompetech.com) — CC BY 4.0 (commercial OK with attribution)
- [Freesound.org](https://freesound.org) — filter by "Commercial use allowed"
- [Epidemic Sound](https://www.epidemicsound.com) — commercial subscription
- Commission original music (budget item: $500–$2000 for a starter pack)

### 6.2 D&D 5e SRD and Open Game License

**Current status:** The app uses the D&D 5e SRD (System Reference Document) via the Open5e API.

**Key facts:**
- The SRD content is licensed under the Open Game License (OGL) v1.0a
- The OGL **does not restrict commercial use** of the licensed content
- You may NOT use D&D trademarks (the D&D logo, "Dungeons & Dragons") without a separate license
- Wizards of the Coast updated their licensing approach in 2023 — stay current with their announcements
- Alternative: Transition fully to Open5e's content, which is under Creative Commons

**Action items:**
- Remove any D&D trademarks from the app UI (replace with "D&D 5e SRD" or "5e compatible")
- Review all marketing materials for inadvertent trademark use
- Monitor WotC license announcements; consult legal counsel if the OGL changes

### 6.3 Open5e API Terms of Service

The Open5e API is free to use and the data is openly licensed. However:
- Do not mirror or redistribute the Open5e dataset without reviewing their terms
- The app currently fetches from the API — this is fine for the free tier
- For the hosted version: consider caching aggressively to reduce API dependency; communicate with the Open5e team about your use case

### 6.4 GDPR and Data Privacy (EU Users)

If any users are in the European Union, GDPR applies. Required before commercial launch:

**Mandatory GDPR compliance items:**
- **Privacy Policy:** Document what data is collected (account info, session metadata, campaign data), how it's stored, and retention periods. Must be linked from the app and website.
- **Terms of Service:** Define user rights, service limits, and acceptable use.
- **Data Residency:** Clarify where user data is stored (server location). If EU users are a target market, consider offering an EU-hosted option.
- **Right to Erasure:** Users must be able to delete their account and all associated data via self-service.
- **Data Portability:** Users must be able to export all their data (campaign files, session logs) in a standard format.
- **Cookie Consent:** If a web player is offered, cookie consent banner is required.
- **Data Processor Agreements:** If using Stripe (payment) or any cloud provider (hosting), ensure DPA agreements are signed.

**Recommended approach:**
- Use a privacy policy generator for SaaS (Termly, Iubenda) as a starting point
- Engage a GDPR-specialist attorney for review before launch (cost: $500–$2000)
- Implement account deletion workflow in Sprint 8 or a post-launch patch

### 6.5 Payment Processing Compliance

**Stripe** is recommended for payment processing:

- Stripe handles PCI DSS compliance for card data storage — the app never touches raw card numbers
- Stripe Checkout or Stripe Customer Portal provides subscription management UI
- Tax handling: use Stripe Tax (automatic tax calculation for all jurisdictions)
- Refund policy must be defined: recommend 7-day no-questions-asked refund for new subscribers

**VAT / Sales Tax:**
- EU VAT applies to digital services sold to EU consumers
- US sales tax varies by state — Stripe Tax handles this automatically
- Consider Canadian GST/HST if targeting Canadian players
- Document your tax registration status in the Terms of Service

---

## 7. Analytics and KPIs

### 7.1 Business KPIs

| KPI | Definition | Target |
|---|---|---|
| Monthly Recurring Revenue (MRR) | Sum of all active subscription payments in a month | See §5 projections |
| Annual Recurring Revenue (ARR) | MRR × 12 | See §5 projections |
| Monthly Active Users (MAU) | Unique users who start at least one session per month | Growing > 20% MoM in beta |
| Conversion Rate | Free → Paid conversion | Target: ≥ 3% (industry average for dev tools: 2–5%) |
| Churn Rate | Subscribers who cancel per month | Target: < 5% monthly (< 3% with annual billing) |
| Customer Lifetime Value (LTV) | Average revenue per subscriber × average retention | Target: > $100 (implies > 12-month average retention) |
| Customer Acquisition Cost (CAC) | Marketing spend / new subscribers | Target: CAC < LTV / 3 |
| Net Promoter Score (NPS) | Likelihood to recommend (0–10 scale) | Target: > 50 |

### 7.2 Product KPIs

| KPI | Definition | Target |
|---|---|---|
| Sessions per active DM per week | Measures genuine use vs. signup-and-abandon | ≥ 1.5 sessions/week |
| Session duration | How long DMs actually use it per session | ≥ 2 hours (typical TTRPG session) |
| Player join rate | Players joining per session (proxy for DM value) | ≥ 3 players per session |
| Feature adoption rate | % of DMs using audio, mind map, battlemap | > 60% of DMs use audio; > 80% use battlemap |
| Support ticket volume | Tickets per 100 subscribers | Decreasing over time; < 5/100/month at maturity |

### 7.3 Instrumentation Plan

**What to track (opt-in, anonymized):**

Events that should be instrumented in the application (with explicit user consent in the privacy policy and an opt-out toggle):

| Event | Why |
|---|---|
| Session started | Measures genuine use |
| Session duration | Engagement metric |
| Player joined (count, not identity) | Measures social reach |
| Feature used (audio/mindmap/battlemap/combat) | Feature adoption |
| Subscription created / upgraded / cancelled | Revenue events |
| Error occurred (type, not content) | Product quality signal |

**What NOT to track:**
- Campaign content (entity names, notes, map content)
- Player identities or names
- Session chat or event log content
- Any personally identifiable information without explicit consent

**Instrumentation tools:**
- Lightweight self-hosted analytics: Plausible (privacy-focused, GDPR-compliant)
- Application error tracking: Sentry (anonymized, self-hosted option available)
- Revenue tracking: Stripe Dashboard (native)

---

## 8. Community and Growth

### 8.1 Pre-Launch Community Building

The most important growth action is building a community **before** the paid product launches. A community of 1,000 active DMs before launch is worth more than any paid marketing.

**Channels to establish (start now):**

| Channel | Purpose | Target Before Launch |
|---|---|---|
| **Discord server** | Primary community hub, feedback, support | 500 members |
| **Reddit presence** (r/DMAcademy, r/DnD, r/rpg) | Organic discovery via helpful posts/demos | 50+ upvoted posts/comments |
| **GitHub** | Open source presence, issue tracker, community trust | Visible, active development |
| **itch.io** | TTRPG tool discovery platform; free listing | Listed, with demo video |
| **YouTube** | Demo videos, tutorials, "session prep with DM Tool" | 3+ videos, 500+ combined views |
| **Twitter/X + Mastodon** | Announce updates, engage with TTRPG community | Regular posting cadence |

**Discord server structure:**
```
#announcements       — Updates, release notes
#get-started         — Onboarding, FAQ
#general             — Community discussion
#session-stories     — DMs sharing their experiences
#feature-requests    — Structured feature discussion
#beta-feedback       — Closed beta feedback channel
#bug-reports         — Issue reporting with template
#show-your-maps      — Community maps and battlemaps
#dev-updates         — Behind-the-scenes development updates
```

### 8.2 Content Creator Program

**Goal:** Turn active community members and TTRPG YouTubers into advocates.

**Referral program (at monetization launch):**
- Every subscriber gets a unique referral link
- Referrer receives **1 month free** for each new paid subscriber they bring
- Referred subscriber receives **15% off their first 3 months**
- No cap on referral earnings (a DM who refers 12 people gets a free year)

**Content creator affiliate program:**
- Apply via Discord (minimum: 1,000 YouTube subscribers or 5,000 social followers)
- Affiliates receive a **20% commission** for 12 months on all new subscribers from their link
- Affiliates receive a **Pro account free** while generating at least 3 new subscribers/month
- Monthly payout via Stripe (minimum threshold: $25)

**Package creator program:**
- Any DM can publish free or paid packages to the community wiki
- Paid packages earn **80% of the sale price** (20% platform fee)
- Featured creator status for packages with 4.5+ stars and 100+ downloads
- Annual "DM Tool Creator Awards" (community voting)

### 8.3 Open-Source Strategy

Publishing select components as open source builds trust, generates developer interest, and creates free marketing:

**Recommended open-source releases:**
- `dmt-event-schema`: The Pydantic event schema models (useful for third-party integrations)
- `dmt-player-sdk`: A minimal Python/JavaScript client for building custom player interfaces
- `dmt-package-validator`: The package validation tool for `.dmt-template` etc.

**Benefits:**
- Attracts developer contributors
- Signals transparency and longevity ("the data format is open even if the service isn't")
- Creates discussion on HackerNews, Reddit r/programming, etc.

---

## 9. Marketing Strategy

### 9.1 Target Audience

**Primary audience:** Tabletop RPG dungeon masters / game masters
- **Age:** 18–45
- **Platform preference:** Desktop (Windows primary, Linux/Mac secondary)
- **Tech comfort:** Moderate to high — willing to install a desktop app
- **Pain points:** Managing battle maps, tracking combat, displaying content to players, session prep time, keeping campaign notes organized
- **Current tools:** Roll20, Foundry, Notion + physical dice, Word/Google Docs, Obsidian

**Secondary audience:** TTRPG content creators (YouTubers, Twitch streamers, podcasters)
- Need polished, professional-looking tools on screen
- Value: mind map for world-building streams, battlemap for actual-plays

**Tertiary audience:** TTRPG educators and therapists
- Using TTRPG as a structured activity
- Need reliability, offline capability, and privacy

### 9.2 Key Messages

1. **"Everything you need at the table, nothing you don't."** — Depth without bloat.
2. **"Your campaign lives on your machine."** — Offline-first, data sovereignty.
3. **"Your players join in seconds."** — Six-character code, no accounts required for players.
4. **"Built for DMs, by someone who runs campaigns."** — Authenticity and care in design.

### 9.3 Channel Strategy

#### Reddit (Primary Discovery Channel)

**r/DMAcademy**, **r/DnD**, **r/rpg**, **r/mattcolville** (if stream alignment), **r/FoundryVTT** (competitive), **r/virtualTabletop**

**Approach:**
- Share genuinely helpful posts about session prep, DM tools, campaign management — not just product promotion
- Show-don't-tell: post screenshots/GIFs of interesting tool features in context ("How I prepare combat with [screenshot]")
- AMA (Ask Me Anything) as the developer — authenticity builds trust
- Never post promotional content without "Made this myself" disclosure (Reddit rules)

**Target:** 2–3 posts per week; at least one becomes a top post (1,000+ upvotes) before launch

#### YouTube (Long-Form Discovery)

**Types of videos:**
- "Full session prep in 20 minutes with DM Tool" — high value, demonstrates real use
- "How I manage 30 NPCs without losing my mind" — mind map feature showcase
- "Setting up an online session with your players in 5 minutes" — online feature launch video
- Tutorial series: beginner, intermediate, power user

**Target creators to collaborate with:**
- DM channels with 50k–500k subscribers (approachable, genuine fit)
- Approach: free Pro account + co-branded content

#### Twitch (Live Discovery)

- Stream development sessions — "building the DM Tool live" before launch
- Partner with small/medium TTRPG streamers for one-session playtests
- Sponsor official D&D/TTRPG community streams during launch period

#### itch.io

- List the app as a free TTRPG tool
- itch.io has a large TTRPG discovery community — many DMs start there
- "Pay what you want" model for the offline version allows voluntary support

#### SEO / Content Marketing

Target keywords:
- "best dungeon master tool"
- "DM campaign management software"
- "virtual tabletop offline"
- "D&D 5e combat tracker desktop"
- "TTRPG session prep software"

Blog posts on the website (once it exists):
- "How to run your first online TTRPG session"
- "The best free DM tools for 2026"
- "DM screen vs. digital tools — which is right for you?"

### 9.4 Launch Timing

| Event | Timing | Notes |
|---|---|---|
| Discord server goes live | Now (Mar 2026) | Start community building immediately |
| Public beta announcement | Jul 2026 | Coordinate with online feature readiness |
| Founding DM program opens | Jul 2026 | Limited slots create urgency |
| Reddit AMA | Aug 2026 | After 2+ weeks of beta feedback |
| YouTube launch video | Sep 2026 | Polished demo with real session footage |
| Paid subscriptions begin | Oct 2026 | After product quality is proven in beta |
| Marketplace opens | Q1 2027 | After subscription base is established |

---

## 10. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| WotC changes the OGL or D&D brand licensing | MEDIUM | HIGH | Design app as system-agnostic first; D&D 5e SRD is layered on top, not baked in. Alternative: pivot to PF2e or generic 5e. |
| Open5e API becomes unavailable or paid | LOW | MEDIUM | Bundle SRD data as a local database; remove API dependency for core content |
| Roll20 adds a competing offline-first desktop client | LOW | HIGH | Accelerate online feature delivery; deepen offline differentiation (mind map, audio, world templates) |
| Hosting costs exceed revenue at scale | MEDIUM | MEDIUM | Set storage/bandwidth caps per tier; use metered billing for overages; negotiate enterprise MinIO pricing |
| Asset license violation discovered post-launch | LOW | CRITICAL | Complete audit before launch (§6.1); have replacement plan ready for critical assets |
| GDPR non-compliance complaint | MEDIUM | HIGH | Engage GDPR counsel before launch; implement full data deletion flow; store EU data in EU region |
| Beta users churn before paid launch (Founding DM program doesn't convert) | MEDIUM | HIGH | Validate willingness-to-pay early via a $1 "reserve your spot" beta fee; measure engagement before offering Founding pricing |
| Player adoption failure (DMs subscribe but players don't join) | MEDIUM | HIGH | Minimize player friction; no account required to join; test join flow with real non-technical players before launch |
| Single developer burnout (if solo project) | HIGH | CRITICAL | Prioritize ruthlessly; accept community contributions for non-core features; consider hiring a part-time contributor after ARR > $50k |
| Competitor acqui-hire or copy the key differentiators | LOW | MEDIUM | Build community moat (Discord, creator program, content library); differentiation through execution speed and community trust, not feature list alone |

---

## Appendix A: Stripe Integration Checklist

Before activating paid subscriptions:

- [ ] Stripe account verified and bank connected
- [ ] Test mode payments working end-to-end
- [ ] Stripe Customer Portal configured (DMs can upgrade, downgrade, cancel self-service)
- [ ] Webhook handler implemented for: `customer.subscription.created`, `customer.subscription.deleted`, `invoice.payment_failed`
- [ ] Stripe Tax configured (automatic tax calculation enabled)
- [ ] Refund policy defined in Terms of Service
- [ ] Invoice generation enabled for Pro tier
- [ ] Annual billing option configured
- [ ] Founding DM discount codes created (Stripe coupon objects)

---

## Appendix B: Pre-Launch Legal Checklist

Before the first paying subscriber:

- [ ] Terms of Service drafted and reviewed by legal counsel
- [ ] Privacy Policy drafted, reviewed, and GDPR-compliant
- [ ] Cookie consent implemented (for any web component)
- [ ] Data deletion flow implemented (self-service account deletion)
- [ ] Data export flow implemented (full campaign export)
- [ ] Asset license audit complete — all ❌ assets replaced
- [ ] D&D trademark usage removed from marketing and UI
- [ ] OGL compliance confirmed with SRD usage
- [ ] Stripe DPA signed
- [ ] Hosting provider DPA signed
- [ ] VAT/sales tax registration reviewed (consult accountant in target markets)
- [ ] Refund policy documented and implemented in Stripe
