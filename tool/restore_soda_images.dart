import 'dart:convert';
import 'dart:io';

// Restores missing imageUrl values in assets/stores/walmart/soda.json
// by referencing the original raw source file assets/stores/walmart/soda original.json
// Usage:
//   dart tool/restore_soda_images.dart [--dry-run]
// Matching strategy: prefers originalName, falls back to name exact match.
// Writes pretty JSON.
Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final originalPath = 'assets/stores/walmart/soda original.json';
  final normalizedPath = 'assets/stores/walmart/soda.json';

  final originalFile = File(originalPath);
  if (!originalFile.existsSync()) {
    stderr.writeln('Original file not found: $originalPath');
    exit(1);
  }
  final normalizedFile = File(normalizedPath);
  if (!normalizedFile.existsSync()) {
    stderr.writeln('Normalized file not found: $normalizedPath');
    exit(1);
  }
  List original;
  List normalized;
  try {
    original = json.decode(await originalFile.readAsString()) as List;
  } catch (e) {
    stderr.writeln('Failed to parse original file: $e');
    exit(1);
  }
  try {
    normalized = json.decode(await normalizedFile.readAsString()) as List;
  } catch (e) {
    stderr.writeln('Failed to parse normalized file: $e');
    exit(1);
  }
  final nameToImage = <String, String>{};
  for (final e in original) {
    if (e is Map) {
      final name = (e['name'] ?? '').toString().trim();
      final img = (e['image'] ?? '').toString().trim();
      if (name.isNotEmpty && img.isNotEmpty) {
        nameToImage[name] = img;
      }
    }
  }
  int restored = 0;
  int alreadyHad = 0;
  int noSource = 0;
  for (final e in normalized) {
    if (e is! Map) continue;
    final img = (e['imageUrl'] ?? '').toString().trim();
    if (img.isNotEmpty) {
      alreadyHad++;
      continue;
    }
    final origName = (e['originalName'] ?? e['name'] ?? '').toString().trim();
    final source = nameToImage[origName];
    if (source != null) {
      e['imageUrl'] = source;
      restored++;
    } else {
      noSource++;
    }
  }
  if (!dryRun) {
    final encoder = const JsonEncoder.withIndent('  ');
    await normalizedFile.writeAsString(encoder.convert(normalized) + '\n');
  }
  stdout.writeln(
    '[restore_soda_images] restored=$restored hadImage=$alreadyHad missingSource=$noSource dryRun=$dryRun',
  );
}
