# Biometric Lock Flow

This feature gates app interaction behind a biometric authentication overlay when enabled by the user.

## Components
- `DisplayPreferences` stores the user preference `biometricLock`.
- `BiometricLockService` performs capability checks (`isDeviceSupported`, `canCheckBiometrics`), manages lock state, and triggers authentication.
- `_BiometricGate` (in `main.dart`) wraps the app `MaterialApp` and displays an overlay when locked.

## Behavior
1. App Launch:
   - `BiometricLockService.init()` checks device support & enrollment.
   - If preference is on and last successful auth is older than threshold (5 min) → lock overlay shown.
2. App Resume:
   - On `AppLifecycleState.resumed`, service recomputes and triggers auth if locked.
3. Enabling Preference:
   - Immediate capability validation; if invalid, preference auto-disabled.
   - If valid, user is prompted to authenticate immediately (first unlock) before continuing.
4. Lock Timeout:
   - A simple 5-minute timeout since last success; future enhancement could make this user-configurable.
5. Disabling Preference:
   - Overlay disappears and no more auth prompts until re-enabled.

## Edge Cases & Safeguards
- Unsupported or unenrolled devices automatically clear the preference to avoid confusion.
- Errors during auth are logged in debug mode only; UI remains on lock screen for retry.
- User can hit "Disable (This Session)" to turn off the preference if repeated failures occur.

## Extensibility Ideas
- Add fallback PIN / passcode for devices without biometrics.
- Configurable timeout duration (e.g., 1 / 5 / 15 minutes or immediate on resume).
- Integrate analytics events for lock/unlock attempts and failures.
- Add an in-app explanation screen reachable from settings toggle.

## Minimal Test Suggestions
- Enable on a supported device → overlay shows then disappears after successful auth.
- Kill & relaunch within timeout → no prompt.
- Wait past timeout → prompt reappears.
- Disable preference while locked → overlay removed immediately.
- Simulate unsupported device (emulator without biometric) → enabling toggle auto-disables.

---
Keep this document updated if timeout logic, fallback auth, or analytics are introduced.
