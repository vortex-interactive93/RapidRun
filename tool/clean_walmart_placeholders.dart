/// Cleans Walmart product JSON asset files by removing objects whose
/// imageUrl matches known placeholder image signatures (e.g., repeated
/// hash pairs that map to the generic 'Photo Coming Soon' image).
///
/// Usage (from repo root):
///   dart run tool/clean_walmart_placeholders.dart [--dry-run]
///
/// Behavior:
///  * Scans assets/stores/walmart/*.json
///  * For each JSON array file, filters out any object (Map) whose
///    `imageUrl` String contains any placeholder signature substring.
///  * Writes a backup <filename>.bak (only once; does not overwrite existing)
///    before rewriting the cleaned file unless --dry-run supplied.
///  * Emits a summary (files changed, products removed, remaining count).
///
/// Placeholder signature rationale:
/// We observed that bad placeholder images reuse an identical GUID/hash pair
/// segment in the URL path. Example:
///   1935136a-1e17-4b5f-8d6a-b362a07e7163.03d5778a809fbcaa05e17582053f6cf0
/// Real product images vary these hash segments; placeholders repeat.
/// This script currently targets the known repeated signature(s). Add more
/// as discovered.
///
/// Safe to re-run: re-running after cleanup should find zero matches and
/// leave files unchanged.
import 'dart:convert';
import 'dart:io';

/// Known placeholder signature substrings inside the imageUrl.
const placeholderSignatures = <String>{
  '1935136a-1e17-4b5f-8d6a-b362a07e7163.03d5778a809fbcaa05e17582053f6cf0',
};

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final processAll = args.contains('--all'); // override category scoping
  final dir = Directory('assets/stores/walmart');
  if (!await dir.exists()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }

  // Collect all .json files under the walmart directory (flat, as current layout).
  var jsonFiles = await dir
      .list()
      .where((e) => e is File && e.path.endsWith('.json'))
      .cast<File>()
      .toList();

  // If not overridden, restrict to file names referenced in walmart_categories.json.
  Set<String>? scopedBasenames;
  if (!processAll) {
    final categoriesFile = File('${dir.path}/walmart_categories.json');
    if (await categoriesFile.exists()) {
      try {
        final raw = await categoriesFile.readAsString();
        final decoded = json.decode(raw);
        final collected = <String>{};
        void walk(dynamic node) {
          if (node is Map) {
            if (node.containsKey('filePath') && node['filePath'] is String) {
              final fp = node['filePath'] as String;
              // Extract basename only (files live directly in dir).
              final parts = fp.split('/')..removeWhere((p) => p.isEmpty);
              if (parts.isNotEmpty) {
                collected.add(parts.last);
              }
            }
            for (final v in node.values) {
              walk(v);
            }
          } else if (node is List) {
            for (final e in node) {
              walk(e);
            }
          }
        }

        walk(decoded);
        if (collected.isNotEmpty) {
          scopedBasenames = collected;
          final beforeCount = jsonFiles.length;
          jsonFiles = [
            for (final f in jsonFiles)
              if (scopedBasenames.contains(f.uri.pathSegments.last)) f,
          ];
          stdout.writeln(
            'Category scoping active: ${jsonFiles.length} of $beforeCount files will be processed. (Use --all to override)',
          );
        } else {
          stdout.writeln(
            'Warning: No filePath entries found in walmart_categories.json; processing all files.',
          );
        }
      } catch (e) {
        stderr.writeln('Failed to parse walmart_categories.json: $e');
        stdout.writeln(
          'Proceeding with all files. Use --dry-run first if unsure.',
        );
      }
    } else {
      stdout.writeln(
        'walmart_categories.json not found; processing all files.',
      );
    }
  } else {
    stdout.writeln(
      'Processing ALL walmart JSON files (override --all supplied).',
    );
  }

  int totalRemoved = 0;
  int totalBefore = 0;
  int totalAfter = 0;
  final perFile = <String, Map<String, int>>{};

  for (final file in jsonFiles) {
    try {
      final raw = await file.readAsString();
      final decoded = json.decode(raw);
      if (decoded is! List) continue; // skip non-array files

      totalBefore += decoded.length;
      int removedHere = 0;

      final filtered = decoded.where((element) {
        if (element is Map && element['imageUrl'] is String) {
          final url = element['imageUrl'] as String;
          if (placeholderSignatures.any(url.contains)) {
            removedHere++;
            return false; // drop
          }
        }
        return true; // keep
      }).toList();

      if (removedHere > 0) {
        totalRemoved += removedHere;
        totalAfter += filtered.length;
        perFile[file.path] = {'removed': removedHere, 'kept': filtered.length};
        if (!dryRun) {
          final bak = File('${file.path}.bak');
          if (!await bak.exists()) {
            await bak.writeAsString(raw);
          }
          // Pretty print with two spaces.
          final encoder = const JsonEncoder.withIndent('  ');
          final output = encoder.convert(filtered);
          await file.writeAsString(output + '\n');
        }
      } else {
        totalAfter += decoded.length;
      }
    } catch (e, st) {
      stderr.writeln('Error processing ${file.path}: $e');
      stderr.writeln(st);
    }
  }

  // Summary
  stdout.writeln('Walmart placeholder cleanup summary:');
  stdout.writeln(' Dry run: $dryRun');
  stdout.writeln(' Files scanned: ${jsonFiles.length}');
  if (scopedBasenames != null) {
    stdout.writeln(
      ' Scoped to ${scopedBasenames.length} category-referenced file names.',
    );
  }
  stdout.writeln(' Total items before: $totalBefore');
  stdout.writeln(' Total removed: $totalRemoved');
  stdout.writeln(' Total after: $totalAfter');
  if (perFile.isNotEmpty) {
    stdout.writeln('\nChanged files:');
    for (final entry in perFile.entries) {
      stdout.writeln(
        '  ${entry.key}: removed ${entry.value['removed']} kept ${entry.value['kept']}',
      );
    }
  } else {
    stdout.writeln(' No placeholder images found matching signatures.');
  }

  if (dryRun) {
    stdout.writeln('\nRe-run without --dry-run to apply changes.');
  }
}
