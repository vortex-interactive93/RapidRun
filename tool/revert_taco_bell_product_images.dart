/// Reverts (removes) product-level `imageUrl` fields from Taco Bell product JSON files.
///
/// This lets you manually curate and re-add images. Category hero images remain
/// untouched (we skip `taco_bell_categories.json`). Modifier set files are also skipped.
///
/// Usage:
///   dart run tool/revert_taco_bell_product_images.dart [--dryRun]
///
/// Behavior:
///   - Scans assets/stores/taco_bell/*.json (excluding categories + modifier sets)
///   - For each product (array element object) removes the `imageUrl` key if present
///   - Writes the file back (pretty JSON) unless --dryRun
///   - Before first write of a file, creates a single backup `<name>.with_images.bak`
///     containing the pre-modification content if that backup doesn't already exist.
///
/// Summary metrics: files processed, products scanned, imageUrls removed.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final dryRun = args.contains('--dryRun');
  final tacoDir = Directory('assets/stores/taco_bell');
  if (!tacoDir.existsSync()) {
    stderr.writeln('ERROR: Taco Bell directory not found at ${tacoDir.path}');
    exit(2);
  }

  final files =
      tacoDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .where((f) => !f.path.endsWith('taco_bell_categories.json'))
          .where((f) => !f.path.endsWith('_modifier_sets.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  int totalProducts = 0;
  int totalRemoved = 0;
  final perFileRemoved = <String, int>{};

  for (final file in files) {
    late String original;
    try {
      original = await file.readAsString();
      final decoded = json.decode(original);
      if (decoded is! List) {
        continue; // skip non-array structures
      }
      bool changed = false;
      int removedHere = 0;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          totalProducts++;
          if (item.containsKey('imageUrl')) {
            item.remove('imageUrl');
            removedHere++;
            changed = true;
          }
        }
      }
      if (removedHere > 0) {
        perFileRemoved[file.path] = removedHere;
        totalRemoved += removedHere;
      }
      if (changed && !dryRun) {
        // Create one-time backup
        final backup = File(file.path + '.with_images.bak');
        if (!backup.existsSync()) {
          await backup.writeAsString(original);
        }
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        await file.writeAsString(pretty + '\n');
      }
    } catch (e) {
      stderr.writeln('WARN: Failed processing ${file.path}: $e');
    }
  }

  stdout.writeln('=== Taco Bell Product Image Revert Summary ===');
  stdout.writeln('Dry Run: $dryRun');
  stdout.writeln('Files processed: ${files.length}');
  stdout.writeln('Products scanned: $totalProducts');
  stdout.writeln('imageUrl removed: $totalRemoved');
  if (perFileRemoved.isNotEmpty) {
    stdout.writeln('\nPer-file removals:');
    perFileRemoved.forEach(
      (k, v) =>
          stdout.writeln('  ${k.split('assets/stores/taco_bell/').last}: $v'),
    );
  } else {
    stdout.writeln('No imageUrl fields found to remove.');
  }
  if (!dryRun) {
    stdout.writeln('\nBackups created (if absent) as *.with_images.bak');
  }
}
