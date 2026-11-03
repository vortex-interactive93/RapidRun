# Firestore Rules Test Plan (Orders)

Intended for use with the Firebase Emulator Suite. These are logical test cases; you can implement them via a Node script, Dart integration tests, or the Firebase CLI `rules-unit-testing` library.

## Pre-Setup
1. Start emulators: Firestore Auth.
2. Seed (optional): Create `/users/{uid}` for test users if your app logic depends on existence.
3. Use at least two users: `alice` (owns order), `bob` (other user).

## Helper
- `as(user)` executes with `request.auth.uid = user`.
- All tests expect `DENY` unless explicitly marked `ALLOW`.

## Test Matrix

### 1. Create
- ALLOW: `alice` creates order with required fields, status=`pending`.
- ALLOW: `alice` creates order with status=`processing` (legacy path).
- DENY: `bob` creates order with `customerId=alice`.
- DENY: unauthenticated create.
- DENY: create missing a required field (e.g., omit `subtotal`).
- DENY: create with status=`assigned` (invalid initial).

### 2. Read
- ALLOW: `alice` reads her order.
- DENY: `bob` reads `alice` order.
- DENY: unauthenticated read.

### 3. Immutable Fields
- DENY: `alice` updates changing `subtotal`.
- DENY: `alice` updates changing `items[0].quantity`.
- DENY: `alice` updates changing a nested payment field.

### 4. Allowed Mutable Fields (No Status Change)
- ALLOW: `alice` adds `driverId` (was null) with unchanged immutable fields.
- ALLOW: `alice` increments `substitutionRequestCount` (if field present or adds it) with unchanged immutables.

### 5. Status Transitions
- ALLOW: `pending -> assigned`.
- ALLOW: `assigned -> shopping`.
- ALLOW: `shopping -> awaiting_substitution`.
- ALLOW: `awaiting_substitution -> shopping` (loop back) or `-> ready_for_delivery`.
- ALLOW: `ready_for_delivery -> enroute`.
- ALLOW: `enroute -> delivered`.
- ALLOW: `processing -> completed`.
- DENY: `pending -> delivered` (skip).
- DENY: `enroute -> shopping` (backward).
- DENY: `delivered -> enroute` (terminal backwards).

### 6. Extra Fields Injection
- DENY: Add unexpected field `debugFlag`.
- DENY: Add `adminOverride=true`.

### 7. Idempotent Write
- ALLOW: Re-write with identical data (no field changes).

### 8. Cancel Paths
- ALLOW: Any forward non-terminal state -> `canceled`.
- DENY: `delivered -> canceled` (terminal).
- DENY: `completed -> canceled`.

### 9. Legacy Flow
- ALLOW: `processing -> failed`.
- ALLOW: `processing -> canceled`.
- DENY: `completed -> failed`.

## Suggested Implementation Snippet (Node - Pseudocode)
```js
const {initializeTestEnvironment} = require('@firebase/rules-unit-testing');
// ... setup env, load rules file

it('alice creates pending order', async () => {
  const aliceDb = testEnv.authenticatedContext('alice').firestore();
  const ref = aliceDb.collection('orders').doc('o1');
  await assertSucceeds(ref.set(baseOrder({customerId: 'alice', status: 'pending'})));
});
```

## Coverage Goal
Achieve 100% pass on listed ALLOW/DENY cases before modifying order workflow.

---
Update this plan alongside any rules or status machine changes.
