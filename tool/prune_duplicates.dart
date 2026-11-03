#!/usr/bin/env dart

/// Prunes duplicate product entries across partitioned part files for a given
/// base asset (e.g. walmart-deli-prepared-meals-sides-partN.json) retaining
/// the entry with the lowest trailing numeric id per duplicate key.
///
/// Duplicate key definition matches `dedupe_report.dart`:
/// (storeId, category, subCategory, normalized name, unit)
///
/// Usage:
///   dart tool/prune_duplicates.dart --base walmart-deli-prepared-meals-sides
///   dart tool/prune_duplicates.dart --base walmart-deli-prepared-meals-sides --dry-run
///
/// The script rewrites the affected part files in-place unless --dry-run is
/// passed. Order of surviving items within each part file is preserved.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? base;
  bool dryRun = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--base' && i + 1 < args.length) {
      base = args[++i];
    } else if (a == '--dry-run') {
      dryRun = true;
    } else if (a == '--help' || a == '-h') {
      _usage();
      return;
    }
  }
  if (base == null) {
    stderr.writeln('Missing --base');
    _usage();
    exit(64); // usage
  }

  final dir = Directory('assets/stores');
  if (!dir.existsSync()) {
    stderr.writeln('assets/stores directory not found');
    exit(1);
  }

  final baseValue = base; // already validated non-null above
  final basePattern = RegExp('/${RegExp.escape(baseValue)}-part\\d+\\.json\$');
  final partFiles =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => basePattern.hasMatch('/${f.path.replaceAll('\\', '/')}'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (partFiles.isEmpty) {
    stderr.writeln('No part files found for base "$base"');
    exit(1);
  }

  final duplicateKeyToBestId = <String, String>{};
  final idToFile = <String, File>{};
  final idToObject = <String, Map<String, dynamic>>{};
  final fileToObjects = <File, List<Map<String, dynamic>>>{};

  // First pass: load all objects.
  for (final file in partFiles) {
    late final List<dynamic> decoded;
    try {
      decoded = json.decode(file.readAsStringSync()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Failed to parse ${file.path}: $e');
      exit(1);
    }
    final objects = <Map<String, dynamic>>[];
    for (final e in decoded) {
      if (e is Map<String, dynamic>) {
        objects.add(e);
      }
    }
    fileToObjects[file] = objects;
  }

  // Build duplicate groups.
  final keyToIds = <String, List<String>>{};
  for (final entry in fileToObjects.entries) {
    for (final obj in entry.value) {
      final id = (obj['id'] ?? '').toString();
      if (id.isEmpty) continue;
      idToFile[id] = entry.key;
      idToObject[id] = obj;
      final key = [
        obj['storeId'] ?? '',
        obj['category'] ?? '',
        obj['subCategory'] ?? '',
        (obj['name'] ?? '').toString().toLowerCase().trim(),
        (obj['unit'] ?? '').toString().toLowerCase().trim(),
      ].join('||');
      keyToIds.putIfAbsent(key, () => []).add(id);
    }
  }

  // Determine winners.
  for (final entry in keyToIds.entries) {
    if (entry.value.length == 1) continue;
    final ids = [...entry.value];
    ids.sort((a, b) => _numericSuffix(a).compareTo(_numericSuffix(b)));
    duplicateKeyToBestId[entry.key] = ids.first;
  }

  if (duplicateKeyToBestId.isEmpty) {
    print('No duplicate groups found for base "$base"');
    return;
  }

  final toRemoveIds = <String>{};
  for (final entry in keyToIds.entries) {
    if (entry.value.length <= 1) continue;
    final winner = duplicateKeyToBestId[entry.key]!;
    for (final id in entry.value) {
      if (id != winner) toRemoveIds.add(id);
    }
  }

  print('Duplicate groups: ${duplicateKeyToBestId.length}');
  print('Entries to remove: ${toRemoveIds.length}');
  if (dryRun) {
    print('Dry-run mode: no files modified. Sample removals:');
    for (final id in toRemoveIds.take(10)) {
      print('  - $id');
    }
    return;
  }

  // Modify in-memory lists preserving original order.
  for (final file in partFiles) {
    final objects = fileToObjects[file]!;
    final filtered = objects
        .where((o) => !toRemoveIds.contains(o['id']))
        .toList();
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(filtered) + '\n',
    );
    print(
      'Rewrote ${file.path} (was ${objects.length}, now ${filtered.length})',
    );
  }
  print('Prune complete. Consider re-running dedupe_report.dart');
}

int _numericSuffix(String id) {
  final m = RegExp(r'_(\d+)$').firstMatch(id);
  return m == null ? 1 << 30 : int.parse(m.group(1)!);
}

void _usage() {
  print(
    'Usage: dart tool/prune_duplicates.dart --base <base-name> [--dry-run]',
  );
}
