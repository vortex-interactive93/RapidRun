# RapidRun Architecture Overview

This document captures the current (2025-08-15) high‑level architecture after the recent refactor & cleanup.

## Goals
- Allow anonymous browsing; gate checkout behind authentication.
- Keep services small, testable, asset‑driven where possible.
- Favor data locality (in‑memory catalogs, local caches) and defer complex infra.
- Maintain analyzer/test cleanliness to support rapid iteration & future AI assistance.

## Layering

```
+-----------------------------+
|            UI              |  Screens, widgets, theming
+--------------+--------------+
|    View / Presentation     |  Simple state derived from services (no heavy state mgmt lib used yet)
+--------------+--------------+
|         Services           |  Auth, Favorites, Cart, Orders (stub), Addresses, Payments (stub), Analytics,
|                             |  Recommendation (prototype), RelatedProducts, ProductCatalog
+--------------+--------------+
|        Data Sources        |  Firebase Auth/Firestore, Asset JSON, SharedPreferences (local sync/share)
+--------------+--------------+
|        Platform / SDK      |  Flutter, Firebase SDKs, Plugins (geolocator, stripe, etc.)
```

## Core Services

### AuthService
Wraps FirebaseAuth. Provides sign‑in/out, Google sign‑in (in progress), account deletion & profile completion path. Emits auth state to dependent services.

### FavoritesService & CartService
- Singleton instances `FavoritesService.instance`, `CartService.instance`.
- Local Map caches kept in memory & hydrated from SharedPreferences.
- On auth state changes: merge anonymous local state with user scoped Firestore doc (if present) and set up listeners; debounce writes for batch persistence.
- Cart: quantity per productId; Favorites: set of productIds.

### ProductCatalogService
- Scans `AssetManifest.json` for `assets/stores/**.json` excluding category listing files.
- Loads each List JSON, building an in‑memory `Map<String, Product>` keyed by `id` (first writer wins to avoid cross‑store duplicates overriding).
- Idempotent `ensureLoaded()` with simple re‑entrancy guard.

### Recommendation Prototype
- `collaborative_filtering.dart` + `recommendation_engine.dart` (lightweight heuristic):
  - Currently uses simple co‑occurrence & recent views heuristics; ratings nullable & safely handled.
  - Provides lists for Home screen ("Because you liked", trending, top rated) without persisting user vectors yet.

### RelatedProductsService
- Given a product: surfaces others sharing category/subCategory or store with light scoring.

### Orders / Payment / AddressBook / PaymentMethods
- Present as stubs or simplified implementations for future expansion (structure in place; heavy integration deferred).

### AnalyticsService
- Central fire‑and‑forget entry points (screen views, product taps, cart events) abstracting Firebase / future pipeline.

## Data Model

### Product
Unified model with minimal required fields:
```
{id, name, price, category, subCategory, storeId, imageUrl, unit?, description?, benefits?}
```
Descriptive fields intentionally nullable (mass nullification sweep) to allow regeneration with higher‑quality copy later. Additional dynamic/custom attributes housed in a loose `customizations`/map if needed (legacy code references trimmed).

## Routing
Enum `AppRoute` drives `onGenerateRoute` mapping to screens. Unknown routes fallback shows a simple diagnostic scaffold.

## UI Patterns
- `HomePage` composes recommendation sections, recent views, quick store/category surfacing, mini‑cart bar.
- `MiniCartBar` animates in when cart has items; collapsible to a FAB.
- `ProductChip`, `ShimmerBox`, service grid & welcome card form reusable micro‑components.
- Settings & Profile screens manage theme preference (persisted), account changes, data export stubs.

## State Management
Currently lean – singletons & `ChangeNotifier`-like patterns (if any) inside services. Candidate future directions:
- Introduce Riverpod for derived/composable state (already partially present in some legacy tests but core app not hard‑bound yet), or
- Lightweight ValueNotifiers & explicit refresh triggers.

## Persistence & Sync Flow (Favorites/Cart)
```
Startup -> Firebase init -> Favorites/Cart bootstrap
  -> Load local SharedPreferences cache
  -> Listen to auth state
      -> If user signs in:
           - Fetch remote doc
           - Merge (union favorites, sum quantities) with local
           - Write merged snapshot back
           - Start listener for remote changes -> update local
      -> If user signs out:
           - Continue using local (last known) state only
```
Conflict merge rule: local changes since last sync always preserved (first writer wins strategy kept simple; future enhancement could add per-item timestamps).

## Error Handling & Resilience
- Catalog load: per‑file try/catch with log prefix `[Catalog]`. Continues processing on failures; we fixed malformed JSON (missing closing bracket) to restore clean load.
- Auth & network: Minimal; UI shows bootstrap error screen if Firebase init fails.
- Recommendation & related products: Fully in‑memory; null-safety guards prevent crashes when optional data absent.

## Testing Strategy (Current Minimal Set)
- `password_strength_test.dart`: validates utility scoring.
- `nutrition_info_test.dart`: schema parsing normalization.
- `catalog_load_test.dart`: verifies product catalog loads & is non‑empty.
- Widget smoke tests consolidated/stubbed to reduce noise; legacy expansive tests retired pending redesigned flows.
- Goal: incrementally add focused unit tests (e.g., cart merge logic, favorites sync, recommendation ranking determinism).

## Recent Cleanups
- Removed/neutralized obsolete integration & service tests referencing deleted services.
- Replaced deprecated `withOpacity` usages with `withValues(alpha: ..)` for forward SDK compatibility.
- Unified product schema; mass‑null descriptions & benefits.
- Fixed malformed JSON asset causing load exception.
- Analyzer: now 0 issues.

### Product Asset Validation & Normalization (Added 2025-08-25)
Taco Bell asset pipeline now enforces structure and deduplicates modifier groups via scripts:

Tools:
* `validate_taco_bell_schema.dart` – strict schema/type and cross-file id uniqueness validation (fails on any error).
* `validate_taco_bell_modifiers.dart` – detects redundant inline modifier groups identical to canonical templates.
* `fix_taco_bell_calories.dart` – parses descriptions to backfill `calories`, `minCalories`, `maxCalories` (supports single values & ranges).
* `refactor_taco_bell_modifiers.dart` – replaces inline groups that are subsets of canonical templates with `modifierRefs`.
* `extract_taco_bell_included_groups.dart` – mines occurrences of the 'included' group to derive canonical union & statistics.

Canonical Modifier Templates:
`assets/stores/taco_bell/_modifier_sets.json` now contains shared group definitions (`add_ons`, `popular_upgrades`, `make_it_your_own`, `sauces`, `included`). Products reference these via `modifierRefs` reducing duplication and future drift.

Refactor Outcomes:
* First pass: 106 inline groups converted to references.
* Second pass (after adding curated `included` template): +31 more groups refed.
* Remaining inline groups are intentional variants (custom choose_* or partial subsets with unique options).

Validation Status:
As of 2025-08-25 schema errors = 0, redundant inline groups = 0. Calorie ranges normalized; missing calories eliminated.

Next Data Enhancements Planned:
1. Split broad `included` template into scoped variants (e.g. base_proteins, base_toppings) to avoid over-inclusive defaults.
2. Introduce combo modeling (`components`, `choiceGroups`) with validator extensions.
3. Strengthen refactor logic to extract unique delta options while referencing base templates.
4. Integrate a unified `validate_all` runner into CI (pre-commit + pipeline) combining schema, modifier, and dedupe checks.

## Pending / Backlog Opportunities
1. Cart & Favorites Merge Tests – simulate local+remote merge edge cases.
2. JSON Schema Validation Script – fail CI on malformed product assets.
  - (Implemented for Taco Bell; extend generically across stores.)
3. Service Initialization Registry – deterministic startup ordering & health check summary.
4. Structured Logging – wrapper with log levels & category filters (swapable sink).
5. Recommendation Engine Evolution – persist interaction events & apply weighted scoring.
6. Search Service Reintroduction – implement product indexing & filtering (previous placeholder removed).
7. Data Export & Deletion Flows – privacy feature completion.
8. JSON (de)serialization generation via `json_serializable` for Product & Nutrition models.
9. UI Performance – virtualized long lists (Slivers), image precache strategy, skeleton placeholders.
10. Accessibility Pass – semantic labels, larger text scaling tests.

## Architectural Principles
- Keep IO & parsing isolated (services) – UI receives domain objects only.
- Fail soft: ignore / log asset errors, never crash core navigation.
- Prefer additive migration: stub legacy features rather than leave broken references.
- Keep top-level `main.dart` lean: initialization + root `MaterialApp` only.

## Extension Points
- Add a `Service` base class with `init()`, `dispose()`, optional `priority` to orchestrate startup.
- Introduce caching layer abstraction if moving beyond SharedPreferences for offline persistence.
- Hook recommendation events into Analytics to build an interaction matrix.

---
_Last updated: 2025-08-15_

## Large Data Asset Partitioning (Added 2025-08-15, Updated 2025-08-15 Later)
Large monolithic product JSON files (> ~150 items or ~150KB) are auto-partitioned to reduce merge conflicts and speed reviews.

Naming Convention:
* Base (legacy single file) e.g. `walmart-deli-prepared-meals-sides.json`
* Parts: `walmart-deli-prepared-meals-sides-part1.json`, `-part2.json`, ...
* Backup of original kept as `.json.bak` for diff (prunable after confidence).

Current State:
* `walmart-deli-prepared-meals-sides` now split into 2 parts (150 + 118 items) per 150-item threshold.
* Other oversize Walmart meat & produce files, pork, sausages, vegetables, etc. already partitioned similarly earlier.
* Original monoliths retained as `*.json.bak` pending final review; loader ignores backups.

Rules:
1. Item `id` values stay unchanged (no renumbering) to keep references stable.
2. Partition boundary is simple fixed-size chunk (threshold from config); contiguous numeric ranges not strictly enforced but overlap test ensures uniqueness.
3. Tests auto-discover parts; validation test checks for overlapping numeric suffixes & reports gaps.
4. After QA, `.bak` files can be deleted in a cleanup commit (non-functional).

Tooling:
* `dart tool/partition_products.dart [--dry-run|--force]` reads thresholds from `assets/config/product_asset_rules.json`.
* `dart tool/dedupe_report.dart` prints duplicate (store/category/subCategory/name/unit) groups.
* `dart tool/generate_id.dart <prefix>` suggests next id for a given prefix.

Pre-commit hook runs a dry-run partition + schema test; optionally can be extended to emit dedupe warnings (implemented now).
