/// Prunes stale .bak backup files created by data maintenance scripts.
///
/// Strategy:
///  * Enumerate any *.json.bak and *.bak in assets/stores/**
///  * Compute total size
///  * By default (no flags) prints a summary (safe dry run)
///  * With --apply deletes backups older than N days (default 7) OR keeps the
///    most recent backup per original file regardless of age
///  * Flags:
///       --apply              Actually delete
///       --days=10            Age threshold in days (default 7)
///       --store=walmart      Limit to a specific store directory
///       --keep-latest        Always preserve newest backup per original
///
/// Safe: does NOT touch non .bak files.
import 'dart:io';

Future<void> main(List<String> args) async {
  final apply = args.contains('--apply');
  final keepLatest = args.contains('--keep-latest');
  final daysArg = _argValue(args, '--days');
  final store = _argValue(args, '--store');
  final days = int.tryParse(daysArg ?? '') ?? 7;
  final cutoff = DateTime.now().subtract(Duration(days: days));

  final root = Directory('assets/stores');
  if (!root.existsSync()) {
    stderr.writeln('Directory not found: assets/stores');
    return;
  }
  final backups = <File>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll('\\', '/');
    if (!path.endsWith('.bak')) continue;
    if (store != null && store.isNotEmpty) {
      if (!path.contains('/$store/')) continue;
    }
    backups.add(entity);
  }
  if (backups.isEmpty) {
    stdout.writeln('No backup files found.');
    return;
  }
  int totalBytes = 0;
  for (final f in backups) {
    totalBytes += f.lengthSync();
  }
  final byOriginal = <String, List<File>>{};
  for (final f in backups) {
    final orig = f.path.substring(0, f.path.length - 4); // strip .bak
    byOriginal.putIfAbsent(orig, () => []).add(f);
  }
  // Sort each list newest first
  byOriginal.values.forEach(
    (list) => list.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    ),
  );

  final toDelete = <File>[];
  for (final entry in byOriginal.entries) {
    final files = entry.value;
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final lm = f.lastModifiedSync();
      final olderThan = lm.isBefore(cutoff);
      final keep = (i == 0 && keepLatest) || !olderThan;
      if (!keep) toDelete.add(f);
    }
  }

  final bytesDelete = toDelete.fold<int>(0, (s, f) => s + f.lengthSync());
  stdout.writeln('Backup pruning summary:');
  stdout.writeln(' Total backups: ${backups.length}');
  stdout.writeln(
    ' Total size: ${(totalBytes / 1024).toStringAsFixed(1)} KB (${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
  );
  stdout.writeln(
    ' Age cutoff: > $days days (before ${cutoff.toIso8601String()})',
  );
  stdout.writeln(' Keep latest per original: $keepLatest');
  stdout.writeln(' Candidates for deletion: ${toDelete.length}');
  stdout.writeln(
    ' Deletion size: ${(bytesDelete / 1024).toStringAsFixed(1)} KB (${(bytesDelete / 1024 / 1024).toStringAsFixed(2)} MB)',
  );
  if (!apply) {
    stdout.writeln('\nDry run only. Re-run with --apply to delete.');
  } else {
    int deleted = 0;
    for (final f in toDelete) {
      try {
        f.deleteSync();
        deleted++;
      } catch (_) {}
    }
    stdout.writeln(' Deleted $deleted backups.');
  }
}

String? _argValue(List<String> args, String key) {
  for (final a in args) {
    if (a.startsWith('$key=')) return a.substring(key.length + 1);
  }
  return null;
}
