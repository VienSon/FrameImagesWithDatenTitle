# Frame Mac App - What's New (from V1)

## V1.0.0

- Initial macOS release of Frame Studio.
- Batch process images from a folder with customizable frame settings.
- Editable metadata table for `Capture Date` and `Title`.
- Typography and layout controls (pixels/percent border modes, title/date fonts).
- Saved settings presets (save, load, delete).
- Native output rendering with image metadata preservation.

## V1.1.0

- Added option to auto-create and use `Framed` subfolder inside Input folder for output.
- File selection behavior improved:
  - Only checkbox toggles include/exclude selection.
  - Row selection is now used for preview.
- Added image preview panel in Files section when a row is selected.
- Added multi-row title sync:
  - Enter one title and apply to all checkbox-selected rows.
- Restored standard macOS text editing shortcuts in fields (including `Cmd+C` copy).

---

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
