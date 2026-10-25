[![Quality gate status](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=coverage)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Duplicated Lines (%)](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=duplicated_lines_density)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Lines of Code](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=ncloc)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Maintainability issues](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=software_quality_maintainability_issues)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Reliability issues](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=software_quality_reliability_issues)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Security issues](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=software_quality_security_issues)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Technical Debt](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=sqale_index)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=nanirocks125_apoorva-skip&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=nanirocks125_apoorva-skip)

# ApoorvaApp

A cross-platform Point of Sale (POS) and business management application built from scratch using Swift, SwiftUI, and the Skip framework for native iOS and Android deployment. 

The application utilizes a strict offline-first architecture, ensuring business continuity without internet access by relying on a local SQLite database (`skip-sql`), which asynchronously synchronizes with Firebase Firestore.

## 🚀 Key Features

*   **Offline-First Data Layer:** Immediate read/write access via local SQLite (`skip-sql`), with background synchronization to remote services.
*   **Cross-Platform (iOS & Android):** Written entirely in Swift and SwiftUI, transpiled to native Kotlin/Compose via the Skip framework.
*   **Daily Cashflow Management:** Track opening and closing balances, register daily transactions, and lock daily summaries.
*   **Inventory & POS:** Real-time inventory tracking, offline cart management, and seamless point-of-sale checkout.
*   **Customer & Organization Management:** Multi-tenant organization support with role-based access and customer purchase history tracking.

## 🛠 Tech Stack

*   **Language:** Swift 5.9+ / 6.0
*   **UI Framework:** SwiftUI
*   **Cross-Platform Tooling:** Skip (`skip-sql`)
*   **Local Storage:** SQLite (managed via Protocol-Oriented DAOs and `SQLCodable`)
*   **Remote Backend:** Firebase Firestore
*   **Architecture:** MVVM, Repository Pattern, Composition Root (Dependency Injection)

## 📂 Project Structure & Modularity

The project uses Swift Package Manager (SPM) to strictly enforce separation of concerns across multiple local packages:

*   **`ApoorvaAppCore`**: Contains the Composition Root (Dependency Containers) that wire up services, repositories, and UI modules without singletons.
*   **`ApoorvaModels`**: Pure Swift data models and entities conforming to `Codable` and `SQLCodable`.
*   **`ApoorvaOfflineStorage`**: The local data access layer managing the `SkipSqlDatabase` connection and Data Access Objects (DAOs) like `CategoryLocalStorage` and `InventoryItemLocalStorage`.
*   **`ApoorvaRepository`**: The single source of truth coordinating offline-first reads/writes between `ApoorvaOfflineStorage` and `ApoorvaServices`.
*   **`ApoorvaServices`**: Remote API and Firebase integration layers (e.g., `FirestoreSyncService`, `AuthService`).
*   **`ApoorvaModules`**: Feature-specific SwiftUI Views and `@Observable` ViewModels (e.g., POS, Cashflow, Login, Inventory).
*   **`ApoorvaUtilities`**: Shared extensions, formatting helpers, and UI utilities.

## 🏗 Architecture Patterns

*   **Composition Root / DI Containers:** Dependencies are injected down the stack from a centralized `AppContainer` via `ServicesContainer`, `OfflineStorageContainer`, and `RepositoryContainer`, eliminating tight coupling and singletons.
*   **Protocol-Oriented DAOs:** Local storage logic is abstracted behind protocols (e.g., `InventoryItemLocalStorageProtocol`) injected into Repositories, making the app highly testable.
*   **Modern Concurrency:** Fully utilizes Swift structured concurrency (`async/await`, `@MainActor`, `Sendable`).

## ⚙️ Getting Started

### Prerequisites
*   macOS with Xcode 15.0 or later.
*   Skip framework installed locally (Homebrew: `brew install skiptools/skip/skip`).
*   Android Studio / Android SDK (for Android deployment).

### Installation
1. Clone the repository.
2. Open `Apoorva.xcodeproj` (or the top-level `Package.swift`).
3. Ensure the active scheme is set to **Apoorva** (iOS) or **ApoorvaApp** (Skip Android target).
4. Build and run. Swift Package Manager will automatically resolve `skip-sql` and other local library dependencies. 

## 👨‍💻 Author
**Manikanta Nandam**
