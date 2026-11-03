/// Maintenance script to set every product object's `description` and
/// `benefits` fields to null in all JSON list files under a given root
/// (default: assets/stores).
///
/// This is useful if you want to intentionally clear all descriptions so they
/// can be regenerated, re-ingested, or localized later without stale text.
///
/// Behavior:
///   * Only processes files whose top-level JSON is a List.
///   * Each element that is a Map<String, dynamic> will have `description`
///     and `benefits` inserted (value = null) or overwritten to null.
///   * Creates a single backup `<file>.bak` if one does not already exist
///     (re-uses any existing .bak created by other maintenance scripts).
///   * Dry run by default; pass `--apply` to rewrite files.
///
/// Usage (from repo root):
///   dart run tool/nullify_descriptions.dart
///   dart run tool/nullify_descriptions.dart --apply
///   dart run tool/nullify_descriptions.dart --apply --root=assets/stores/walmart
///
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final apply = args.contains('--apply');
  final rootArg = args.firstWhere(
    (a) => a.startsWith('--root='),
    orElse: () => '--root=assets/stores',
  );
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

  int filesChanged = 0;
  int totalDescriptionsSet = 0;
  int totalBenefitsSet = 0;

  for (final file in jsonFiles) {
    final content = await file.readAsString();
    dynamic decoded;
    try {
      decoded = json.decode(content);
    } catch (e) {
      stderr.writeln('[SKIP] Invalid JSON: ${file.path}  Error: $e');
      continue;
    }
    if (decoded is! List) {
      // Not a list style product file; ignore silently.
      continue;
    }
    final list = decoded.cast<dynamic>();
    int descModifiedInFile = 0;
    int benefitsModifiedInFile = 0;
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map) {
        final map = item.cast<String, dynamic>();
        // Description changes
        if (map['description'] != null || !map.containsKey('description')) {
          descModifiedInFile++;
          map['description'] = null;
        }
        // Benefits changes
        if (map['benefits'] != null || !map.containsKey('benefits')) {
          benefitsModifiedInFile++;
          map['benefits'] = null;
        }
      }
    }
    if (descModifiedInFile == 0 && benefitsModifiedInFile == 0) {
      // Nothing to do.
      continue;
    }

    if (apply) {
      final encoder = const JsonEncoder.withIndent('  ');
      final newJson = encoder.convert(list) + '\n';
      final backup = File(file.path + '.bak');
      if (!await backup.exists()) {
        await backup.writeAsString(content);
      }
      await file.writeAsString(newJson);
      print(
        '[CHG] ${file.path}  desc_null=$descModifiedInFile benefits_null=$benefitsModifiedInFile (backup: ${backup.path})',
      );
    } else {
      print(
        '[DRY] ${file.path}  would_desc_null=$descModifiedInFile would_benefits_null=$benefitsModifiedInFile',
      );
    }
    filesChanged++;
    totalDescriptionsSet += descModifiedInFile;
    totalBenefitsSet += benefitsModifiedInFile;
  }

  print('\nSummary:');
  print('  Root:        $rootDir');
  print('  Files scan:  ${jsonFiles.length}');
  print('  Files mod:   $filesChanged');
  print('  Descriptions set to null: $totalDescriptionsSet');
  print('  Benefits set to null:     $totalBenefitsSet');
  if (!apply) {
    print('  (dry run; re-run with --apply to persist changes)');
  }
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
