// Optimization & deduplication script for Walmart Bread & Bakery category files.
// Usage (examples):
//   dart run tool/walmart_bread_bakery_optimize.dart --dry-run
//   dart run tool/walmart_bread_bakery_optimize.dart --threshold=150 --chunk=120
//   dart run tool/walmart_bread_bakery_optimize.dart --no-backups
// Flags:
//   --dry-run      : Analyze & report without writing changes.
//   --threshold=N  : If a file's item count exceeds N, it will be split (default 400).
//   --chunk=N      : Split chunk size (default 250).
//   --no-backups   : Do not create .bak backup files.
//
// Behavior:
//   * Loads each targeted Bread & Bakery file in assets/stores/walmart.
//   * Deduplicates entries by normalized name (case & whitespace) + image if present.
//   * Skips items lacking a non-empty name (reports count); does not fabricate names.
//   * Optionally splits large lists into -part1, -part2, ... retaining original name order.
//   * Writes a summary report at the end.
//
// Notes:
//   If future enrichment adds names to currently nameless price-only entries, rerun with this
//   script (not dry-run) to apply dedupe logic to those newly named items.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final noBackups = args.contains('--no-backups');
  final thresholdArg = args.firstWhere(
    (a) => a.startsWith('--threshold='),
    orElse: () => '--threshold=400',
  );
  final chunkArg = args.firstWhere(
    (a) => a.startsWith('--chunk='),
    orElse: () => '--chunk=250',
  );
  final threshold = int.tryParse(thresholdArg.split('=').last) ?? 400;
  final chunkSize = int.tryParse(chunkArg.split('=').last) ?? 250;

  final dir = Directory('assets/stores/walmart');
  if (!dir.existsSync()) {
    stderr.writeln('Directory assets/stores/walmart not found.');
    exit(1);
  }

  final targetPattern = RegExp(
    r'^walmart-(cupcakes|bakery-donuts|cookies|pastries|breakfast-breads|keto-bread|gluten-free-bread|organic-bread|wheatbread|white-bread|english-muffins|sourdough|tortillas|cheesecakes|rolls)\.json$',
  );

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => targetPattern.hasMatch(f.uri.pathSegments.last))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stdout.writeln('No target Bread & Bakery files found.');
    return;
  }

  final summary = <String, Map<String, int>>{};

  for (final file in files) {
    final baseName = file.uri.pathSegments.last;
    stdout.writeln('Processing $baseName');

    List<dynamic> data;
    try {
      data = json.decode(file.readAsStringSync()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('  ! Skipping invalid JSON: $e');
      continue;
    }

    int originalCount = data.length;
    int nameless = 0;
    final seenKeys = <String, int>{};
    final deduped = <Map<String, dynamic>>[];

    for (final raw in data) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        nameless++;
        deduped.add(Map<String, dynamic>.from(raw));
        continue; // keep but can't dedupe by name
      }
      final norm = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final image = (raw['image'] ?? '').toString();
      final key = '$norm||$image';
      if (seenKeys.containsKey(key)) {
        // duplicate -> skip
        continue;
      }
      seenKeys[key] = deduped.length;
      deduped.add(Map<String, dynamic>.from(raw));
    }

    int removed = originalCount - deduped.length;

    summary[baseName] = {
      'original': originalCount,
      'after': deduped.length,
      'removed': removed,
      'nameless': nameless,
    };

    // Splitting if needed
    if (deduped.length > threshold) {
      final parts = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < deduped.length; i += chunkSize) {
        parts.add(
          deduped.sublist(
            i,
            i + chunkSize > deduped.length ? deduped.length : i + chunkSize,
          ),
        );
      }

      if (!dryRun) {
        if (!noBackups) {
          file.copySync('${file.path}.bak');
        }
        // Remove original file and write parts
        if (!dryRun) {
          file.deleteSync();
        }
        for (int i = 0; i < parts.length; i++) {
          final partFile = File(
            file.path.replaceFirst('.json', '-part${i + 1}.json'),
          );
          partFile.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(parts[i]),
          );
        }
        stdout.writeln('  Split into ${parts.length} parts');
      } else {
        stdout.writeln('  (dry-run) Would split into ${parts.length} parts');
      }
    } else {
      // Write deduped back if changed
      if (!dryRun && removed > 0) {
        if (!noBackups) {
          file.copySync('${file.path}.bak');
        }
        file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(deduped),
        );
        stdout.writeln('  Wrote deduped file (removed $removed)');
      } else if (dryRun) {
        stdout.writeln('  (dry-run) Would remove $removed duplicates');
      } else {
        stdout.writeln('  No changes needed');
      }
    }
  }

  stdout.writeln('\nSummary:');
  for (final entry in summary.entries) {
    final m = entry.value;
    stdout.writeln(
      '  ${entry.key}: original=${m['original']} after=${m['after']} removed=${m['removed']} nameless=${m['nameless']}',
    );
  }
  stdout.writeln('\nDone.');
}
