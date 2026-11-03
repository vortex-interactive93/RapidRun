// Tool to fix duplicate product IDs across ALDI asset JSON files by
// renaming IDs to use each file's own base name (minus partition suffix)
// plus a sequential number. Partitioned files (e.g. aldi_cookies_sweets-part1.json)
// are treated as a single group sharing a numbering sequence.
//
// Usage:
//   dart tool/fix_duplicate_product_ids.dart            (dry run)
//   dart tool/fix_duplicate_product_ids.dart --apply    (write changes)
//
// Safe-guards:
//  * Only rewrites a group if its existing ID prefix differs from the
//    normalized base name (prevents unnecessary churn on already-correct sets).
//  * Generates a mapping old->new printed to stdout for traceability.
//  * Skips .bak files.
//
// Limitations:
//  * Assumes each entry is a Map with an 'id' String field.
//  * Does not currently update any references elsewhere (none expected).
//
// After running with --apply, re-run: flutter test test/asset_schema_validation_test.dart

import 'dart:convert';
import 'dart:io';

final _partSuffix = RegExp(r'-part(\d+)$');
final _idNumber = RegExp(r'^(.*)_(\d+)$');

class _GroupFile {
  final File file;
  final String baseName; // e.g. aldi_cookies_sweets-part1
  final String normalized; // e.g. aldi_cookies_sweets
  List<dynamic> jsonList = const [];
  _GroupFile(this.file, this.baseName, this.normalized);
}

Future<int> main(List<String> args) async {
  final apply = args.contains('--apply');
  final dir = Directory('assets/stores/aldi');
  if (!await dir.exists()) {
    stderr.writeln('Directory not found: ${dir.path}');
    return 1;
  }

  final files = <_GroupFile>[];
  await for (final ent in dir.list()) {
    if (ent is! File) continue;
    final name = ent.uri.pathSegments.last;
    if (!name.endsWith('.json')) continue;
    if (name.endsWith('.bak')) continue;
    final base = name.substring(0, name.length - 5); // drop .json
    final normalized = base.replaceFirst(_partSuffix, '');
    files.add(_GroupFile(ent, base, normalized));
  }
  files.sort((a, b) => a.baseName.compareTo(b.baseName));

  // Load JSON
  for (final gf in files) {
    try {
      final raw = await gf.file.readAsString();
      final decoded = json.decode(raw);
      if (decoded is List) {
        gf.jsonList = decoded;
      } else {
        stderr.writeln('Skipping non-list JSON: ${gf.baseName}.json');
      }
    } catch (e) {
      stderr.writeln('Failed to parse ${gf.baseName}.json: $e');
    }
  }

  // Group by normalized
  final groups = <String, List<_GroupFile>>{};
  for (final gf in files) {
    groups.putIfAbsent(gf.normalized, () => []).add(gf);
  }

  int groupsEvaluated = 0;
  int groupsRewritten = 0;
  int idsRewritten = 0;

  for (final entry in groups.entries) {
    groupsEvaluated++;
    final normalized = entry.key; // desired prefix
    final groupFiles = entry.value
      ..sort((a, b) => a.baseName.compareTo(b.baseName));

    // Decide whether rewrite needed: if any list's first id has prefix not equal normalized
    bool needsRewrite = false;
    for (final gf in groupFiles) {
      if (gf.jsonList.isEmpty) continue;
      final first = gf.jsonList.first;
      if (first is Map && first['id'] is String) {
        final m = _idNumber.firstMatch(first['id']);
        if (m != null) {
          final prefix = m.group(1)!;
          if (prefix != normalized) {
            needsRewrite = true;
            break;
          }
        }
      }
    }
    if (!needsRewrite) continue; // already aligned, skip

    groupsRewritten++;

    // Collect all entries across parts preserving existing per-file order
    final allEntries = <Map<String, dynamic>>[];
    for (final gf in groupFiles) {
      for (final e in gf.jsonList) {
        if (e is Map<String, dynamic>) allEntries.add(e);
      }
    }
    final pad = allEntries.length >= 1000 ? 4 : 3;

    int counter = 1;
    final mapping = <String, String>{};
    for (final e in allEntries) {
      final oldId = e['id']?.toString() ?? '';
      final newId = '${normalized}_${counter.toString().padLeft(pad, '0')}';
      if (oldId != newId) {
        mapping[oldId] = newId;
        e['id'] = newId;
        idsRewritten++;
      }
      counter++;
    }

    // Redistribute entries back to part files keeping original counts
    int start = 0;
    for (final gf in groupFiles) {
      final length = gf.jsonList.length;
      if (length == 0) continue;
      final slice = allEntries.sublist(start, start + length);
      start += length;
      if (apply) {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(slice);
        await gf.file.writeAsString('$jsonStr\n');
      }
    }

    stdout.writeln(
      'Rewrote group "$normalized" (parts: ${groupFiles.length}) => ${mapping.length} ids updated',
    );
    if (mapping.isNotEmpty) {
      for (final kv in mapping.entries.take(5)) {
        stdout.writeln('  ${kv.key} -> ${kv.value}');
      }
      if (mapping.length > 5)
        stdout.writeln('  ... ${mapping.length - 5} more');
    }
  }

  stdout.writeln('\nSummary:');
  stdout.writeln('  Groups evaluated:  $groupsEvaluated');
  stdout.writeln('  Groups rewritten:  $groupsRewritten');
  stdout.writeln('  IDs rewritten:     $idsRewritten');
  stdout.writeln('  Mode: ${apply ? 'APPLY (files updated)' : 'DRY RUN'}');

  if (!apply && idsRewritten > 0) {
    stdout.writeln('\nRun again with --apply to persist these changes.');
  }

  return 0;
}
