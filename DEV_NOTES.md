# Aldi Data Model Notes

## Current Stable Approach (Reverted Model)
- Single mapping file: `assets/stores/aldi/aldi_categories.json` defines hierarchy.
- Flat product JSON files live directly in `assets/stores/aldi/` prefixed with `aldi_`.
- Model loader (`lib/data/aldi_category_model.dart`) only reads the categories file; it does NOT auto-discover.

## JSON Structure
Each entry in `aldi_categories.json` is a category object:
```jsonc
{
  "categoryName": "Snacks",
  "iconCodePoint": null, // optional int (Material icon codepoint)
  "sections": [
    {
      "sectionName": "Snack Types",
      "productTypes": [
        { "name": "Trail Mix", "filePath": "assets/stores/aldi/aldi_trail_mix.json" }
      ]
    }
  ]
}
```

Product type -> `filePath` points to a flat JSON list of product objects (id, name, imageUrl, description, price, etc.).

## Add a New Product Type (Checklist)
1. Create product JSON file in `assets/stores/aldi/` named `aldi_<snake_case_name>.json`.
2. File content: an array `[]` of product objects. Minimal fields:
   - `id` (unique string) (e.g. `"aldi_new_cat_001"`)
   - `name`
   - `imageUrl` (can be placeholder or null)
   - `description` (optional)
   - `price` (number) and `unit` (optional)
   - `storeId`: `"aldi"`
   - `category`: top-level category display name (e.g. `"Snacks"`)
   - `subCategory`: section name (e.g. `"Snack Types"`)
3. Edit `assets/stores/aldi/aldi_categories.json`: add a productTypes entry under the correct section:
```jsonc
{ "name": "New Thing", "filePath": "assets/stores/aldi/aldi_new_thing.json" }
```
4. (No pubspec change needed: `assets/stores/aldi/` is already listed.)
5. Rebuild: `flutter run` (or hot restart if running and only data files changed). If a red screen shows an asset error, verify the `filePath` spelling and inclusion in the categories file.

## Add or Expand a Section
- Add another section object inside an existing category's `sections` array.
- Keep sectionName consistent with the `subCategory` you store inside each product object for easier filtering.

## Add a New Category
1. Append a new category object to the root array in `aldi_categories.json`.
2. Provide at least one section with at least one productType so UI has something to render.

## Common Pitfalls & Prevention
| Issue | Cause | Fix |
|-------|-------|-----|
| FormatException parsing product file | Trailing commas or not a JSON array | Ensure file starts with `[` and ends with `]` exactly. |
| Red screen: Unable to load asset | Typo in `filePath` or file not added | Match exact file name; ensure committed. |
| Empty UI category | Added category but no sections/productTypes | Add at least one product type. |
| Stale data after edit | Hot reload doesn't reload asset strings | Perform hot restart or full rebuild. |

## Naming Conventions
- File prefix: `aldi_` then snake case of product type: e.g. `aldi_fresh_fruit.json`.
- IDs: `aldi_<logical_group>_<3 digit seq>`.

## Future Enhancements (Optional)
- Create a small script to validate that every `filePath` exists and every product references a valid category/section.
- Introduce an optional `iconCodePoint` on productTypes for richer UI icons.
- Later (if desired) add a second loader that auto-discovers files but keep this stable path as fallback.

## Recovery Reference
- This commit (`feat(aldi): revert to categories.json model and add diapers/wipes/wash + snacks product files`) is the stable baseline after removing the failed dynamic discovery approach.
- Tag suggestion: `aldi_revert_stable`.

## Tag This Baseline
```
git tag -a aldi_revert_stable -m "Stable Aldi categories.json baseline"
git push --tags   # if remote configured
```

## Quick Verification Script (Dart Snippet)
```dart
// Run in a scratch file to sanity check assets at dev time.
import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory('assets/stores/aldi');
  final categoriesFile = File('${root.path}/aldi_categories.json');
  final categories = json.decode(categoriesFile.readAsStringSync()) as List;
  for (final cat in categories) {
    for (final section in (cat['sections'] as List)) {
      for (final pt in (section['productTypes'] as List)) {
        final p = File(pt['filePath']);
        if (!p.existsSync()) {
          print('MISSING: ${pt['filePath']}');
        }
      }
    }
  }
  print('Check complete.');
}
```

---
These notes help future AI (and humans) apply changes safely.

---

## Driver App Dev Utilities (Seeding & Orders)

### Seeding Pending Orders (Driver Flow Testing)
File: `rapidrun_driver/lib/dev_seed.dart`

Exports:
- `Future<String> seedTestOrder()` – Inserts a single `pending` order with example line items and computed `subtotal`, `tax`, `total`.
- `Future<List<String>> seedMultiple(int count)` – Convenience batch seeding.

Invocation (current temporary UI): App bar action (Seed icon) in the driver app stub root calls `seedTestOrder()` and shows a SnackBar with the new order ID.

Firestore shape (required base fields):
```
orders/{id} {
  status: 'pending',
  createdAt: <server timestamp or ISO string>,
  items: [ { name, quantity, unitPrice, ... } ],
  subtotal, tax, total,
  payment: { methodId, brand, last4 },
  address: { fullName, city, line1, ... },
  driverId: null (until claimed)
}
```

### Dev Removal / Hardening Checklist (Before Beta)
| Item | Action |
|------|--------|
| Seeding button | Remove from UI or wrap with a `kDebugMode` check. |
| dev_seed.dart | Keep for local manual runs or move under `tool/` directory. |
| Firestore Rules | Introduce driver claim validation (only unassigned + status `pending`). |
| Index | Ensure composite index (status ASC, driverId ASC, createdAt ASC) exists in prod project. |
| Logging | Add analytics events for claim + every status transition. |

### Status Transition Flow (Driver)
Implemented in `ActiveOrderScreen` with transactional guards:
`assigned -> shopping -> ready_for_delivery -> enroute -> delivered`
Each relevant transition adds a server timestamp field:
| Status | Timestamp Field |
|--------|-----------------|
| shopping | shoppingStartedAt |
| ready_for_delivery | shoppingCompletedAt |
| enroute | deliveryStartedAt |
| delivered | deliveredAt |
| canceled | canceledAt |

Client enforces allowed transitions; Firestore rules still need complementary constraints (see TODO scaffold below).

### Pull-to-Refresh on Available Orders
`AvailableOrdersScreen` now uses a `RefreshIndicator` that forces a new StreamBuilder key to re-subscribe. Also surfaces missing-index guidance with a quick-create URL.

### TODO (Rules Enhancements)
Add to `firestore.rules` under orders match block:
```
// TODO(driver): allow drivers (with a drivers/{uid} doc) to:
//  - claim: pending -> assigned (only if driverId null) setting driverId + assignedAt.
//  - perform forward transitions listed above ONLY when resource.data.driverId == uid().
//  - prohibit modifying financial fields, items, payment, address from driver clients.
//  - reject transitions that skip intermediate states or revert backwards.
//  - ensure timestamp fields added correspond correctly to new status.
```

### Suggested Next Improvements
1. Add Firestore rule helpers: `isDriver(uid)` (check existence of drivers/{uid}).
2. Split customer vs driver order operations (maybe separate callable Cloud Functions for claim & transitions for stronger validation / auditing).
3. Implement background location ping service for active delivery states (`enroute`).
4. Add optimistic UI updates for line-item picking (checkbox states persisted under nested `driverProgress.itemsPicked[]`).
5. Write integration test that seeds an order, claims it, walks through all states (using emulator suite if adopted later).

---

## Driver App Phase 2 UI Enhancements (Summary)

This section documents the second-phase iteration focused on a uniquely differentiated driver experience (beyond legacy gig metaphors):

### New Visual / Interaction Layers
| Feature | File(s) | Notes |
|---------|---------|-------|
| Availability Orb (spectral arc) | `presentation/home/availability_orb.dart` | Shows time remaining + animated arc; long press opens radial menu; double tap spawns mock offer (temporary). |
| Radial Availability Menu | `presentation/home/radial_availability_menu.dart` | Fan-out pods for extend, remove cap, offline/online; safe-area aware angle adjustments. |
| Command Rail (expanded) | `presentation/home/command_rail.dart` | Adds Metrics, Info, Bloom, Center, and Menu toggles with animated expand & active Bloom gradient glow. |
| Insight Carousel | `presentation/home/insight_panel.dart` | PageView: Demand Forecast, Earnings Pace, Availability. Swipable bottom center. |
| Metrics Strip & Overlays | `presentation/home/metrics_strip.dart`, `presentation/home/metrics_overlay.dart` | Frosted panels for richer analytics; lightweight sparkline painter. |
| Demand Forecast Bars | `presentation/home/forecast_bars.dart` | Animated hourly future demand bars (mock). |
| Incoming Offer Overlay | `presentation/home/incoming_offer_overlay.dart` | Prototype card w/ countdown ring, pay & distance pills. Accept/Decline currently dismiss only. |
| Demand Bloom Overlay | `presentation/home/demand_bloom_overlay.dart` | Additive blend radial gradient clusters visualizing opportunity heat (mock clusters anchored to camera target). Toggle via Bloom in command rail. |

### Theme & Tokens
Extended `theme/design_tokens.dart` with:
- Bloom heat spectrum (bloomCool, bloomWarm, bloomHot, bloomCore).
- Radial menu gradient + demand bloom cluster gradient scaffold.
- Performance/earnings semantic colors (pacePositive/Negative/Neutral).

### Layering Order (Stack Strategy)
Map → Bloom (toggle) → Availability Orb / Command Rail / Insight Carousel → Radial Menu (modal) → Metrics / Info overlays → Incoming Offer overlay.

### Offer Prototype Behavior
- Offer spawns manually via double-tap orb (dev only) creating `IncomingOfferData` with 28s countdown.
- Accept/Decline/Expire all currently clear local state. Backend claim logic pending (future task).

### Demand Bloom Implementation Notes
- Painter uses additive BlendMode.plus for luminous accumulation.
- Mock clusters reposition when camera target changes (approx anchor recentering).
- Current coordinate mapping is naive lat/lng normalization; replace with map projection or tile overlay for production accuracy.

### Known TODOs / Follow-Ups
| Area | Next Step |
|------|-----------|
| Bloom accuracy | Use Mercator projection & map camera bounds to position clusters correctly. |
| Offer actions | Persist accept/decline in Firestore; integrate scoring & conflict checks. |
| Analytics | Log toggles (Bloom on/off), menu interactions, radial selections. |
| Accessibility | Add semantic labels for radial pods & bloom toggle. |
| Perf | Consider caching bloom layer to offscreen image when camera static. |

### Dev Shortcuts (Temporary)
- Double tap orb → spawn mock offer.
- Bloom toggle in command rail (local only).

### Removal / Hardening Before Beta
- Gate dev spawn actions with `kDebugMode`.
- Replace mock cluster generator with live demand ingestion pipeline.
- Add A/B option flags for Bloom vs traditional pin heatmap for controlled rollout.

---

