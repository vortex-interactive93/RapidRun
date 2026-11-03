# RapidRun Driver App (Bootstrap)

This directory contains the early scaffold for the dedicated **RapidRun Driver** application.

## Goals (MVP)
- Authenticate driver (email / Google) & verify driver role (Firestore doc or custom claim)
- See list of available (unclaimed) orders
- Claim an order atomically
- Manage lifecycle: assigned → shopping → ready_for_delivery → enroute → delivered
- Mark individual line items (found / substituted / missing) – future enhancement
- Upload proof-of-delivery (photo) – future enhancement
- Stream driver location while enroute (with user permission)

## Current State
- Shared models consumed via `packages/rapidrun_shared`
- Mock `OrderOfferService` simulates incoming order offers & claim removal
- Stub `DriverLocationService` emits a moving coordinate periodically
- Placeholder screens: `AvailableOrdersScreen`, `ActiveOrderScreen`
- `main.dart` shows a temporary bootstrap + shared order rendering

## Next Engineering Steps
1. Integrate Firebase (run `flutterfire configure` selecting new Android/iOS app IDs for `com.rapidrun.driver`).
2. Add platform-specific Google Services files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. Initialize Firebase in `main()` before running the app.
4. Add auth flow (simple email + password first). After sign-in verify `drivers/{uid}` exists. If not: sign out & show error.
5. Replace mock offer stream with Firestore query for unassigned orders (`where('driverId', isNull: true)`). Limit fields if needed.
6. Implement claim logic with Firestore transaction:
   ```dart
   await db.runTransaction((tx) async {
     final ref = orders.doc(orderId);
     final snap = await tx.get(ref);
     if (snap['driverId'] != null) throw 'Already claimed';
     tx.update(ref, {
       'driverId': uid,
       'status': 'assigned',
       'assignedAt': FieldValue.serverTimestamp(),
     });
   });
   ```
7. Build ActiveOrder detail screen with status advance buttons (guard transitions).
8. Introduce a small state holder (e.g. Riverpod or ChangeNotifier) for active order + updates.
9. Add driver heartbeat / location writes: write to `driverLocations/{uid}` every X seconds when enroute.
10. Add Storage rule + upload for proof-of-delivery photo (`pod/{orderId}/{uid}.jpg`).
11. Add push notifications (Cloud Function: on new order create send to active drivers).
12. Add substitution workflow UI (awaiting_substitution state).

## Firestore Structure (Additions)
```
drivers/{driverId}
  active: bool
  name: string
  createdAt: timestamp

orders/{orderId}
  driverId: string|null
  status: string
  assignedAt, shoppingStartedAt, shoppingCompletedAt,
  deliveryStartedAt, deliveredAt: timestamps
  awaitingSubstitutionApproval: bool
  substitutionRequestCount: int

driverLocations/{driverId}
  lat: number
  lng: number
  updatedAt: timestamp
```

## Security Rule Considerations (Sketch)
```
function isDriver() {
  return isSignedIn() && exists(/databases/$(database)/documents/drivers/$(uid()));
}
match /orders/{id} {
  allow list: if isDriver();
  allow get: if isDriver() || (isSignedIn() && resource.data.customerId == uid());
  allow update: if isDriver() && resource.data.driverId == uid();
}
match /driverLocations/{driverId} {
  allow write: if isDriver() && driverId == uid();
  allow get: if isDriver() && driverId == uid();
}
```
(Refine & lock down fields later.)

## Shared Package Usage
The driver app depends on `rapidrun_shared` via a path dependency for unified models. Any schema change must update both the shared package and relevant serialization code.

## Development Commands (Windows PowerShell)
```powershell
cd rapidrun_driver
flutter pub get
flutter run
```

## Roadmap (Post-MVP)
- Route optimization / batching
- Earnings dashboard + tips breakdown
- Customer messaging (chat / canned responses)
- Incident reporting (damaged, store closed, etc.)
- Metrics & quality scoring (late deliveries, substitutions efficiency)

---
This README will evolve as real backend integration replaces mocks.
