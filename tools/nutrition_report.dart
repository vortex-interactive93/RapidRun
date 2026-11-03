import 'dart:convert';
import 'dart:io';

/// Generates a CSV report of all products (for a given store) that are
/// missing nutrition blocks or missing one or more core nutrition keys.
///
/// Usage:
///   dart run tools/nutrition_report.dart aldi > nutrition_missing.csv
///
/// Core keys: calories, fat_total_g, carbs_total_g, protein_g
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart nutrition_report.dart <store_name>');
    exit(64);
  }
  final store = args[0];
  final dir = Directory('assets/stores/$store');
  if (!dir.existsSync()) {
    stderr.writeln('Store directory not found: ${dir.path}');
    exit(66);
  }
  final core = ['calories', 'fat_total_g', 'carbs_total_g', 'protein_g'];
  final out = StringBuffer('file,id,name,missing_core_keys,has_nutrition\n');
  for (final file in dir.listSync()) {
    if (file is! File) continue;
    final name = file.path.split(Platform.pathSeparator).last;
    if (!name.startsWith('${store}_') || name.contains('_categories')) continue;
    if (!name.endsWith('.json')) continue;
    List data;
    try {
      data = json.decode(file.readAsStringSync()) as List;
    } catch (_) {
      continue;
    }
    for (final item in data) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final id = map['id'] ?? '';
      final pname = (map['name'] ?? '').toString().replaceAll(',', ' ');
      final nutrition = map['nutrition'];
      if (nutrition is! Map) {
        out.writeln('${name},${id},${pname},ALL (no block),false');
        continue;
      }
      final keys = nutrition.keys.cast<String>().toSet();
      final missing = core.where((c) => !keys.contains(c)).toList();
      if (missing.isNotEmpty) {
        out.writeln('${name},${id},${pname},${missing.join('|')},true');
      }
    }
  }
  stdout.write(out.toString());
}
