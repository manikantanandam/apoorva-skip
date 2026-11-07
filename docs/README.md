# Apoorva — Planning Docs

Offline-first shop/POS app (Swift + SwiftUI, Skip for Android). Local SQLite is the source of truth; Firebase Firestore syncs in the background.

| # | Doc | Covers |
|---|-----|--------|
| 01 | [Product vision & features](01-product-vision-and-features.md) | Personas, modules, MVP vs later |
| 02 | [Requirements](02-requirements.md) | Functional + non-functional, how each is met |
| 03 | [Architecture & HLD](03-architecture-hld.md) | Layers, module graph, sync, ERD (Mermaid) |
| 04 | [UI design](04-ui-design.md) | Vertical themes, theme resolution, navigation, screen index |
| 05 | [Feature flags & config](05-feature-flags-and-config.md) | App / org / store / role flags, resolution, rollout |
| 06 | [Observability & maintenance](06-observability-and-maintenance.md) | Crashlytics, analytics, perf, runbook |
| 07 | [Build, CI/CD](07-build-ci-cd.md) | Debug/release, environments, pipelines |
| 08 | [Security & compliance](08-security-and-compliance.md) | Auth, rules, data protection, privacy, optional tax |
| 09 | [Roadmap & risks](09-roadmap-and-risks.md) | Milestones, risks, open questions, gaps |
| 10 | [Admin & multi-tenancy](10-admin-and-multi-tenancy.md) | Org/store/roles, permissions, theme & flag admin, audit |
| 11 | [NFR MVP baseline](11-nfr-mvp-baseline.md) | Minimum non-functional bar for the Store MVP, verification, release gate |

**Designs:** 140 screens in the Clean style (light + dark side by side), frozen for v1, in [`/designs`](../designs/README.md).

Diagrams are Mermaid and render in GitHub and most Markdown previews.
