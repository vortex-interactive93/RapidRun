# Firestore Orders Rules Overview

This document summarizes the hardened security rules applied to the `/orders/{orderId}` collection.

## Goals
- Enforce ownership (only the creating customer can read/update their order).
- Prevent mutation of immutable fields post-creation (identity + financial + line items).
- Allow only forward, valid status transitions (basic state machine).
- Maintain backward compatibility with legacy `processing` / `completed` / `failed` statuses.
- Provide a clear extension point for future privileged roles (driver, admin, system functions).

## Immutable Fields
`customerId`, `createdAt`, `items[]`, `subtotal`, `tax`, `total`, `payment`, `address`

These must remain bit‑for‑bit equal between `resource.data` and `request.resource.data` on update.

## Mutable Fields
`status`, `driverId`, `awaitingSubstitutionApproval`, `substitutionRequestCount`, `assignedAt`, `shoppingStartedAt`, `shoppingCompletedAt`, `deliveryStartedAt`, `deliveredAt`, `canceledAt`

## Status Transition Map
```
pending -> assigned | processing | canceled
processing -> completed | failed | canceled
assigned -> shopping | canceled
shopping -> awaiting_substitution | ready_for_delivery | canceled
awaiting_substitution -> shopping | ready_for_delivery | canceled
ready_for_delivery -> enroute | canceled
enroute -> delivered | canceled
(delivered | completed | failed | canceled) -> (no outbound transitions)
```
Unchanged status (`from == to`) is allowed (idempotent write / retry).
Any transition not in the map is rejected.

## Creation Constraints
- Must be authenticated.
- `customerId` must equal `request.auth.uid`.
- Must include: `customerId,status,createdAt,items,subtotal,tax,total,payment,address`.
- Initial status limited to `pending` or legacy `processing`.

## Update Constraints
All of the following must be true:
1. Auth user matches `resource.data.customerId`.
2. Immutable fields unchanged.
3. Only allowed fields present (no introducing arbitrary keys).
4. Status transition valid or unchanged.

## Deletion
Client delete is disallowed. (Future: soft delete or admin purge tool.)

## Future Extensions (Not Implemented Yet)
- Driver role enforcement: restricting certain forward transitions (e.g., only a driver can move `ready_for_delivery -> enroute`).
- Admin/system elevated writes for cancellations or forced resolution.
- Monotonic timestamp checks (ensure e.g., `deliveredAt` cannot precede `assignedAt`).
- Rate limiting or write count throttling.

## Testing Plan (See `tool/firestore_rules_test_plan.md`)
We maintain a test plan for emulator-based rule assertions covering ownership, immutability, valid/invalid transitions, and unexpected field injection.

## Change Log
- v1 (current): Introduced hardened rules and state machine.

---
Keep this doc updated as roles or transitions evolve.
