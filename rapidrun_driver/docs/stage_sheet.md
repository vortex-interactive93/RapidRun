# Stage Sheet Architecture

The Stage Sheet unifies driver session UI states (incoming offers, multi-offer queue, active order placeholder, post-delivery celebration) into a single overlay and removes competing ad‑hoc overlays.

## Stages
| Stage | Meaning | Visible Elements |
|-------|---------|------------------|
| `idle` | No pending offers / no active order | Nothing rendered |
| `singleOffer` | Exactly one offer in queue | Cinematic hero card + dim/blur backdrop (first time only) |
| `multiOffer` | 2+ offers | Hero card + up to 2 stacked peek cards + position pill (e.g. 1/3) |
| `activeOrder` | Driver accepted an offer (Phase 1 placeholder) | Compact placeholder card with View Details CTA |
| `postDelivery` | Transient celebration after marking delivered | Toast animation (auto-dismiss) |

## Controller (`DriverStageController`)
`ChangeNotifier` that owns:
- Offer queue (list of `IncomingOfferData`)
- `stage` enum
- `activeIndex` for multi-offer rotation
- `firstCinematicPlayed` flag (prevents re‑playing entrance)
- Post-delivery timer lifecycle

Key methods: `enqueueOffer(s)`, `acceptActive()`, `declineActive()`, `cycleForward()`, `expireActive()`, `showPostDeliveryToast()`, `markCinematicPlayed()`.

### Cinematic Rule
Cinematic runs only once: when the very first single offer arrives. The flag is set after the animation completes (listener in the sheet), not during enqueue.

## Sheet (`DriverStageSheet`)
Single Positioned overlay; ignores pointer events during `postDelivery` only (so it can fade without interference). Multi-offer hero card exposes:
- Position pill with swap icon
- Tap OR horizontal swipe cycles offers via controller

## Feature Flag
`FeatureFlags.enableStageSheet` toggles the entire system. When `false`, legacy overlay + badge + bottom sheet remain active. All new code is additive and can be disabled instantly.

## Integration Points
- Offer ingestion: `_subscribeTestOrders()` (and future real offer stream) calls `enqueueOffer` when flag enabled.
- Accept / Decline: sheet callbacks invoke `OfferAcceptanceService`, then call controller transitions.
- Post-delivery trigger: `ActiveOrderScreen` calls `showPostDeliveryToast()` (global registry interim pattern) after a successful transition to `delivered`.

## Temporary Global Registry
A lightweight `DriverStageControllerRegistry` holds a reference to the controller so non-descendant screens (e.g., full-screen active order flow) can trigger toast without introducing a full DI layer yet. This should be replaced with Provider / Riverpod / scoped dependency as part of a future refactor.

## Planned Enhancements (Future Phases)
1. Active Order Rich Panel: Replace placeholder with real order timeline + substitution tasks.
2. Micro‑interactions: Sub-card hover scaling, subtle physics on multi-offer cycling.
3. Persistence: Survive hot restart / app resume (serialize queue + stage into local storage or Firestore driver doc).
4. Analytics: Events for cinematic play, multi-offer cycle, offer peek interactions.
5. Accessibility: Semantic labels, larger tap targets, high contrast audit.

## Rollback Strategy
Toggle `enableStageSheet` to `false`:
- Stage controller & sheet remain instantiated but hidden / inert.
- Legacy offer overlay + badge + bottom sheet path still functions.
- No schema or persistent migrations required for rollback.

## Implementation Notes
- Controller avoids reflection and global state except for the temporary registry hook. Replace with dependency injection soon.
- No timers except post-delivery toast (auto-dismiss) and countdown ring per offer card (AnimationController duration).
- All UI transitions are self-contained (no external animation dependencies), simplifying testability.

## Minimal Test Ideas
| Test | Expectation |
|------|-------------|
| Enqueue first offer | Stage = singleOffer, cinematic not yet flagged until animation ends |
| Accept active offer | Stage transitions to activeOrder, queue cleared |
| Enqueue 3 offers | Stage = multiOffer, activeIndex cycles on onCycle callback |
| Post-delivery trigger | Stage = postDelivery then returns to idle after timeout |

---
_Last updated: ${DateTime.now().toIso8601String()}_
