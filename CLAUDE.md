# AmbuKit - Claude Code Context

## Project Overview

AmbuKit is a native iOS application for managing medical kits in emergency ambulance services. It's a Final Degree Project (TFG) for the Higher Degree in Multiplatform Application Development (DAM), 2024-2025.

The app manages inventory of medications and medical supplies in ambulances, with offline support for operations in areas without coverage (tunnels, rural areas, hospital basements).

## Tech Stack

- **Language**: Swift 6.0
- **UI Framework**: SwiftUI 6.0
- **IDE**: Xcode 16.0+
- **Platform**: iOS 17.0+
- **Backend**: Firebase 11.0+ (Firestore, Firebase Auth)
- **Architecture**: MVVM + Services
- **Local Storage**: SwiftData (transitioning to Firebase)
- **Concurrency**: Swift Concurrency (async/await, @MainActor, Sendable)
- **Testing**: XCTest

## Project Structure

```
AmbuKit/
├── App/                          # App entry point and state
│   ├── AmbuKitApp.swift         # @main entry point
│   └── AppState.swift           # Global app state (ObservableObject)
├── Core/
│   ├── Models/Firebase/         # Firestore models (*FS.swift)
│   │   ├── Audit/               # AuditLogFS, AuditServiceFS
│   │   ├── Auth/                # UserFS, RoleFS, PolicyFS
│   │   ├── Catalog/             # CatalogItemFS, CategoryFS, UnitOfMeasureFS
│   │   └── Inventory/           # BaseFS, KitFS, KitItemFS, VehicleFS
│   └── Services/Firebase/
│       ├── Auth/                # FirebaseAuthService, UserSession
│       ├── Authorization/       # AuthorizationServiceFS
│       ├── Firestore/           # CRUD services (BaseService, KitService, etc.)
│       ├── Network/             # NetworkMonitor, OffLineManager
│       ├── Seed/                # SeedDataFirebase
│       └── Sync/                # SyncServices
├── DataModel/                   # SwiftData models (legacy, being migrated)
│   ├── Entities/                # SwiftData @Model classes
│   ├── Enumerations/            # ActionKind, EntityKind, KitType, RoleKind
│   ├── Repositories/            # SwiftData repositories
│   └── Persistence/             # ModelContainerBuilder
├── Views/
│   ├── Admin/                   # Admin screens (ThresholdEditor, etc.)
│   ├── Auth/                    # LoginView
│   ├── Components/              # Reusable UI components
│   ├── Inventory/               # InventoryView
│   ├── Permissions/             # PermissionGuardView, AccessDeniedView
│   ├── Profile/                 # ProfileView
│   ├── Root/                    # RootView
│   └── Preview/                 # PreviewSupport
└── GoogleService-Info.plist     # Firebase configuration

AmbuKitTests/
├── Firebase/
│   ├── Services/                # Firebase service tests
│   └── FirebaseTestHelper.swift # Test utilities
└── SwiftData/                   # SwiftData tests
```

## Key Concepts

### User Roles
- **Programador**: Full access - manages users, kits, vehicles, configuration
- **Logistica**: Inventory and stock management (cannot create kits or users)
- **Sanitario**: Updates quantities (read-only for everything else)

### Firebase Models
All Firestore models end with `FS` suffix (e.g., `KitFS`, `UserFS`, `VehicleFS`). They implement:
- `Codable`, `Identifiable`, `Sendable`
- `@DocumentID` for Firestore document ID
- `CodingKeys` enum for field mapping
- Static `collectionName` property

### Services Pattern
Services are singletons with `@MainActor` isolation:
```swift
@MainActor
final class BaseService: ObservableObject {
    static let shared = BaseService()
    private let db = Firestore.firestore()
    // Cache management
    // CRUD operations with authorization checks
}
```

### Authorization
All CRUD operations check permissions via `AuthorizationServiceFS.allowed()`:
```swift
guard await AuthorizationServiceFS.allowed(.create, on: .base, for: actor) else {
    throw BaseServiceError.unauthorized("...")
}
```

## Common Commands

```bash
# Run tests
xcodebuild test -scheme AmbuKit -destination 'platform=iOS Simulator,name=iPhone 16'

# Build project
xcodebuild build -scheme AmbuKit -destination 'platform=iOS Simulator,name=iPhone 16'

# Open in Xcode
open AmbuKit.xcodeproj
```

## Testing

- Firebase tests use `FirebaseTestHelper` for setup/teardown
- Tests run against Firebase Emulator when available
- Test files follow pattern: `*Tests.swift`

## Code Conventions

- Spanish comments and UI strings (user-facing text)
- English code identifiers and documentation comments
- MARK comments for code organization: `// MARK: - Section Name`
- Error types as enums with `LocalizedError` conformance
- Validation methods throw descriptive errors
- Debug helpers wrapped in `#if DEBUG`

## Current Migration Status

The project is migrating from SwiftData to Firebase Firestore:
- `DataModel/` contains legacy SwiftData models
- `Core/Models/Firebase/` contains new Firestore models
- Both systems coexist during transition (see TODO in AmbuKitApp.swift)

## Important Notes

- Firebase must be configured before any Firestore operations
- Offline support via `OffLineManager` queues operations when disconnected
- All services use caching with configurable expiration (default: 300 seconds)
- Audit logging tracks all CRUD operations for compliance
