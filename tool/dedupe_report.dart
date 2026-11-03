#!/usr/bin/env dart

/// Scans partitioned product part files for potential duplicates based on
/// (storeId, category, subCategory, normalized name, unit).
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  bool summary = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--summary') summary = true;
    if (args[i] == '--help' || args[i] == '-h') {
      print('Usage: dart tool/dedupe_report.dart [--summary]');
      return;
    }
  }
  final root = Directory('assets/stores');
  if (!root.existsSync()) {
    stderr.writeln('assets/stores directory not found');
    exit(1);
  }
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('.json.bak'))
      .toList();

  final Map<String, List<String>> groups = {};
  for (final file in files) {
    try {
      final decoded = json.decode(file.readAsStringSync());
      if (decoded is! List) continue;
      for (final e in decoded) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final key = [
          m['storeId'] ?? '',
          m['category'] ?? '',
          m['subCategory'] ?? '',
          (m['name'] ?? '').toString().toLowerCase().trim(),
          (m['unit'] ?? '').toString().toLowerCase().trim(),
        ].join('||');
        groups.putIfAbsent(key, () => []).add(id);
      }
    } catch (_) {
      stderr.writeln('Failed to parse ${file.path}');
    }
  }
  final dupGroups = groups.entries.where((e) => e.value.length > 1).toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  if (dupGroups.isEmpty) {
    print('No duplicate (name+unit+category+subCategory+store) groups found.');
    return;
  }
  if (summary) {
    final top = dupGroups.take(5).toList();
    print(
      '[dedupe-summary] groups=${dupGroups.length}; top5=' +
          top.map((g) => '${g.value.length}x').join(','),
    );
    return;
  }
  print('Duplicate candidate groups (${dupGroups.length}):');
  for (final g in dupGroups.take(50)) {
    print(' * ${g.value.length}x -> ${g.value.join(', ')}');
  }
  if (dupGroups.length > 50) {
    print('   ... (${dupGroups.length - 50} more)');
  }
}
