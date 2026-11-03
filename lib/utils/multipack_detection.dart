/// Shared multipack detection heuristics used by tooling, tests, and runtime UI.
///
/// The intent is to centralize the regex logic originally embedded in
/// `tool/extract_multipacks.dart` so we can:
///  * Unit test positive / negative examples (guard against regressions)
///  * Reuse for QA sampling & potential future UI badges / filters
///  * Evolve heuristics in one place
///
/// Heuristics (case-insensitive) applied to provided `name` and optional
/// `shortName`:
///  * Leading parenthetical: "(3 pack)" or "(3-pack)"
///  * Standalone count forms: "12 pack", "12-pack", "12 pk", "12pk"
///  * Phrase: "pack of 6"
///  * Descriptors: "twin pack", "triple pack", "quad pack", "value pack"
///  * Leading parenthetical without trailing ')' occasionally present: "(2 pack"
///
/// NOTE: We deliberately do NOT match generic words like "multi", "family size",
/// "party size", or "bulk" unless coupled with the explicit patterns above to
/// avoid excessive false positives.
library multipack_detection;

/// Ordered list of regex patterns used for detection.
final List<RegExp> kMultipackPatterns = [
  // (3 pack) prefix / (3-pack)
  RegExp(r'^\(\s*\d+\s*[- ]?pack\s*\)', caseSensitive: false),
  // standalone N pack / N-pack / N pk / pack of N
  RegExp(r'\b\d+\s*[- ]?pack\b', caseSensitive: false),
  RegExp(r'\b\d+\s*pk\b', caseSensitive: false),
  RegExp(r'\bpack of\s*\d+\b', caseSensitive: false),
  // descriptive packs
  RegExp(r'\b(twin|triple|quad|value) pack\b', caseSensitive: false),
  // (2 pack   (missing trailing ) sometimes observed)
  RegExp(r'^\(\s*\d+\s*pack', caseSensitive: false),
];

/// Returns true if either [name] or [shortName] match any multipack pattern.
bool isMultipackName(String? name, [String? shortName]) {
  for (final text in [name, shortName]) {
    if (text == null) continue;
    final t = text.trim();
    if (t.isEmpty) continue;
    for (final re in kMultipackPatterns) {
      if (re.hasMatch(t)) return true;
    }
  }
  return false;
}

/// Lightweight model-agnostic map based detection to mirror previous script API.
bool isMultipackMap(Map obj) =>
    isMultipackName(obj['name'] as String?, obj['shortName'] as String?);
