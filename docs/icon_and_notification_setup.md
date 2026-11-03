# RapidRun Icon & Notification Asset Playbook

This document provides ultra-detailed, step‑by‑step guidance for preparing all app launcher, adaptive, notification, and marketing icons for RapidRun.

---
## 0. Overview
Assets you will produce:
- `assets/branding/icon_foreground.png` (adaptive foreground, transparent 432×432)
- `assets/branding/icon_background.png` (adaptive background 432×432)
- `assets/branding/notification_icon.png` (pure white silhouette 96–432 px)
- `assets/branding/marketing_icon_1024.png` (optional store / marketing 1024×1024)
- (Optional) `assets/branding/lockup_light.png` (wordmark for splash / onboarding)

Tooling suggestions: Figma (preferred), Inkscape (free), Illustrator (ok). Maintain vectors; export PNGs only at final step.

Safe padding principle: keep ~15–18% transparent margin around the mark so adaptive masks never clip it.

---
## 1. Foreground Adaptive Icon (`icon_foreground.png`)
**Goal:** 432×432 transparent PNG of gold mark only.

1. Create frame 432×432 (name: `icon_foreground`). Background / Fill: None (transparent).
2. Import gold gradient mark SVG.
3. Scale mark to ~360 px max dimension (360–365). Maintain aspect ratio.
4. Center horizontally & vertically.
5. Visual check: ~36 px transparent padding on each side.
6. Export frame → PNG → name `icon_foreground.png` → save to `assets/branding/`.
7. Open exported PNG to confirm only mark + transparency (no tint, no matte).

_Inkscape variant:_ Set page size 432×432, align object to page center, export **Page** as PNG 432×432.

---
## 2. Adaptive Background (`icon_background.png`)
**Goal:** 432×432 PNG with dark gradient rounded rect (no mark).

1. New frame 432×432 (name: `icon_background`).
2. Corner radius: 96 (or 90–100 for rounded square).
3. Fill: Radial or linear gradient (#232323 center → #101010 edge). No stroke.
4. Export PNG to `assets/branding/icon_background.png`.
5. Confirm corners are transparent outside rounded shape.

---
## 3. White Notification Icon (`notification_icon.png`)
**Goal:** Pure white silhouette for Android notifications.

1. Duplicate flat (non‑gradient) mark.
2. Remove gradients/shadows; unify overlapping shapes (boolean union) into one white fill (#FFFFFF).
3. New frame 96×96 (name: `notification_icon_base`).
4. Scale white mark to ~72×72 (leaves 12 px padding each side).
5. Center both axes.
6. Export PNG as `notification_icon.png` into `assets/branding/`.
7. (If skipping generator) also create density variants: 24, 36, 48, 72, 96 px.
8. Zoom out (25–30%) to ensure clarity at small size.

---
## 4. Marketing Icon (`marketing_icon_1024.png`) (Optional)
**Goal:** Large 1024×1024 promotional icon.

1. Frame 1024×1024 (`marketing_icon`).
2. Background: same gradient (or refined). Optional corner radius (store masks anyway).
3. Mark size: ~720–760 px width (≈70–75%).
4. Center precisely.
5. Optional subtle shadow/glow <8% opacity.
6. Export PNG as `marketing_icon_1024.png` to `assets/branding/`.

---
## 5. Pubspec Launcher Config
Add or update (top level, **not** nested under `flutter:`):

```
flutter_launcher_icons:
  android: true
  ios: true
  image_path_ios: assets/branding/icon_foreground.png
  adaptive_icon_background: assets/branding/icon_background.png
  adaptive_icon_foreground: assets/branding/icon_foreground.png
  remove_alpha_ios: true
  android_notification_icon: assets/branding/notification_icon.png
```

Validate each referenced file exists.

---
## 6. Generate Icons
1. Stop any running `flutter run` session.
2. In project root (PowerShell):
   - `flutter pub get`
   - `flutter pub run flutter_launcher_icons`
3. Watch for success messages; ensure no "file not found" errors.

---
## 7. Firebase Notification Icon (Android)
If using firebase_messaging, add inside `<application>` in `android/app/src/main/AndroidManifest.xml`:

```
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/notification_icon" />
```

(If the generated resource name differs, adjust accordingly.)

---
## 8. Verification Checklist
- [ ] Foreground icon not clipped by circular or squircle mask.
- [ ] iOS icon edges smooth (no leftover alpha border).
- [ ] Notification icon appears crisp, pure white in status bar.
- [ ] No gradients or colors in notification icon.
- [ ] Marketing icon exported for store upload.

---
## 9. Troubleshooting
| Problem | Cause | Fix |
| ------- | ----- | --- |
| Clipped foreground | Too large mark | Reduce size (<380px) keep padding |
| Blurry background | Up-scaled small PNG | Re-export at native 432×432 |
| Notification icon colored | Used gradient asset | Replace with pure white silhouette |
| Generator error file not found | Wrong path | Verify relative path & case; rerun `flutter pub get` |
| iOS icon jagged | Low-res source | Recreate 432×432 foreground, regenerate |

---
## 10. Next Enhancements
- Add `flutter_native_splash` with mark or lockup.
- Create seasonal color variant (swap gradient stops) and script re-runs.
- Generate dark + light theme adaptive icons if you add a light theme.

---
## 11. Master Task List
[ ] icon_foreground.png
[ ] icon_background.png
[ ] notification_icon.png
[ ] marketing_icon_1024.png (optional)
[ ] Pubspec config updated
[ ] Launcher icons generated
[ ] Firebase meta-data added (if needed)
[ ] Visual verification done

---
## 12. File Locations Summary
- All PNG exports live in: `assets/branding/`
- SVG masters remain alongside for future edits.
- Generated launcher outputs: Android `android/app/src/main/res/mipmap-*`, iOS `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

---
## 13. Why 432×432?
Android adaptive icon spec base size 108dp × 4 (mdpi scaling) = 432 px. Supplying exact dimension avoids scaling artifacts.

---
## 14. Padding Formula Example
Given foreground canvas 432 px and desired mark size 360 px:
Padding = (432 - 360) / 2 = 36 px each side (~8.3%). Enough for shape masks + OEM variations.

---
Happy shipping.
