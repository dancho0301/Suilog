# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Preference

**IMPORTANT: Always respond in Japanese (日本語) when working in this repository.**

## Project Overview

Suilog is an iOS SwiftUI application that helps users track their visits to aquariums across Japan. It features:
- 82 aquariums across all regions of Japan (Hokkaido to Okinawa)
- Two check-in types: location-based (gold) and manual (silver)
- Photo and memo functionality for each visit
- Map view with real-time location tracking
- Passport (visit log) view
- SwiftData for persistent storage with schema migration support
- Theme system with StoreKit integration for in-app purchases
- Remote data updates via Firebase-hosted JSON

## Building and Testing

### Build the project
```bash
# シミュレータ向けビルド
xcodebuild -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Run tests
```bash
# Run all tests
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run unit tests only
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests

# Run UI tests only
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogUITests

# Run specific test
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SuilogTests/SuilogTests/example
```

## Architecture

### Data Layer

#### SwiftData with Schema Migration
The app uses SwiftData with versioned schemas and migration support:

- **Current Schema**: `AquariumSchemaV4` (version 4.0.0)
- **Schema Files**: `AquariumSchemaV1.swift` → `AquariumSchemaV4.swift`
- **Migration Plan**: `AquariumMigrationPlan.swift` defines lightweight migrations between versions
- **Model Definitions**:
  - `Aquarium` - 水族館マスターデータ（id, name, latitude, longitude, description, region, representativeFish, fishIconSize, address, affiliateLink）
  - `VisitRecord` - 訪問記録（id, visitDate, memo, photoData, checkInType, aquarium）
- **Relationships**: `Aquarium` has one-to-many relationship with `VisitRecord` using `@Relationship(deleteRule: .cascade)`

**IMPORTANT**: When adding new fields to models:
1. Create a new schema version file (e.g., `AquariumSchemaV5.swift`)
2. Add new migration stage in `AquariumMigrationPlan.swift`
3. Use lightweight migration if possible (new optional fields with defaults)

### Remote Data Management

#### Firebase-hosted JSON Data
Aquarium master data is fetched from Firebase Hosting instead of being bundled in the app:

- **Data URL**: `https://suilog-3a94e.web.app/aquariums.json`
- **Loader**: `AquariumJSONLoader.swift` - Async fetch with error handling
- **Seeder**: `DataSeeder.swift` - Version-controlled updates via `UserDefaults`
- **Data Model**: `AquariumData.swift` - JSON response structure

#### Update Behavior
- **Version check**: Compares `UserDefaults("AquariumDataVersion")` with JSON `version` field
- **Offline support**: If existing data exists, silently skips update on network failure
- **First launch**: Requires network connection to fetch initial data
- **Existing aquariums**: Updates all fields while preserving visit records
- **New aquariums**: Automatically added
- **Removed aquariums**: Kept if has visit records, deleted otherwise

**To update aquarium data**: Edit `firebase/public/aquariums.json` and increment the `version` field, then deploy to Firebase Hosting.

### Theme System

#### Theme Architecture
- **Theme Model**: `Theme.swift` - Defines colors, backgrounds, and assets per theme
- **ThemeManager**: `ThemeManager.swift` - ObservableObject managing current theme selection
- **StoreManager**: `StoreManager.swift` - StoreKit 2 integration for in-app purchases

#### Adding New Themes
1. Add theme definition in `Theme.allThemes`
2. Add product ID in `StoreManager.themeProductIds`
3. Add theme assets in `Assets.xcassets/Themes/[ThemeName]/`
4. Configure product in App Store Connect

### App Structure
- **Entry Point**: `SuilogApp.swift` - Sets up ModelContainer with migration plan, calls `DataSeeder.seedAquariums()` on launch
- **Main View**: `ContentView.swift` - Tab-based interface:
  1. マイ水槽 (My Tank) - Visit statistics with animated fish
  2. マップ・検索 (Map/Search) - Map view with aquarium markers
  3. パスポート (Passport) - Visit log/history view
- **Managers**:
  - `LocationManager.swift` - GPS permissions and distance calculations
  - `ThemeManager.swift` - Theme state management
  - `StoreManager.swift` - In-app purchase handling
  - `DataSeeder.swift` - Remote data seeding
  - `AquariumJSONLoader.swift` - Firebase JSON fetching

### SwiftData Update Patterns
**IMPORTANT**: SwiftData computed properties do NOT trigger view updates. Always follow these patterns:

#### ❌ WRONG - Using computed properties
```swift
struct AquariumMapView: View {
    @Query private var aquariums: [Aquarium]

    var body: some View {
        ForEach(aquariums) { aquarium in
            // This won't update when visits change!
            if aquarium.hasVisited { /* ... */ }
        }
    }
}
```

#### ✅ CORRECT - Direct property access + Query dependency
```swift
struct AquariumMapView: View {
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord] // Triggers update when visits change

    var body: some View {
        ForEach(aquariums) { aquarium in
            // Direct access to relationship property
            let hasVisited = !aquarium.visits.isEmpty
            if hasVisited { /* ... */ }
        }
    }
}
```

### CloudKit Integration
The app is configured for CloudKit services (see `Suilog.entitlements`):
- Development environment enabled for push notifications
- CloudKit container identifiers configured
- Background modes enabled for remote notifications (`Info.plist`)

### Testing Framework
- Uses the Swift Testing framework (not XCTest)
- Tests import the `Testing` module and use `@Test` macro with `#expect(...)` assertions
- Main target is made testable via `@testable import Suilog`
