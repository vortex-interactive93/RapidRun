/// Generates suggested alias expansions based on telemetry zero-result queries.
///
/// Logic:
///  1. Loads stored search telemetry events from SharedPreferences JSON file
///     (relies on same key as app). For CLI use, supply a path to an exported
///     telemetry JSON file using --file=path if running outside device.
///  2. Finds zero-result search queries (normalized lower-case) and counts.
///  3. Applies simple heuristics to recommend alias link candidates by:
///       * Singular/plural normalization (chip -> chips, batteries -> battery)
///       * Common misspell corrections (configured set)
///       * Token dropping ("toiletpaper" -> "toilet paper")
///  4. Emits a patch-style suggestion showing lines to add to search_aliases.dart
///
/// Usage:
///   dart run tool/suggest_aliases_from_zero_results.dart --file=telemetry.json
///   (If no --file provided, tries to read lib/services/search_telemetry.dart export placeholder path.)
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final fileArg = _argValue(args, '--file');
  final filePath = fileArg ?? 'telemetry_export.json';
  final file = File(filePath);
  if (!file.existsSync()) {
    stderr.writeln('Telemetry JSON not found: $filePath');
    stderr.writeln('Export telemetry first, then re-run with --file=...');
    exit(1);
  }
  dynamic decoded;
  try {
    decoded = json.decode(await file.readAsString());
  } catch (e) {
    stderr.writeln('Invalid JSON: $e');
    exit(1);
  }
  if (decoded is! List) {
    stderr.writeln('Expected a JSON array of events.');
    exit(1);
  }
  final zeroCounts = <String, int>{};
  for (final e in decoded) {
    if (e is Map) {
      if (e['type'] == 'search' && (e['results'] is int) && e['results'] == 0) {
        final q = (e['q'] ?? '').toString().trim().toLowerCase();
        if (q.isEmpty) continue;
        zeroCounts[q] = (zeroCounts[q] ?? 0) + 1;
      }
    }
  }
  if (zeroCounts.isEmpty) {
    print('No zero-result queries found.');
    return;
  }
  final top = zeroCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  // Simple heuristics
  final misspell = {
    'toiletpaper': 'toilet paper',
    'paper towls': 'paper towels',
    'papertowels': 'paper towels',
    'q tips': 'qtips',
    'q-tip': 'qtip',
  };
  final suggestions = <String, Set<String>>{}; // key -> aliases
  for (final e in top.take(100)) {
    final q = e.key;
    final count = e.value;
    // Skip very short or numeric only
    if (q.length < 3 || RegExp(r'^\d+$').hasMatch(q)) continue;
    // Misspell corrections
    if (misspell.containsKey(q)) {
      suggestions.putIfAbsent(misspell[q]!, () => <String>{}).add(q);
      continue;
    }
    // Singular/plural: if ends with 's' try singular
    if (q.endsWith('s') && q.length > 3) {
      final singular = q.substring(0, q.length - 1);
      suggestions.putIfAbsent(singular, () => <String>{}).add(q);
    } else if (!q.endsWith('s')) {
      suggestions.putIfAbsent(q + 's', () => <String>{}).add(q);
    }
    // Token split: if no space but can insert one between known words heuristically
    final tokenSplit = _splitCompound(q);
    if (tokenSplit != null && tokenSplit != q) {
      suggestions.putIfAbsent(tokenSplit, () => <String>{}).add(q);
    }
    // Hyphen variant
    if (q.contains('-')) {
      final noHyphen = q.replaceAll('-', ' ');
      suggestions.putIfAbsent(noHyphen, () => <String>{}).add(q);
    }
    // Score threshold: we might skip very low frequency (<2)
    if (count < 2) {
      // Keep but mark low frequency (future: maybe tag)
    }
  }
  if (suggestions.isEmpty) {
    print('No alias suggestions generated.');
    return;
  }
  print(
    '--- Suggested alias additions (merge manually into kSearchAliases) ---',
  );
  for (final entry in suggestions.entries) {
    final key = entry.key;
    final vals = entry.value.toList()..sort();
    print("  '$key': ${json.encode(vals)},");
  }
  print('-------------------------------------------------------------------');
}

String? _argValue(List<String> args, String key) {
  for (final a in args) {
    if (a.startsWith('$key=')) return a.substring(key.length + 1);
  }
  return null;
}

String? _splitCompound(String input) {
  // Naive splitting: find first split where both sides are alphabetic and length >=3.
  if (input.contains(' ') || input.length < 6) return null;
  final pattern = RegExp(r'^[a-z]+$');
  for (int i = 3; i <= input.length - 3; i++) {
    final left = input.substring(0, i);
    final right = input.substring(i);
    if (pattern.hasMatch(left) && pattern.hasMatch(right)) {
      return '$left $right';
    }
  }
  return null;
}
