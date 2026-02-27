# Frame Mobile (Flutter)

Simple camera app for iOS/Android:
- Take photo
- Add title
- Auto include date/time + location name (fallback to latitude/longitude)
- Save framed result to gallery
- No photo crop/trim (photo stays full, border is added around it)

## 1) Install Flutter and create platform folders

This folder was generated without running Flutter CLI. After installing Flutter, run:

```bash
cd /Users/vienson/Pictures/Frame/frame_mobile
flutter create .
flutter pub get
```

## 2) iOS permissions

Edit `/Users/vienson/Pictures/Frame/frame_mobile/ios/Runner/Info.plist` and add:

```xml
<key>NSCameraUsageDescription</key>
<string>Need camera access to take photos.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Need location to add place name to photo frame.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Need photo library access to save framed photos.</string>
```

## 3) Android permissions

Edit `/Users/vienson/Pictures/Frame/frame_mobile/android/app/src/main/AndroidManifest.xml`.

Add these permissions (outside `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
```

If camera preview is stretched, ensure your activity supports full screen and test on a physical device.

## 4) Run

```bash
flutter run
```

## Notes

- Border is generated into a new canvas, so original photo pixels are not trimmed.
- If geocoding fails, app saves latitude/longitude text instead.
- Title defaults to `Untitled` when empty.
