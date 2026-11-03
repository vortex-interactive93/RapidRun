/// Maintenance script to scan all product JSON files under assets/stores/**
/// and report (and optionally remove) duplicate product entries within the
/// same file. Intended for cleaning up repeated items like multiple
/// "Natural Delights Pitted Fresh Medjool Dates" entries in
/// `walmart-fresh-fruit.json`.
///
/// Usage (from repo root):
///   dart run tool/deduplicate_products.dart            (dry run)
///   dart run tool/deduplicate_products.dart --apply    (rewrite files)
///   dart run tool/deduplicate_products.dart --apply --root=assets/stores/walmart
///
/// Rules:
///  - A "duplicate" is any later item in the same file whose normalized name
///    matches a previous item OR whose id matches a previous id OR whose full
///    JSON map (after removing volatile fields like price) is identical.
///  - Normalized name: lowercase, trim, collapse internal whitespace, remove
///    trailing punctuation.
///  - When duplicates are removed the FIRST occurrence is kept.
///  - A backup of the original file is written as <file>.bak before rewrite.
///  - Script also reports potential cross-file duplicate names (not removed).
///
/// Safe: It never rewrites unless --apply is passed.
///
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final apply = args.contains('--apply');
  final rootArg = args.firstWhere(
    (a) => a.startsWith('--root='),
    orElse: () => '--root=assets/stores',
  );
  // Extract value after first '=' (String.split in Dart doesn't support limit)
  final eqIndex = rootArg.indexOf('=');
  final rootDir = eqIndex >= 0
      ? rootArg.substring(eqIndex + 1)
      : 'assets/stores';
  final dir = Directory(rootDir);
  if (!await dir.exists()) {
    stderr.writeln('Root directory not found: $rootDir');
    exitCode = 2;
    return;
  }

  final jsonFiles = await _listJsonFiles(dir);
  if (jsonFiles.isEmpty) {
    print('No JSON files under $rootDir');
    return;
  }

  final overallNameIndex = <String, List<String>>{}; // normalizedName -> files
  int totalDuplicates = 0;
  int totalRemoved = 0;

  for (final file in jsonFiles) {
    final content = await file.readAsString();
    dynamic decoded;
    try {
      decoded = json.decode(content);
    } catch (e) {
      stderr.writeln('Skipping (invalid JSON): ${file.path}  Error: $e');
      continue;
    }
    if (decoded is! List) continue; // Only process list-style product files

    final list = decoded.cast<dynamic>();
    final seenByName = <String, int>{};
    final seenById = <String, int>{};
    final seenHashes = <String, int>{};
    final toRemove = <int>{};

    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final name = (map['name'] ?? '').toString();
      final id = map['id']?.toString();
      final normName = _normalizeName(name);
      if (normName.isNotEmpty) {
        overallNameIndex.putIfAbsent(normName, () => []).add(file.path);
      }
      final structuralHash = _structuralHash(map);

      bool duplicate = false;
      if (id != null && seenById.containsKey(id)) {
        duplicate = true;
      } else if (normName.isNotEmpty && seenByName.containsKey(normName)) {
        duplicate = true;
      } else if (seenHashes.containsKey(structuralHash)) {
        duplicate = true;
      }

      if (duplicate) {
        toRemove.add(i);
      } else {
        if (id != null) seenById[id] = i;
        if (normName.isNotEmpty) seenByName[normName] = i;
        seenHashes[structuralHash] = i;
      }
    }

    if (toRemove.isEmpty) {
      print('[OK]  ${file.path}  (no duplicates)');
      continue;
    }

    totalDuplicates += toRemove.length;
    print(
      '[DUP] ${file.path}  duplicates=${toRemove.length}  entries=${list.length}',
    );

    if (apply) {
      // Build new list excluding removed indices
      final newList = <dynamic>[];
      for (var i = 0; i < list.length; i++) {
        if (!toRemove.contains(i)) newList.add(list[i]);
      }
      final encoder = const JsonEncoder.withIndent('  ');
      final newJson = encoder.convert(newList) + '\n';
      final backup = File(file.path + '.bak');
      if (!await backup.exists()) {
        await backup.writeAsString(content);
      }
      await file.writeAsString(newJson);
      print(
        '      Removed ${toRemove.length}; new length: ${newList.length} (backup: ${backup.path})',
      );
      totalRemoved += toRemove.length;
    }
  }

  // Cross-file duplicate name report (only names appearing in >=2 files)
  print('\nCross-file duplicate name summary (not modified):');
  final duplicatesAcross =
      overallNameIndex.entries
          .where((e) => e.value.toSet().length >= 2 && e.key.isNotEmpty)
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (duplicatesAcross.isEmpty) {
    print('  None.');
  } else {
    for (final e in duplicatesAcross.take(80)) {
      // limit output
      final files = e.value.toSet().length;
      print('  ${e.key}  -> $files files');
    }
    if (duplicatesAcross.length > 80) {
      print('  ... (${duplicatesAcross.length - 80} more)');
    }
  }

  print('\nSummary:');
  print('  Files scanned: ${jsonFiles.length}');
  print('  Duplicate entries found: $totalDuplicates');
  if (apply)
    print('  Entries removed: $totalRemoved');
  else
    print('  (dry run; pass --apply to rewrite files)');
}

String _normalizeName(String name) {
  var n = name.trim().toLowerCase();
  if (n.isEmpty) return n;
  n = n.replaceAll(RegExp(r'\s+'), ' ');
  n = n.replaceAll(RegExp(r'[.,;:!]+\s*'), '');
  return n;
}

String _structuralHash(Map<String, dynamic> map) {
  // Remove volatile fields that might differ but still represent same product.
  final clone = Map<String, dynamic>.from(map)..remove('price');
  return json.encode(clone); // deterministic if key order stable after encode
}

Future<List<File>> _listJsonFiles(Directory dir) async {
  final files = <File>[];
  await for (final ent in dir.list(recursive: true, followLinks: false)) {
    if (ent is File && ent.path.toLowerCase().endsWith('.json')) {
      files.add(ent);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}
