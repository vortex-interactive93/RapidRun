/// Alias remediation pipeline driver.
///
/// Steps:
/// 1. Read telemetry export JSON (from app or stored file) passed via --file
/// 2. Generate alias suggestions from zero-result queries (heuristics)
/// 3. Parse existing alias map (lib/services/search_aliases.dart) unless overridden with --aliases
/// 4. Output proposed additions plus a full updated alias map (JSON) for review
///
/// Usage:
///   dart run tool/alias_pipeline.dart --file=telemetry_export.json > alias_proposal.txt
///
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final telemetryPath = _arg(args, '--file') ?? 'telemetry_export.json';
  final aliasPath =
      _arg(args, '--aliases') ?? 'lib/services/search_aliases.dart';
  final telemetryFile = File(telemetryPath);
  if (!telemetryFile.existsSync()) {
    stderr.writeln('Telemetry file not found: $telemetryPath');
    exit(1);
  }
  dynamic decoded;
  try {
    decoded = json.decode(await telemetryFile.readAsString());
  } catch (e) {
    stderr.writeln('Invalid telemetry JSON: $e');
    exit(1);
  }
  if (decoded is! List) {
    stderr.writeln('Telemetry JSON must be an array of events.');
    exit(1);
  }
  final events = decoded.cast<dynamic>();

  final existing = _parseExistingAliases(aliasPath);
  final suggestions = _generateSuggestions(events);
  if (suggestions.isEmpty) {
    print('No new alias suggestions.');
    return;
  }
  final additions = <String, List<String>>{};
  suggestions.forEach((target, sources) {
    final current = existing[target] ?? const <String>[];
    final newVals = sources.where((s) => !current.contains(s)).toList();
    if (newVals.isNotEmpty) {
      additions[target] = (List<String>.from(newVals)..sort());
      existing[target] = [...current, ...newVals];
    }
  });
  if (additions.isEmpty) {
    print('All suggestions already represented in existing aliases.');
    return;
  }
  print(
    '--- Alias Pipeline Proposed Additions (merge into kSearchAliases) ---',
  );
  additions.forEach((k, v) {
    print("  '$k': ${json.encode(v)},");
  });
  print('--- Full Updated Alias Map (JSON for reference) ---');
  final sortedKeys = existing.keys.toList()..sort();
  final stable = <String, List<String>>{};
  for (final k in sortedKeys) {
    final vals = [...existing[k]!];
    vals.sort();
    stable[k] = vals;
  }
  print(const JsonEncoder.withIndent('  ').convert(stable));
}

Map<String, List<String>> _parseExistingAliases(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  try {
    final content = file.readAsStringSync();
    final mapMatch = RegExp(
      r'kSearchAliases\s*=\s*{([\s\S]*?)};',
    ).firstMatch(content);
    if (mapMatch == null) return {};
    final body = mapMatch.group(1)!;
    final entryRe = RegExp(
      r"'([^']+)'\s*:\s*\[(.*?)\],",
      multiLine: true,
      dotAll: true,
    );
    final out = <String, List<String>>{};
    for (final m in entryRe.allMatches(body)) {
      final key = m.group(1)!;
      final valsStr = m.group(2)!;
      final vals = <String>[];
      final valRe = RegExp(r"'([^']+)'");
      for (final v in valRe.allMatches(valsStr)) {
        vals.add(v.group(1)!);
      }
      out[key] = vals;
    }
    return out;
  } catch (_) {
    return {};
  }
}

Map<String, Set<String>> _generateSuggestions(List events) {
  final zeroCounts = <String, int>{};
  for (final e in events) {
    if (e is Map) {
      if (e['type'] == 'search' && (e['results'] is int) && e['results'] == 0) {
        final q = (e['q'] ?? '').toString().trim().toLowerCase();
        if (q.isEmpty) continue;
        zeroCounts[q] = (zeroCounts[q] ?? 0) + 1;
      }
    }
  }
  if (zeroCounts.isEmpty) return {};
  final misspell = {
    'toiletpaper': 'toilet paper',
    'paper towls': 'paper towels',
    'papertowels': 'paper towels',
    'q tips': 'qtips',
    'q-tip': 'qtip',
  };
  final suggestions = <String, Set<String>>{};
  final ordered = zeroCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in ordered.take(150)) {
    final q = e.key;
    if (q.length < 3 || RegExp(r'^\d+$').hasMatch(q)) continue;
    if (misspell.containsKey(q)) {
      suggestions.putIfAbsent(misspell[q]!, () => <String>{}).add(q);
      continue;
    }
    if (q.endsWith('s') && q.length > 3) {
      final singular = q.substring(0, q.length - 1);
      suggestions.putIfAbsent(singular, () => <String>{}).add(q);
    } else if (!q.endsWith('s')) {
      suggestions.putIfAbsent(q + 's', () => <String>{}).add(q);
    }
    final compound = _splitCompound(q);
    if (compound != null && compound != q) {
      suggestions.putIfAbsent(compound, () => <String>{}).add(q);
    }
    if (q.contains('-')) {
      final noHyphen = q.replaceAll('-', ' ');
      suggestions.putIfAbsent(noHyphen, () => <String>{}).add(q);
    }
  }
  return suggestions;
}

String? _splitCompound(String input) {
  if (input.contains(' ') || input.length < 6) return null;
  final alpha = RegExp(r'^[a-z]+$');
  for (int i = 3; i <= input.length - 3; i++) {
    final left = input.substring(0, i);
    final right = input.substring(i);
    if (alpha.hasMatch(left) && alpha.hasMatch(right)) {
      return '$left $right';
    }
  }
  return null;
}

String? _arg(List<String> args, String key) {
  for (final a in args) {
    if (a.startsWith('$key=')) return a.substring(key.length + 1);
  }
  return null;
}
