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
- SwiftData for persistent storage with version-controlled data updates

## Building and Testing

### Build the project
```bash
xcodebuild -scheme Suilog -project Suilog.xcodeproj build
```

### Run tests
```bash
# Run all tests
xcodebuild test -scheme Suilog -project Suilog.xcodeproj

# Run unit tests only
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -only-testing:SuilogTests

# Run UI tests only
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -only-testing:SuilogUITests
```

### Run a single test
```bash
# Run specific test
xcodebuild test -scheme Suilog -project Suilog.xcodeproj -only-testing:SuilogTests/SuilogTests/example
```

## Architecture

### Data Layer
- **SwiftData**: The app uses SwiftData as its persistence framework with a `ModelContainer` configured in `SuilogApp.swift`
- **Model Definitions**:
  - `Aquarium.swift` - 水族館マスターデータ（id, name, latitude, longitude, description, region）
  - `VisitRecord.swift` - 訪問記録（id, visitDate, memo, photoData, checkInType, aquarium）
- **Relationships**: `Aquarium` has one-to-many relationship with `VisitRecord` using `@Relationship(deleteRule: .cascade)`
- **Storage Configuration**: Data is persisted to disk (not in-memory) via `ModelConfiguration`

### Data Seeding and Version Management
**IMPORTANT**: The app uses a version-controlled data seeding system to safely update aquarium master data without losing user's visit records.

#### Version Control System (`DataSeeder.swift`)
- Uses `UserDefaults` to track data version with key `"AquariumDataVersion"`
- Current version is stored in `currentDataVersion` constant
- On app launch, `seedDataIfNeeded()` is called to check version and update data if needed

#### How to Update Aquarium Data
When adding or modifying aquarium data in future app updates:

1. **Edit the data** in `DataSeeder.swift` → `getAquariumData()` method
2. **Increment version** by changing `currentDataVersion` (e.g., from `1` to `2`)
3. **Build and release** the app

#### Update Behavior
- **Existing aquariums**: Updates latitude, longitude, description, and region while preserving all visit records
- **New aquariums**: Automatically added to the database
- **Removed aquariums**:
  - If has visit records → kept in database (保持)
  - If no visit records → deleted from database (削除)

#### Data Structure
Current aquarium count: 82 facilities
- 北海道: 10施設
- 東北: 6施設
- 関東: 13施設
- 中部: 18施設
- 関西: 14施設
- 中国・四国: 11施設
- 九州・沖縄: 10施設

**CRITICAL**: Never modify the version control logic without careful consideration. User data (visit records, photos, memos) must always be preserved during updates.

### App Structure
- **Entry Point**: `SuilogApp.swift` - Defines the app lifecycle, sets up the shared `ModelContainer`, and calls `seedDataIfNeeded()` on app launch
- **Main View**: `ContentView.swift` - Tab-based interface with three tabs:
  1. マイ水槽 (My Tank) - Home view showing visit statistics
  2. マップ・検索 (Map/Search) - Map view with aquarium markers
  3. パスポート (Passport) - Visit log/history view
- **Views**:
  - `MyTankView.swift` - Displays user's visit statistics and achievements
  - `AquariumMapView.swift` - Map with markers, list view, and detail sheets
  - `PassportView.swift` - Visit history with photos and memos
  - `LocationCheckInView.swift` - Location-based check-in (gold badge)
  - `ManualCheckInView.swift` - Manual check-in with date picker (silver badge)
  - `EditVisitRecordView.swift` - Edit existing visit records
- **Managers**:
  - `LocationManager.swift` - Handles GPS permissions and distance calculations
  - `DataSeeder.swift` - Version-controlled aquarium data seeding
- **Data Access**: Uses `@Query` property wrapper for reactive data fetching from SwiftData

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

This pattern is used in:
- `AquariumMapView.swift:16` - Map marker updates
- `AquariumListView.swift:80` - List checkmark updates
- `AquariumDetailView.swift` - Visit history display

### CloudKit Integration
The app is configured for CloudKit services (see `Suilog.entitlements`):
- Development environment enabled for push notifications
- CloudKit container identifiers configured
- Background modes enabled for remote notifications (`Info.plist`)

### Testing Framework
- Uses the Swift Testing framework (not XCTest)
- Tests import the `Testing` module and use `@Test` macro with `#expect(...)` assertions
- Main target is made testable via `@testable import Suilog`
