import 'dart:convert';
import 'dart:io';

/// Detects and cleans Taco Bell product JSON files that were accidentally
/// concatenated as multiple top-level JSON arrays (e.g. "]\n[").
/// Strategy: if a file contains more than one '[' at top-level producing
/// a pattern of multiple arrays, we attempt to split and keep the largest
/// parsed array (assuming it is the enriched version) OR, if all arrays
/// parse, merge them (dedup by product id) when both are meaningful.
/// A .bak backup is created before modifying.
Future<void> main() async {
  final dir = Directory('assets/stores/taco_bell');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }
  int filesScanned = 0;
  int filesFixed = 0;
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.json')) continue;
    if (name.startsWith('_')) continue; // skip catalogs/templates
    filesScanned++;
    final content = await entity.readAsString();
    if (!content.contains('\n[') || !content.contains(']\n[')) {
      // Single array (likely) or compact single-line; skip.
      continue;
    }
    // Split on pattern of end/start of arrays
    final parts = content.split(RegExp(r']\s*\n\s*\['));
    if (parts.length < 2) continue;
    // Reconstruct each candidate array text.
    final arrays = <List<dynamic>>[];
    for (var i = 0; i < parts.length; i++) {
      String text;
      if (i == 0) {
        text = parts[i] + ']';
      } else if (i == parts.length - 1) {
        text = '[' + parts[i];
      } else {
        text = '[' + parts[i] + ']';
      }
      try {
        final parsed = jsonDecode(text);
        if (parsed is List) arrays.add(parsed);
      } catch (_) {
        // ignore parse failure
      }
    }
    if (arrays.isEmpty) continue;
    // Choose strategy: if any array length > others significantly, keep largest.
    arrays.sort((a, b) => b.length.compareTo(a.length));
    List<dynamic> finalArray = arrays.first;
    // If there is a second array with unique ids, merge.
    if (arrays.length > 1) {
      final idSet = <String>{};
      final merged = <dynamic>[];
      for (final arr in arrays) {
        for (final item in arr) {
          if (item is Map && item['id'] is String) {
            final id = item['id'] as String;
            if (idSet.add(id)) merged.add(item);
          } else {
            merged.add(item);
          }
        }
      }
      // Use merged if it doesn't shrink the primary list.
      if (merged.length >= finalArray.length) finalArray = merged;
    }
    // Backup and write cleaned file (pretty format).
    final bak = File(entity.path + '.dup.bak');
    if (!bak.existsSync()) await bak.writeAsString(content);
    final encoder = const JsonEncoder.withIndent('  ');
    await entity.writeAsString(encoder.convert(finalArray) + '\n');
    filesFixed++;
    stdout.writeln(
      'Cleaned duplicate arrays in $name (items=${finalArray.length}).',
    );
  }
  stdout.writeln('Cleaning complete. scanned=$filesScanned fixed=$filesFixed');
}
