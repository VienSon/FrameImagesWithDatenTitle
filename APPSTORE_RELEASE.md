# App Store Handoff Guide

This repo is prepared so you can pull it on your Apple-developer machine and publish from Xcode.

## 1) Generate Xcode project

Install XcodeGen once:

```bash
brew install xcodegen
```

Generate project:

```bash
cd /Users/vienson/Pictures/Frame
./generate_xcode_project.sh
```

Open:

```bash
open /Users/vienson/Pictures/Frame/AppStoreProject/FrameMacApp.xcodeproj
```

## 2) Configure signing in Xcode

In target `FrameMacApp`:

1. `Signing & Capabilities`
2. Select your Team
3. Confirm Bundle Identifier (default in repo is `local.vienson.frame-mac-app`; change to your App Store ID)
4. Keep App Sandbox enabled:
   - `com.apple.security.app-sandbox`
   - `com.apple.security.files.user-selected.read-write`

## 3) Bump version/build before release

Edit in `AppStoreProject/project.yml`:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Regenerate project after edits:

```bash
./generate_xcode_project.sh
```

## 4) Archive + upload

Option A (recommended): Xcode Organizer

1. Product -> Archive
2. Validate App
3. Distribute App -> App Store Connect

Option B (CLI):

```bash
./archive_appstore.sh
```

This creates:

- `dist-appstore/FrameMacApp.xcarchive`
- `dist-appstore/export/` (upload package)

## 5) Files used for App Store build

- `AppStoreProject/project.yml` (XcodeGen spec)
- `AppStoreProject/Info.plist`
- `AppStoreProject/FrameMacApp.entitlements`
- `AppStoreProject/FrameMacApp.xcassets/AppIcon.appiconset/*`
- `AppStoreProject/ExportOptions-AppStore.plist`

## Notes

- The app is now native Swift only (no Python runtime dependency for Phase 2/3).
- Input/output folder access is via user-selected paths, compatible with App Sandbox.
