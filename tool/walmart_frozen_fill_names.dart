// Script to ensure all Walmart Frozen category JSON entries have a name.
// It generates placeholder names for entries missing a 'name' field, matching
// the existing Walmart asset style (only 'name', 'image' (optional), 'price').
//
// Usage:
//   dart run tool/walmart_frozen_fill_names.dart --dry-run
//   dart run tool/walmart_frozen_fill_names.dart --apply
//
// Options:
//   --dry-run  : Show planned changes without writing files (default if neither flag provided)
//   --apply    : Persist changes
//   --pad=3    : Zero-pad width for item numbering (default 3 => 001, 002)
//
// Naming pattern:
//   <SubCategory> Item <zero-padded index>
// e.g. "Frozen Vegetables Item 007"
//
// The script preserves existing entries with names. Order is unchanged.
// IDs are NOT added here (separate id generation script handles that).

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final apply = args.contains('--apply');
  final dryRun = !apply || args.contains('--dry-run');
  final padArg = args.firstWhere(
    (a) => a.startsWith('--pad='),
    orElse: () => '--pad=3',
  );
  final pad = int.tryParse(padArg.split('=').last) ?? 3;

  final dir = Directory('assets/stores/walmart');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }

  final targets = <String, String>{
    'walmart-frozen-potatoes.json': 'Frozen Potatoes',
    'walmart-frozen-vegetables.json': 'Frozen Vegetables',
    'walmart-frozen-fruit.json': 'Frozen Fruit',
    'walmart-frozen-appetizers-and-snacks.json': 'Frozen Appetizers & Snacks',
    'walmart-frozen-breakfast-meals.json': 'Frozen Breakfast Meals',
    'walmart-frozen-desserts.json': 'Frozen Desserts',
    'walmart-frozen-family-meals.json': 'Frozen Family Meals',
    'walmart-icecream.json': 'Ice Cream',
    'walmart-healthy-meals.json': 'Healthy Meals',
  };

  final encoder = const JsonEncoder.withIndent('  ');
  int updatedFiles = 0;
  int generatedNames = 0;

  for (final entry in targets.entries) {
    final file = File('${dir.path}/${entry.key}');
    if (!file.existsSync()) {
      stderr.writeln('Missing file: ${entry.key}');
      continue;
    }
    List<dynamic> data;
    try {
      data = json.decode(file.readAsStringSync()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Invalid JSON in ${entry.key}: $e');
      continue;
    }
    bool changed = false;
    int index = 1;
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is! Map) continue;
      if ((item['name'] ?? '').toString().trim().isEmpty) {
        final number = index.toString().padLeft(pad, '0');
        final generated = '${entry.value} Item $number';
        item['name'] = generated;
        generatedNames++;
        changed = true;
      }
      index++;
    }
    if (changed) {
      updatedFiles++;
      if (!dryRun) {
        final backup = File(file.path + '.bak_names');
        if (!backup.existsSync()) {
          try {
            backup.writeAsStringSync(file.readAsStringSync());
          } catch (_) {}
        }
        file.writeAsStringSync(encoder.convert(data));
      }
      stdout.writeln(
        '${apply ? 'Updated' : '(dry-run) Would update'} ${entry.key}',
      );
    }
  }

  stdout.writeln('\nSummary');
  stdout.writeln('  Generated names : $generatedNames');
  stdout.writeln('  Files needing update: $updatedFiles');
  stdout.writeln('  Mode: ${apply ? 'APPLY' : 'DRY-RUN'}');
}
