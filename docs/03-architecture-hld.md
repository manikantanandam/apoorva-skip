# 03 — Architecture & High-Level Design

## 1. Layers

```mermaid
flowchart TB
  subgraph App["App shell"]
    A[Apoorva app<br/>iOS Xcode / Android Gradle via Skip]
  end
  subgraph Core["Composition"]
    AC[ApoorvaAppCore<br/>AppContainer, Router, MainView]
  end
  subgraph Feature["Presentation"]
    M[ApoorvaModules<br/>Views + @Observable VMs]
    UI[ApoorvaUI]
    VM[ApoorvaViewModel]
  end
  subgraph Data["Data"]
    R[ApoorvaRepository<br/>offline-first coordination]
    OS[ApoorvaOfflineStorage<br/>SkipSQL / GRDB]
    S[ApoorvaServices<br/>Auth, Firestore sync]
  end
  subgraph Base["Foundation"]
    MD[ApoorvaModels]
    U[ApoorvaUtilities]
  end
  A --> AC --> M
  M --> R
  R --> OS
  R --> S
  OS --> MD
  S --> MD
  M --> U
  R --> U
  OS --> U
```

## 2. Module dependency graph (from package manifests)

```mermaid
flowchart LR
  App[app Apoorva] --> AppCore[ApoorvaAppCore]
  AppCore --> Modules[ApoorvaModules]
  Modules --> Repo[ApoorvaRepository]
  Modules --> Utils[ApoorvaUtilities]
  Repo --> Storage[ApoorvaOfflineStorage]
  Repo --> Services[ApoorvaServices]
  Repo --> Utils
  Storage --> Models[ApoorvaModels]
  Services --> Models
  Models --> Utils
```

Rules:
- Views never touch storage or Firebase directly.
- Only `ApoorvaAppCore` knows concrete types; everything else depends on protocols.
- `ApoorvaUI` and `ApoorvaViewModel` are placeholders — fill when a second screen needs shared components.

## 3. Key flows

### 3.1 Create bill
```mermaid
sequenceDiagram
  participant U as User
  participant VM as ViewModel
  participant R as SaleRepository
  participant L as Local DB
  participant O as Outbox
  participant F as Firestore
  U->>VM: Tap "Save bill"
  VM->>R: save(bill)
  R->>L: insert bill + items (txn), syncState=pending
  R->>O: enqueue(bill.id)
  R-->>VM: success (local, < 200 ms)
  VM-->>U: Receipt shown
  O->>F: batch write when online
  F-->>O: ack
  O->>L: syncState=synced
```

### 3.2 Pull remote changes
```mermaid
sequenceDiagram
  participant F as Firestore
  participant S as FirestoreSyncService
  participant R as Repository
  participant L as Local DB
  F-->>S: snapshot listener (changed docs)
  S->>R: applyRemote(docs)
  R->>L: upsert if remote.updatedAt > local (or merge rule)
  L-->>R: changed rows → UI observes
```

### 3.3 Login and session
Firebase Auth → token with `shopId` custom claim → repository scoped to shop → local DB opened per shop (file name includes `shopId`).

## 4. Data model (ERD)

```mermaid
erDiagram
  SHOP ||--o{ USER : has
  SHOP ||--o{ CUSTOMER : has
  SHOP ||--o{ ITEM : sells
  CUSTOMER ||--o{ BILL : places
  BILL ||--|{ BILL_LINE : contains
  ITEM ||--o{ BILL_LINE : "sold as"
  BILL ||--o{ PAYMENT : settled_by
  ITEM ||--o{ STOCK_MOVEMENT : tracks
  SHOP ||--o{ CASH_ENTRY : records
  CASH_ENTRY }o--o| BILL : "may link"
  SUPPLIER ||--o{ PURCHASE : supplies
  PURCHASE ||--|{ STOCK_MOVEMENT : adds
  CUSTOMER ||--o{ ORDER : books
  ORDER ||--o{ PAYMENT : "advance / balance"
  ORDER |o--o| BILL : "billed on delivery"
  SHOP ||--o{ EXPENSE : spends
  MEMBER ||--o{ ATTENDANCE : marks
  MEMBER ||--o{ SALARY_ENTRY : "paid / advance"
  BILL_LINE ||--o{ WARRANTY_CLAIM : claims
```

Item adds `prices` (retail, wholesale), `unit`, `packSize`, `warrantyValue`, `warrantyUnit` (days|months|years). Bill line stores `warrantyUntil` at sale time, so later changes to the item never change past warranties.

Every table carries: `id` (UUID), `shopId`, `createdAt`, `updatedAt`, `deviceId`, `syncState`, `isDeleted`.

## 5. Cross-cutting
- **IDs:** UUIDv4 generated on device (no server round trip).
- **Time:** store UTC; display in shop timezone.
- **Money:** integer minor units (paise). Never `Double`.
- **Errors:** typed `AppError` per layer, mapped to user message in VM.
- **Logging:** `os.Logger` on iOS, Logcat via Skip; forwarded to Crashlytics for errors.

## 6. Verticals, themes, flags (one app)

```mermaid
flowchart LR
  VP[VerticalProfile<br/>id, catalogFields, defaultTheme, defaultFlags] --> BS[BillingStrategy protocol]
  BS --> K[KiranaBilling<br/>search list, weight]
  BS --> F[FancyBilling<br/>tile grid, variants]
  BS --> J[JewelleryBilling<br/>catalog, design code]
  BS --> P[ParlourBilling<br/>spot services, packages]
  TS[ThemeStore] --> UI[SwiftUI environment tokens]
  FR[FlagResolver] --> VM[View models]
  PR[PermissionService] --> VM
```

- `VerticalProfile` is data (synced from Firestore `verticals/{id}`). `BillingStrategy` is the only code per vertical: item picker view, line-item rules (weight, variant, done-by staff), receipt template. Adding handloom means one new strategy and one profile doc.
- Cart, checkout, payments, sync, ledger and analytics are shared and vertical-agnostic.
- `ThemeStore`, `FlagResolver` and `PermissionService` are built in `AppContainer` and injected. They have no globals.
- Placement: `ApoorvaUI` (ThemeStore, component kit, font loader, icon mapping Lucide → SF Symbols / Material Symbols), `ApoorvaModels` (VerticalProfile, FlagResolver, Permission, TaxPolicy), `ApoorvaModules` (Auth sign-in hub, Billing strategies incl. calculator, Orders, Suppliers & Purchases, Expenses, Staff, Warranty, Insights, Settings incl. Payments & Devices, Admin, Platform console, Developer settings). `AppEnvironment` (dev/stg/prod) is chosen at launch and passed to `AppContainer`, which builds Firebase and the local DB for that environment.

Additional entities: `ORG`, `STORE` (with `verticalId`), `MEMBER`, `ROLE`, `FLAG_OVERRIDE`, `THEME`, `AUDIT_EVENT`, `SERVICE`, `PACKAGE`, `PLAN_USAGE` (bills this month, grace used). See the ERD in [10](10-admin-and-multi-tenancy.md).

## 7. Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Source of truth | Local SQLite | Offline-first |
| Sync backend | Firestore | Already in use, real-time listeners |
| Storage backend | SkipSQL now, GRDB as iOS-only option | Shared code across iOS/Android |
| DI | Containers in AppCore | No singletons, testable |
| Multi-device conflicts | LWW per field + append-only money/stock | Simple and predictable |
