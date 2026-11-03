# Android Google Sign-In Configuration

This doc explains how to configure and maintain Google Sign-In for the Android app (`applicationId` = `com.rapidrun.rapidrun`). If misconfigured you will see `ApiException: 10 (DEVELOPER_ERROR)`.

---
## 1. Required Artifacts
- `android/app/google-services.json` (must contain an `oauth_client` with `client_type: 1` for Android)
- SHA-1 and SHA-256 fingerprints for every signing key used (debug + release/upload)

## 2. Obtain Fingerprints
Run from project root (PowerShell):
```powershell
cd android; .\gradlew signingReport
```
Copy the `SHA1` and `SHA-256` under the `Variant: debug` section.

If you have a release/upload keystore (recommended early):
```powershell
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 3650 -alias rapidrun_upload -keystore rapidrun_upload.jks
keytool -list -v -keystore rapidrun_upload.jks -alias rapidrun_upload
```
Store `rapidrun_upload.jks` outside version control.

## 3. Register Fingerprints in Firebase
1. Firebase Console → Project Settings → Your apps → Android app (`com.rapidrun.rapidrun`).
2. Click "Add fingerprint"; add ALL:
   - Debug SHA-1 & SHA-256
   - Release SHA-1 & SHA-256 (if available)
3. Save. Then re-download `google-services.json` and replace the existing one.

## 4. Enable Provider
Firebase Console → Authentication → Sign-in method → Enable Google and set a support email.

## 5. Clean & Rebuild After Changes
```powershell
flutter clean
flutter pub get
flutter run
```
Hot restart is not enough after changing `google-services.json`.

## 6. Validating Success
Your updated `google-services.json` should now include a block similar to:
```json
"oauth_client": [
  { "client_id": "<hash>.apps.googleusercontent.com", "client_type": 1, "android_info": { "package_name": "com.rapidrun.rapidrun", "certificate_hash": "7C8E070D..." } },
  { "client_id": "<web client id>", "client_type": 3 }
]
```
Sign-in should produce a Firebase user and no longer throw `ApiException: 10`.

## 7. Runtime Preflight (Optional)
Add a silent GoogleSignIn attempt in debug to surface configuration issues early (see `login_screen.dart` preflight banner if enabled).

## 8. Common Pitfalls
| Symptom | Cause | Fix |
|---------|-------|-----|
| ApiException: 10 | Missing Android OAuth client | Add fingerprints & re-download config |
| Still error after adding | Old cached build | Run full clean build |
| Works debug, fails release | Missing release fingerprints | Add release SHA-1 & SHA-256 |
| Multiple identical Android apps in Firebase | Duplicate registration | Remove unused entry |

## 9. API Key Restrictions
If you restrict Web API keys in Google Cloud Console, ensure Android app restrictions list the package + all SHA-1 fingerprints. Otherwise leave unrestricted during development.

## 10. Maintenance Checklist
- [ ] New keystore? Add new SHA-1 & SHA-256 and re-download config.
- [ ] Rotated keys? Remove old fingerprints if unused.
- [ ] Cloned project on new machine? Run signingReport and verify debug fingerprint matches Firebase (debug keystore differs across machines; either add each dev's SHA or distribute a shared debug keystore).

## 11. Shared Debug Keystore (Optional)
To avoid every dev adding a fingerprint, create a shared debug keystore and commit only a secure distribution method (never the keystore itself) OR accept multiple fingerprints in Firebase.

## 12. iOS Note
iOS uses `GoogleService-Info.plist` and does not require SHA fingerprints.

---
**Quick Failure Triage**
1. See ApiException: 10 → Open `google-services.json` and confirm `client_type: 1` exists.
2. If absent → Add fingerprints in Firebase → Re-download file → Clean & rebuild.
3. If present → Ensure package name matches `applicationId` and no API key over-restriction.

---
Last updated: 2025-09-28.
