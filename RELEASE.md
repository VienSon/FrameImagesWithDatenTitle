# Phase 3 Release Guide (Sign + Notarize)

## 1) Build and Sign the `.app`

For local testing (ad-hoc signing):

```bash
./build_app_bundle.sh
```

For distribution (Developer ID + hardened runtime):

```bash
./build_app_bundle.sh \
  --release-signing \
  --sign-identity "Developer ID Application: YOUR NAME (TEAMID)" \
  --bundle-id "com.yourcompany.frame-mac-app" \
  --version "1.0.0" \
  --build "1"
```

## 2) Create DMG

```bash
./create_release_dmg.sh
```

Output:

- `dist/Frame Mac App.app`
- `dist/Frame-Mac-App.dmg`

## 3) Configure notarytool profile (one-time)

```bash
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## 4) Notarize and Staple

```bash
export NOTARY_PROFILE=AC_NOTARY
./notarize_release.sh
```

This notarizes and staples both:

- `dist/Frame Mac App.app`
- `dist/Frame-Mac-App.dmg`

## 5) Verify

```bash
./verify_release.sh
```

`spctl` should report accepted/notarized status after stapling.
