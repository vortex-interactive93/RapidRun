/// Script to optimize Walmart Dairy & Eggs related product JSON files.
/// Actions:
/// 1. Deduplicate product entries within each JSON file (by normalized name + image).
/// 2. Optionally split very large files into -partN segments for faster load.
///
/// This intentionally does NOT add IDs so schema stays consistent with existing
/// Walmart product JSON assets (which currently only have image/name/price fields).
///
/// Usage:
///   dart run tool/walmart_dairy_eggs_optimize.dart            (executes with defaults)
///   dart run tool/walmart_dairy_eggs_optimize.dart --dry-run  (prints planned changes)
///   dart run tool/walmart_dairy_eggs_optimize.dart --threshold 275 --chunk 275
///
/// Defaults:
///   threshold = 300 (only split if > 300 items after dedupe)
///   chunkSize = 300
///
/// Naming:
///   If a file exceeds threshold and is not already split (does not contain -part),
///   it will be replaced by files named `<base>-part1.json`, `<base>-part2.json`, etc.
///   The original file is deleted only after successful write of all part files.
///
/// Safe operations:
///   - Creates a `.bak` backup of any file it rewrites (single-file rewrite case) as
///     `<filename>.bak` (overwriting previous backup).
///   - For splits, original large file is renamed to `<filename>.bak` then part files written.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final parser = _ArgParser(args);
  final bool dryRun = parser.flag('--dry-run');
  final bool noBackups = parser.flag('--no-backups');
  final int threshold = parser.intValue('--threshold', 300);
  final int chunkSize = parser.intValue('--chunk', 300);

  // Dairy & Eggs related Walmart category files we want to optimize.
  // (Some may already be reasonably small; script skips missing files.)
  const targetBases = <String>[
    'walmart-milk',
    'walmart-non-dairy-milk',
    'walmart-yogurt',
    'walmart-cheese',
    'walmart-cream-cheese',
    'walmart-cream-and-creamers',
    'walmart-butter-margarine',
    'walmart-sourcream-dips',
    'walmart-eggs',
    'walmart-pudding-and-desserts',
  ];

  final dir = Directory('assets/stores/walmart');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exitCode = 1;
    return;
  }

  int totalBefore = 0;
  int totalAfter = 0;
  int filesProcessed = 0;
  int filesSplit = 0;
  int entriesRemoved = 0;

  for (final base in targetBases) {
    final file = File('${dir.path}/$base.json');
    if (!file.existsSync()) continue; // skip missing
    final originalContent = await file.readAsString();
    List<dynamic> data;
    try {
      data = json.decode(originalContent) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Skipping $base.json (not valid JSON array): $e');
      continue;
    }
    final beforeCount = data.length;
    totalBefore += beforeCount;

    final deduped = _dedupe(data);
    final afterDedup = deduped.length;
    final removed = beforeCount - afterDedup;
    entriesRemoved += removed;

    final needsSplit = afterDedup > threshold && !base.contains('-part');

    if (dryRun) {
      stdout.writeln(
        '[DRY-RUN] $base.json: $beforeCount -> $afterDedup (removed $removed)${needsSplit ? ' SPLIT into parts of $chunkSize' : ''}',
      );
      totalAfter += afterDedup; // pretend same
      filesProcessed++;
      continue;
    }

    if (needsSplit) {
      // Rename original to .bak
      if (!noBackups) await _backupFile(file);
      // Chunk and write parts
      int index = 0;
      int partNumber = 1;
      while (index < afterDedup) {
        final slice = deduped.sublist(
          index,
          (index + chunkSize).clamp(0, afterDedup),
        );
        final partPath = '${dir.path}/$base-part$partNumber.json';
        await File(
          partPath,
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(slice));
        stdout.writeln(
          'Wrote ${slice.length} items -> ${partPath.split('assets/stores/walmart/').last}',
        );
        index += slice.length;
        partNumber++;
      }
      filesSplit++;
      // Optionally delete the original (already backed up) to avoid double inclusion.
      if (file.existsSync()) {
        await file.delete();
      }
      totalAfter += afterDedup;
    } else {
      // Rewrite original only if changed.
      if (removed > 0) {
        if (!noBackups) await _backupFile(file);
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(deduped),
        );
        stdout.writeln(
          'Updated $base.json: $beforeCount -> $afterDedup (removed $removed)',
        );
      } else {
        stdout.writeln('No change $base.json ($beforeCount entries)');
      }
      totalAfter += afterDedup;
    }
    filesProcessed++;
  }

  stdout.writeln('--- Summary ---');
  stdout.writeln('Files processed: $filesProcessed');
  stdout.writeln('Files split:     $filesSplit');
  stdout.writeln('Entries removed: $entriesRemoved');
  stdout.writeln('Total before:    $totalBefore');
  stdout.writeln('Total after:     $totalAfter');
  stdout.writeln('Net reduction:   ${totalBefore - totalAfter}');
  stdout.writeln('Done.');
  if (!dryRun && noBackups) {
    // Remove any stale .bak files for our targetBases to keep asset set lean.
    for (final base in targetBases) {
      final bak = File('${dir.path}/$base.json.bak');
      if (bak.existsSync()) {
        try {
          await bak.delete();
          stdout.writeln('Removed backup ${bak.path} (no-backups mode)');
        } catch (_) {}
      }
    }
  }
}

List<Map<String, dynamic>> _dedupe(List<dynamic> raw) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue; // skip invalid
    final map = item.cast<String, dynamic>();
    final name = (map['name'] ?? '').toString();
    final image = (map['image'] ?? '').toString();
    if (name.isEmpty) continue; // skip nameless
    final key = _normalizeName(name) + '|' + image;
    if (seen.add(key)) {
      out.add(map);
    }
  }
  return out;
}

String _normalizeName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

Future<void> _backupFile(File file) async {
  final bak = File(file.path + '.bak');
  if (bak.existsSync()) {
    await bak.delete();
  }
  await file.copy(bak.path);
}

class _ArgParser {
  final List<String> _args;
  _ArgParser(this._args);

  bool flag(String name) => _args.contains(name);
  int intValue(String name, int defaultValue) {
    final idx = _args.indexOf(name);
    if (idx == -1 || idx == _args.length - 1) return defaultValue;
    final v = int.tryParse(_args[idx + 1]);
    return v ?? defaultValue;
  }
}
