# Data Assets & Validation

This document summarizes the structure, validation, and maintenance tooling for product JSON assets under `assets/stores/`.

## Goals
* Unique, stable product IDs per logical category file (or partitioned group of files)
* Lightweight schema validation (shape, numeric types, optional fields)
* Guardrails to detect accidental reintroduction of legacy/duplicate datasets
* Developer tooling to normalize IDs and detect issues early (CI friendly)

## File Organization
Each store (e.g. `aldi`, `walmart`, `target`) has many category JSON files. Some large categories are partitioned using a `-partN` suffix (e.g. `aldi_cookies_sweets-part1.json`). All partitions together represent one logical category whose IDs should share a common prefix.

## Product ID Convention
`<base_file_name>_<NNN>`

* `base_file_name` = category file name *without* partition suffix and without `.json` extension.
* `NNN` = 3+ digit, zero‑padded sequential integer starting at 001. (4 digits automatically used for groups with 1000+ items.)
* Partitioned files continue numbering across parts.

Examples:
* `aldi_cookies_sweets-part1.json` starts at `aldi_cookies_sweets_001`
* `aldi_cookies_sweets-part2.json` continues sequence past the last ID of part1

## Legacy / Deprecated Datasets
Several historical Walmart deli JSON files were superseded by consolidated `walmart-deli-*` sets. Deprecated placeholders are skipped in validation (see `legacyFileSkips` in `test/asset_schema_validation_test.dart`). Keep deprecated assets either removed or with an empty JSON array (`[]`).

## Validation Test
`test/asset_schema_validation_test.dart` performs:
1. Discovers all product JSON files (skipping legacy + support files)
2. Parses and lightly validates record fields
3. Enforces global product ID uniqueness
4. Reports (non-fatal) potential duplicate items by (lowercased name + unit) for Walmart Deli + Aldi Deli categories
5. Reports (non-fatal) gaps inside partitioned numeric sequences and overlapping numeric suffixes (the latter would fail the test)

## Normalization Tool
Script: `tool/fix_duplicate_product_ids.dart`

Dry run:
```
dart run tool/fix_duplicate_product_ids.dart
```
Apply changes:
```
dart run tool/fix_duplicate_product_ids.dart --apply
```
The script:
* Scans `assets/stores/aldi`
* Groups partitioned files
* Detects when current ID prefixes differ from the normalized base
* Rewrites IDs sequentially with preserved relative order
* Prints summary + sample mapping (caps at first 5 changes per group)

### Extending to Other Stores
To add Walmart or Target:
1. Generalize the script: parameterize root directory and optionally a whitelist regex for file names.
2. Add a CI task (see below) to run dry-run for all stores and fail on proposed rewrites.

## CI Guard (Planned)
A future test can run the normalization script in dry-run and ASSERT `IDs rewritten == 0`. This prevents committing mis-prefixed IDs.

Example (pseudo):
```dart
// In a new test file, e.g. test/data_id_normalization_guard_test.dart
final result = await Process.run('dart', ['run', 'tool/fix_duplicate_product_ids.dart']);
expect(result.stdout.contains('IDs rewritten:     0'), true, reason: 'Run ID normalization tool --apply to fix IDs');
```

## Name + Unit Duplicate Review
Current notices highlight items sharing `name` + `unit` pairs that may represent real duplicates (e.g. same product across sub-categories) or intentional overlaps. Curate by:
* Removing true duplicates
* Merging categories or differentiating names (e.g. add flavor/size)
* Suppressing known-intentional duplicates via an allowlist JSON (future enhancement)

## Sequence Gaps
Gap notices are informational and often benign (removed / pruned items). If gaps grow noisy, maintain an allowlist file with base -> excluded numeric IDs.

## Recommendations / Next Steps
1. Generalize ID normalization script for all stores
2. Add normalization guard test
3. Introduce `assets/config/duplicate_name_unit_allowlist.json`
4. Optionally convert severe gap patterns (over 200 missing in < 1000 range) into test warnings logged once.

---
Last updated: 2025-08-15
