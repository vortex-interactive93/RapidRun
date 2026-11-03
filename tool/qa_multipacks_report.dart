/// QA reporting script for Multipack extraction accuracy.
///
/// Provides:
///  * Counts of total multipack items per section
///  * Any items inside multipack files that NO LONGER match heuristics
///    (potential drift / manual edits)
///  * Any remaining items in source product type files that now match heuristics
///    (missed on extraction; likely newly added or heuristic gap)
///
/// Usage:
///   dart run tool/qa_multipacks_report.dart                    (default Walmart scan)
///   dart run tool/qa_multipacks_report.dart --sections=Pantry,Produce
///   dart run tool/qa_multipacks_report.dart --store=walmart
///
import 'dart:convert';
import 'dart:io';
import 'package:rapidrun/utils/multipack_detection.dart';

Future<void> main(List<String> args) async {
  final store = _argValue(args, '--store') ?? 'walmart';
  final sectionsFilter = _argValue(
    args,
    '--sections',
  )?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

  final categoriesPath = 'assets/stores/$store/${store}_categories.json';
  final categoriesFile = File(categoriesPath);
  if (!categoriesFile.existsSync()) {
    stderr.writeln('Categories file not found: $categoriesPath');
    exit(1);
  }
  final categoriesJson = json.decode(await categoriesFile.readAsString());
  if (categoriesJson is! List) {
    stderr.writeln('Unexpected categories root (expected List).');
    exit(1);
  }

  final multipackFiles = <String, String>{}; // section -> mp file path
  final sectionProductTypeFiles =
      <String, List<String>>{}; // section -> list files (excluding multipacks)

  void walk(node) {
    if (node is Map) {
      if (node['sectionName'] is String && node['productTypes'] is List) {
        final section = node['sectionName'] as String;
        final pts = node['productTypes'] as List;
        for (final pt in pts) {
          if (pt is Map && pt['filePath'] is String) {
            final fp = pt['filePath'] as String;
            if (pt['name'] == 'Multipacks' || fp.contains('-multipacks.json')) {
              multipackFiles[section] = fp;
            } else {
              sectionProductTypeFiles.putIfAbsent(section, () => []).add(fp);
            }
          }
        }
      }
      for (final v in node.values) walk(v);
    } else if (node is List) {
      for (final v in node) walk(v);
    }
  }

  walk(categoriesJson);

  int totalMultipackItems = 0;
  int heuristicMismatches = 0;
  int missedCandidates = 0;
  final mismatches = <String, List<Map<String, dynamic>>>{};
  final missed = <String, List<Map<String, dynamic>>>{};

  // Scan multipack files for items that no longer satisfy heuristics.
  for (final entry in multipackFiles.entries) {
    final section = entry.key;
    if (sectionsFilter != null && !sectionsFilter.contains(section)) continue;
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final list = json.decode(await file.readAsString());
    if (list is! List) continue;
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        totalMultipackItems++;
        if (!isMultipackMap(item)) {
          heuristicMismatches++;
          mismatches.putIfAbsent(section, () => []).add(item);
        }
      }
    }
  }

  // Scan remaining product type files for missed candidates.
  for (final entry in sectionProductTypeFiles.entries) {
    final section = entry.key;
    if (sectionsFilter != null && !sectionsFilter.contains(section)) continue;
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final list = json.decode(await file.readAsString());
      if (list is! List) continue;
      for (final item in list) {
        if (item is Map<String, dynamic> && isMultipackMap(item)) {
          missedCandidates++;
          missed.putIfAbsent(section, () => []).add(item);
        }
      }
    }
  }

  stdout.writeln('Multipack QA Report for store: $store');
  stdout.writeln(
    ' Sections scanned: ' +
        (sectionsFilter?.join(', ') ?? multipackFiles.keys.join(', ')),
  );
  stdout.writeln(' Total multipack items: $totalMultipackItems');
  stdout.writeln(
    ' Heuristic mismatches inside multipack files: $heuristicMismatches',
  );
  stdout.writeln(' Missed candidates still in originals: $missedCandidates');

  if (heuristicMismatches > 0) {
    stdout.writeln('\nExamples of mismatches (first 8 per section):');
    for (final e in mismatches.entries) {
      stdout.writeln('  Section: ${e.key} (${e.value.length})');
      for (final item in e.value.take(8)) {
        stdout.writeln(
          '    - ${(item['id'] ?? '')} ${(item['name'] ?? item['shortName'] ?? '')}',
        );
      }
    }
  }
  if (missedCandidates > 0) {
    stdout.writeln('\nExamples of missed candidates (first 8 per section):');
    for (final e in missed.entries) {
      stdout.writeln('  Section: ${e.key} (${e.value.length})');
      for (final item in e.value.take(8)) {
        stdout.writeln(
          '    - ${(item['id'] ?? '')} ${(item['name'] ?? item['shortName'] ?? '')}',
        );
      }
    }
  }

  stdout.writeln(
    '\nStatus: ' +
        (heuristicMismatches == 0 && missedCandidates == 0
            ? 'CLEAN'
            : 'ISSUES DETECTED'),
  );
}

String? _argValue(List<String> args, String key) {
  for (final a in args) {
    if (a.startsWith('$key=')) return a.substring(key.length + 1);
  }
  return null;
}
