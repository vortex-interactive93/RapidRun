# Release Checklist

A structured, repeatable process to reduce risk and ensure quality for each driver app release.

## 1. Pre-Flight
- [ ] Confirm product scope for this release (features, bug fixes, toggles).
- [ ] Verify feature flags default states (`enableStageSheet`, `enableLegacyOfferQueue`) and adjust for target audience.
- [ ] Update `pubspec.yaml` version:
  - Bump semantic version (MAJOR.MINOR.PATCH+build) per changes.
  - Record rationale in CHANGELOG (if maintained) or `DEV_NOTES.md`.
- [ ] Ensure Firebase project references (Android `google-services.json`, iOS `GoogleService-Info.plist`) are correct for target env (prod vs staging).

## 2. Code Quality
- [ ] Run `flutter analyze` (no new warnings/errors).
- [ ] Run tests: `flutter test` (all green). Add/adjust tests for new features.
- [ ] Ensure coverage did not regress materially for critical logic (stage controller, runtime health, offer acceptance).
- [ ] Lint formatting: `dart format --output=none --set-exit-if-changed .` (CI safe guard).

## 3. Runtime Health & Permissions
- [ ] Sanity test offline state (enable airplane mode) — banner shows, actions gated.
- [ ] Test location permission denial & grant flows.
- [ ] Validate behavior when connectivity flaps (toggle Wi-Fi quickly) — no crashes, banner transitions cleanly.

## 4. Feature Flags & Fallbacks
- [ ] Stage Sheet ON path: enqueue/accept/decline/cycle flows work, analytics events emitted.
- [ ] Legacy Queue path (if enabled): offer ingestion, badge toggle, overlay accept/decline, sheet list interactions.
- [ ] Confirm only one path active (no overlapping UI) — if both true, confirm precedence rule (currently Stage Sheet wins).
- [ ] Precedence assertion passes (no unwanted debug assert in logs). If both flags accidentally true, warning log shows once and Stage Sheet UI renders.
- [ ] Test Scenarios Covered: (1) Stage Sheet accept & decline (2) Legacy queue accept & decline (3) Cycling multi-offer in Stage Sheet (4) Runtime unhealthy gating blocks actions.

## 5. Analytics & Logging
- [ ] Verify critical analytics events fire (offer_accept, offer_decline, offer_cycle) in staging (use debug console or Firelog).
- [ ] Confirm no PII logged unintentionally (driver location & identifiers minimized).
- [ ] Crashlytics: force a test crash in a debug build (if instrumentation present) to confirm symbol mapping.

## 6. Performance & Stability
- [ ] Observe rebuild counters in debug for idle screen (< target threshold, document any anomaly).
- [ ] Map performance: pan/zoom responsiveness acceptable; no jank during offer overlay animations.
- [ ] Memory: open DevTools, watch for runaway growth after multiple offer cycles.

## 7. Accessibility & UX
- [ ] Verify Semantics on Availability Orb & Command Palette via TalkBack/VoiceOver.
- [ ] Offer overlay button hit areas >= 44x44 logical pixels.
- [ ] Color contrast meets WCAG AA for text on primary surfaces.

## 8. Security & Privacy
- [ ] Secrets not embedded in repo (API keys restricted / environment-based).
- [ ] Firestore security rules audited (`firestore.rules` load without errors; spot-check queries used by app).
- [ ] Location permission rationale strings accurate in both platforms.

## 9. Platform-Specific
- Android:
  - [ ] Increment versionCode.
  - [ ] Build release APK / App Bundle: `flutter build appbundle --release`.
  - [ ] Test on API 24+ and a modern device (foldable if available).
- iOS:
  - [ ] Increment CFBundleShortVersionString & CFBundleVersion.
  - [ ] Run `flutter build ipa` (or Xcode archive) and install on physical device.
  - [ ] Validate push notification registration (if applicable).

## 10. Remote Config / Backend Dependencies
- [ ] Sync any Remote Config defaults with documented expectations (`remote_config.md`).
- [ ] Confirm required indexes exist in Firestore for new queries.
- [ ] Run data normalization scripts if required (see task: Normalize Walmart Pantry) prior to shipping dependent features.

## 11. Final QA Pass
- [ ] Fresh install on clean device (no previous app data) — complete onboarding/initial permission flows.
- [ ] Upgrade test from previous production build — no data corruption, flags respected.
- [ ] Smoke test: online toggle, receive offer, accept, transition into active order state.

## 12. Release Packaging
- [ ] Tag release in VCS: `git tag vX.Y.Z && git push --tags`.
- [ ] Generate release notes (features, fixes, known issues, migration notes).
- [ ] Attach build artifacts or publish to internal testing track (Play Console / TestFlight).

## 13. Post-Release Monitoring
- [ ] Monitor Crashlytics dashboard for first 24h (crash-free users target > 99%).
- [ ] Monitor analytics funnels (offer accept rate, decline rate) for regressions.
- [ ] Prepare hotfix branch template if critical issue surfaces.

## 14. Deferred / Nice-to-Have (Optional)
- [ ] Automated golden test for offer overlay styling.
- [ ] Integration test for legacy queue path (multi-offer accept/decline cycle).
- [ ] Performance benchmark test harness (frame build time, memory snapshots).

---

Checklist Owner: (assign)
Date Executed: (fill)
Version: (fill)

Sign-off:
- Engineering:
- Product:
- QA:
