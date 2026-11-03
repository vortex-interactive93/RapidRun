#!/usr/bin/env dart

/// Append helper: generates next id for a given base prefix inside JSON part files.
/// Usage: dart tool/generate_id.dart walmart_deli_prepared_meals_sides
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Provide an id prefix (e.g. walmart_deli_prepared_meals_sides)',
    );
    exit(64);
  }
  final prefix = args.first;
  final dir = Directory('assets/stores');
  if (!dir.existsSync()) {
    stderr.writeln('assets/stores directory missing');
    exit(1);
  }
  final regex = RegExp('"id"\s*:\s*"(${RegExp.escape(prefix)})_(\\d{3,})"');
  int maxNum = 0;
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.json') || f.path.endsWith('.json.bak')) continue;
    final content = f.readAsStringSync();
    for (final m in regex.allMatches(content)) {
      final numStr = m.group(2)!;
      final n = int.tryParse(numStr) ?? 0;
      if (n > maxNum) maxNum = n;
    }
  }
  final next = maxNum + 1;
  final nextStr = next.toString().padLeft(3, '0');
  print('NEXT_ID: ${prefix}_$nextStr');
}
