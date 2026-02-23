# App Store Submission Guide (macOS)

Use this guide from `/Users/MobieyesDev/Working/FrameImagesWithDatenTitle`.

## 1) One-time setup

1. Ensure you can build in Xcode (`Xcode 26.2` is installed on this machine).
2. Ensure `xcodegen` is installed if you need to regenerate the project:

```bash
brew install xcodegen
```

3. Generate project if needed:

```bash
./generate_xcode_project.sh
```

## 2) Configure release values

Create your local release env file:

```bash
cp .appstore.env.example .appstore.env
```

Set these in `.appstore.env`:

- `APPLE_TEAM_ID` (10-character Apple Developer Team ID)
- `APP_BUNDLE_ID` (final App Store bundle identifier)
- `APP_VERSION` (marketing version, example `1.0.0`)
- `APP_BUILD` (integer build number, example `1`)

## 3) Configure signing once in Xcode

Open:

- `/Users/MobieyesDev/Working/FrameImagesWithDatenTitle/AppStoreProject/FrameMacApp.xcodeproj`

In target `FrameMacApp` -> `Signing & Capabilities`:

1. Select your Team.
2. Keep `Automatically manage signing` enabled.
3. Keep App Sandbox enabled with:
   - `com.apple.security.app-sandbox`
   - `com.apple.security.files.user-selected.read-write`

## 4) Preflight checks

Run:

```bash
./preflight_appstore.sh
```

This verifies:

- Required plist files are valid
- Team ID, Bundle ID, Version, Build are set and valid
- App icon set files are present
- Xcode scheme exists

## 5) Archive + export for App Store Connect

Run:

```bash
./archive_appstore.sh
```

Outputs:

- Archive: `dist-appstore/FrameMacApp.xcarchive`
- Exported upload package: `dist-appstore/export/`

## 6) Upload in Xcode Organizer (recommended)

1. Open Xcode -> `Window` -> `Organizer`
2. Select the archive
3. `Distribute App` -> `App Store Connect` -> `Upload`

## 7) App Store Connect checklist

Before submitting for review, make sure App Store Connect has:

- App name, subtitle, description, keywords
- Privacy policy URL
- Support URL
- Category
- Age rating
- Screenshots for required macOS display sizes
- App privacy answers (data collection)
