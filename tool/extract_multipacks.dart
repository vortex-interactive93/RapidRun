/// Extracts multi-pack products from Walmart category asset files into a new
/// per-section "Multipacks" subcategory/file, removing them from their
/// original product type files.
///
/// Detection heuristics (case-insensitive) on `name` or `shortName`:
///  * Starts with "(N pack" or "(N-pack" (e.g., "(3 pack)")
///  * Contains standalone patterns: "N pack", "N-pack", "N pk", "Npk", "pack of N"
///  * Contains size keywords: "twin pack", "triple pack", "quad pack", "value pack"
///  * Contains count + "ct" when also followed by a keyword like "pack" (to avoid false positives)
///
/// Usage:
///   dart run tool/extract_multipacks.dart --dry-run   (report only)
///   dart run tool/extract_multipacks.dart             (apply changes)
/// Options:
///   --sections=Bath & Body,Oral Care   Limit to specific section names (comma separated)
///   --verbose                         Print each moved item id/name
///
/// Behavior:
///  * Parses walmart_categories.json to map product type file paths to section names.
///  * Scans each referenced file; identifies multi-pack items.
///  * Aggregates per section; writes/updates a <section-slug>-multipacks.json file.
///  * Adds (or ensures) a productTypes entry for "Multipacks" in that section with the new file path.
///  * Removes moved items from original files (with .bak backup on first write) unless --dry-run.
///  * Sets/overrides item['subCategory'] = 'Multipacks'.
///
/// Safe re-run: Only items still in source files will be moved; already moved items persist in multipacks file.
import 'dart:convert';
import 'dart:io';
import 'package:rapidrun/utils/multipack_detection.dart';

String slugify(String s) {
  var out = s.toLowerCase();
  out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  out = out.replaceAll(RegExp(r'-+'), '-');
  out = out.replaceAll(RegExp(r'^-'), '');
  out = out.replaceAll(RegExp(r'-$'), '');
  return out;
}

// Deprecated internal function preserved for backwards compatibility if other tooling imports.
@Deprecated('Use isMultipackMap from multipack_detection.dart')
bool isMultipack(Map obj) => isMultipackMap(obj);

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final verbose = args.contains('--verbose');
  final sectionsFilterArg = args.firstWhere(
    (a) => a.startsWith('--sections='),
    orElse: () => '',
  );
  final sectionsFilter = sectionsFilterArg.isNotEmpty
      ? sectionsFilterArg
            .substring('--sections='.length)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
      : null;

  final walmartDir = Directory('assets/stores/walmart');
  final categoriesFile = File('${walmartDir.path}/walmart_categories.json');
  if (!await categoriesFile.exists()) {
    stderr.writeln('walmart_categories.json not found.');
    exit(1);
  }
  final categoriesRaw = await categoriesFile.readAsString();
  final categoriesJson = json.decode(categoriesRaw);
  if (categoriesJson is! List) {
    stderr.writeln('Unexpected categories root (expected List).');
    exit(1);
  }

  // Map filePath -> sectionName
  final fileToSection = <String, String>{};
  // SectionName -> section Map reference
  final sectionEntries = <String, Map<String, dynamic>>{};

  void walkCategory(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey('sectionName')) {
        final sectionName = node['sectionName'] as String;
        sectionEntries[sectionName] = node;
      }
      if (node.containsKey('productTypes') && node['productTypes'] is List) {
        final sectionName = node['sectionName'] as String?;
        if (sectionName != null) {
          for (final pt in (node['productTypes'] as List)) {
            if (pt is Map && pt['filePath'] is String) {
              fileToSection[pt['filePath'] as String] = sectionName;
            }
          }
        }
      }
      for (final v in node.values) {
        walkCategory(v);
      }
    } else if (node is List) {
      for (final v in node) walkCategory(v);
    }
  }

  walkCategory(categoriesJson);

  final sectionStats =
      <String, Map<String, int>>{}; // section -> {moved, remaining}
  final sectionAggregated = <String, List<Map<String, dynamic>>>{};
  final modifiedSourceFiles = <File>[];

  for (final entry in fileToSection.entries) {
    final filePath = entry.key;
    final sectionName = entry.value;
    if (sectionsFilter != null && !sectionsFilter.contains(sectionName))
      continue;
    final file = File(filePath);
    if (!await file.exists()) continue; // skip missing
    final raw = await file.readAsString();
    dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (e) {
      stderr.writeln('Skipping invalid JSON: $filePath ($e)');
      continue;
    }
    if (decoded is! List) continue;
    int moved = 0;
    final keep = <dynamic>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        if (isMultipackMap(item)) {
          moved++;
          final clone = Map<String, dynamic>.from(item);
          clone['subCategory'] = 'Multipacks';
          sectionAggregated.putIfAbsent(sectionName, () => []).add(clone);
          if (verbose) {
            stdout.writeln(
              '[${sectionName}] MOVE ${(item['id'] ?? item['name'] ?? item['shortName'])}',
            );
          }
          continue; // exclude from original
        }
      }
      keep.add(item);
    }
    if (moved > 0) {
      sectionStats.putIfAbsent(
        sectionName,
        () => {'moved': 0, 'sources': 0, 'remaining': 0},
      );
      sectionStats[sectionName]!['moved'] =
          (sectionStats[sectionName]!['moved'] ?? 0) + moved;
      sectionStats[sectionName]!['sources'] =
          (sectionStats[sectionName]!['sources'] ?? 0) + 1;
      sectionStats[sectionName]!['remaining'] =
          (sectionStats[sectionName]!['remaining'] ?? 0) + keep.length;
      if (!dryRun) {
        final bak = File('$filePath.bak');
        if (!await bak.exists()) await bak.writeAsString(raw);
        final encoder = const JsonEncoder.withIndent('  ');
        await file.writeAsString(encoder.convert(keep) + '\n');
        modifiedSourceFiles.add(file);
      }
    }
  }

  // Write per-section multipacks files & update categories JSON.
  if (!dryRun) {
    bool categoriesChanged = false;
    for (final sectionName in sectionAggregated.keys) {
      final slug = slugify(sectionName);
      final mpFilePath = 'assets/stores/walmart/${slug}-multipacks.json';
      final mpFile = File(mpFilePath);

      List existing = [];
      if (await mpFile.exists()) {
        try {
          final existingRaw = await mpFile.readAsString();
          final ex = json.decode(existingRaw);
          if (ex is List) existing = ex;
        } catch (_) {}
      }
      // Merge (avoid duplicates by id+name)
      final existingKey = <String>{};
      for (final e in existing) {
        if (e is Map) {
          existingKey.add('${e['id']}_${e['name']}_${e['shortName']}');
        }
      }
      for (final item in sectionAggregated[sectionName]!) {
        final key = '${item['id']}_${item['name']}_${item['shortName']}';
        if (!existingKey.contains(key)) {
          existing.add(item);
          existingKey.add(key);
        }
      }
      final encoder = const JsonEncoder.withIndent('  ');
      await mpFile.writeAsString(encoder.convert(existing) + '\n');

      // Ensure Multipacks productType present
      final sectionMap = sectionEntries[sectionName];
      if (sectionMap != null) {
        final pts = (sectionMap['productTypes'] as List?) ?? [];
        final already = pts.any(
          (pt) =>
              pt is Map &&
              (pt['name'] == 'Multipacks' || pt['filePath'] == mpFilePath),
        );
        if (!already) {
          pts.add({
            'name': 'Multipacks',
            'iconCodePoint': null,
            'filePath': mpFilePath,
          });
          sectionMap['productTypes'] = pts;
          categoriesChanged = true;
        }
      }
    }

    if (categoriesChanged) {
      final categoriesBak = File('${categoriesFile.path}.bak');
      if (!await categoriesBak.exists())
        await categoriesBak.writeAsString(categoriesRaw);
      final encoder = const JsonEncoder.withIndent('  ');
      await categoriesFile.writeAsString(
        encoder.convert(categoriesJson) + '\n',
      );
    }
  }

  // Summary
  stdout.writeln('Multipack extraction summary:');
  stdout.writeln(' Dry run: $dryRun');
  stdout.writeln(
    ' Sections processed: ${sectionsFilter?.length ?? sectionEntries.length}',
  );
  if (sectionStats.isEmpty) {
    stdout.writeln(' No multipack candidates found with current heuristics.');
  } else {
    stdout.writeln(' Per-section results:');
    for (final e in sectionStats.entries) {
      stdout.writeln(
        '  ${e.key}: moved ${e.value['moved']} from ${e.value['sources']} files (remaining in those files: ${e.value['remaining']})',
      );
    }
  }
  if (!dryRun) {
    stdout.writeln('\nSource files modified: ${modifiedSourceFiles.length}');
    stdout.writeln(
      'New multipack files created/updated: ${sectionAggregated.length}',
    );
  } else {
    stdout.writeln('\nRe-run without --dry-run to apply changes.');
  }
}
