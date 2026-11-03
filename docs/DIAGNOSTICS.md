# Diagnostics & Logging

This app includes a lightweight in-memory logging and diagnostics system to aid development, QA triage, and future remote support tooling.

## Components

### LogService (`lib/services/log_service.dart`)
- Ring buffer (FIFO) with configurable capacity (default 500 entries).
- Each log entry captures timestamp, message, optional category, optional error & stack trace.
- Broadcasts changes via a `Stream<List<LogEntry>>` so UIs can reactively render recent logs.
- Supports manual clearing.

### Diagnostics Screen (`/diagnostics` route)
Located in `lib/screens/diagnostics/diagnostics_screen.dart` and reachable via Settings (developer tile shown in debug/profile modes).

Displays:
- Current authenticated user (uid/email/phone flags).
- Remote config / feature flag values.
- Orders summary (local count + pending operation queue length when cloud orders enabled).
- Recent log lines (newest first, truncated for readability).

## Logging Guidelines
| Scenario | Category | Example |
|----------|----------|---------|
| Firebase auth state changes | `auth` | `auth state -> SIGN_OUT` |
| Order placement / mutation | `orders` | `placeOrder 1689123123 items=3 total=42.17` |
| Cloud sync successes/failures | `orders` | `cloud write fail 1689123 ...` |
| Startup / initialization checkpoints | `init` | `favorites bootstrap complete` (future) |
| Secure setup flow steps | `onboarding` | `phone verification started` (future) |

Keep messages concise; avoid logging large payloads (consider summarizing counts or IDs).

## Adding New Logs
1. Import `log_service.dart`.
2. Call:
```dart
LogService.instance.log('cart merge started', category: 'cart');
```
3. For errors:
```dart
try { /* ... */ } catch (e, st) {
  LogService.instance.log('payment intent create failed', category: 'payments', error: e, stack: st);
}
```

## Extending Diagnostics
Potential future enhancements (low risk):
- Filter chips to show only selected categories.
- Export logs as a JSON blob (share sheet/email).
- Add network latency pings to Firestore & Storage (category `net`).
- Display app version + build number (env / package_info).
- Show device info (platform, locale, text scale) for QA.
- Add button to simulate test log storm for perf profiling.

Higher complexity (plan separately):
- Remote log upload (opt-in) with user consent.
- Structured performance events (timeline markers) joined with logs.
- Rule evaluation mini-harness to validate Firestore security rules offline.

## Testing LogService
A basic unit test should validate:
- Buffer trimming when exceeding capacity.
- Stream emits on each `log()` call.
- Clearing emits an empty list.

See `test/log_service_test.dart` (added in this change) for a reference implementation.

## Operational Notes
- Because the buffer is in-memory only, logs are cleared on app restart. Persist only if a reproducibility requirement arises.
- Avoid personally identifiable information (PII) or secrets in log messages.
- If categories proliferate, introduce an enum wrapper or central registry to prevent typos.

## Quick Reference
```dart
// Basic
LogService.instance.log('user tapped checkout', category: 'ui');

// With error
try { /* ... */ } catch (e, st) {
  LogService.instance.log('sync failed', category: 'sync', error: e, stack: st);
}

// Listen (e.g., for custom overlay)
final sub = LogService.instance.stream.listen((entries) {
  // React to new entries
});

// Dispose
await sub.cancel();
```

---
Maintainers: Expand this doc with any new diagnostics surfaces you add so discovery remains easy for collaborators.
