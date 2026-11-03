import 'dart:convert';
import 'dart:io';

/// Repairs Taco Bell product JSON files by adding missing calorie fields
/// (calories, minCalories, maxCalories) when they can be parsed from the
/// description. Also normalizes existing entries that have calories but
/// are missing min/max (sets both equal to calories) and upgrades range
/// descriptions like (0-1120 Cal Per Item) into min/max.
///
/// Parsing logic:
/// - Looks for patterns inside parentheses ending with 'Cal' optionally
///   followed by ' Per Item' or closing parenthesis.
/// - Supports single value: (420 Cal)
/// - Supports range: (0-1120 Cal) or (0-1120 Cal Per Item)
/// - If range present and calories field missing, chooses max as calories.
/// - If calories present but min/max missing and no explicit range, sets
///   minCalories = maxCalories = calories.
///
/// Safety:
/// - Creates .bak once per modified file (if not already present)
/// - Skips non-array JSON roots.
/// - Writes pretty JSON.
Future<void> main(List<String> args) async {
  final storeDir = Directory('assets/stores/taco_bell');
  if (!storeDir.existsSync()) {
    stderr.writeln('Store directory not found.');
    exit(1);
  }

  final rangeRegex = RegExp(r'\((\d+)[\u2013\-](\d+) Cal(?:[^)]*)\)');
  final singleRegex = RegExp(r'\((\d+) Cal(?:[^)]*)\)');

  int filesScanned = 0;
  int productsScanned = 0;
  int productsUpdated = 0;
  int caloriesAdded = 0;
  int rangesAdded = 0;
  int minMaxFilled = 0;

  for (final entity in storeDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.json') || name.startsWith('_')) continue;
    filesScanned++;
    dynamic parsed;
    final original = await entity.readAsString();
    try {
      parsed = jsonDecode(original);
    } catch (_) {
      continue; // skip malformed
    }
    if (parsed is! List) continue;
    bool fileChanged = false;
    for (final item in parsed) {
      if (item is! Map<String, dynamic>) continue;
      productsScanned++;
      bool updated = false;
      String? desc = item['description']?.toString();
      num? calories = _asNum(item['calories']);
      num? minCalories = _asNum(item['minCalories']);
      num? maxCalories = _asNum(item['maxCalories']);

      if (desc != null) {
        // Prefer parsing range first.
        final rangeMatch = rangeRegex.firstMatch(desc);
        if (rangeMatch != null) {
          final low = int.parse(rangeMatch.group(1)!);
          final high = int.parse(rangeMatch.group(2)!);
          if (minCalories == null) {
            minCalories = low;
            updated = true;
          }
          if (maxCalories == null) {
            maxCalories = high;
            updated = true;
          }
          if (calories == null) {
            calories = high; // choose max as representative
            updated = true;
            caloriesAdded++;
          }
          rangesAdded++;
        } else {
          // Single value
          final singleMatch = singleRegex.firstMatch(desc);
          if (singleMatch != null) {
            final val = int.parse(singleMatch.group(1)!);
            if (calories == null) {
              calories = val;
              updated = true;
              caloriesAdded++;
            }
            if (minCalories == null) {
              minCalories = val;
              updated = true;
              minMaxFilled++;
            }
            if (maxCalories == null) {
              maxCalories = val;
              updated = true;
            }
          }
        }
      }

      // If still have calories but missing min/max, fill them.
      if (calories != null) {
        if (minCalories == null) {
          minCalories = calories;
          updated = true;
          minMaxFilled++;
        }
        if (maxCalories == null) {
          maxCalories = calories;
          updated = true;
        }
      }

      if (updated) {
        item['calories'] = calories;
        if (minCalories != null) item['minCalories'] = minCalories;
        if (maxCalories != null) item['maxCalories'] = maxCalories;
        productsUpdated++;
        fileChanged = true;
      }
    }
    if (fileChanged) {
      final bak = File(entity.path + '.bak');
      if (!bak.existsSync()) await bak.writeAsString(original);
      final encoder = const JsonEncoder.withIndent('  ');
      await entity.writeAsString(encoder.convert(parsed) + '\n');
    }
  }

  final summary = {
    'filesScanned': filesScanned,
    'productsScanned': productsScanned,
    'productsUpdated': productsUpdated,
    'caloriesAdded': caloriesAdded,
    'rangeEntriesParsed': rangesAdded,
    'minMaxFilled': minMaxFilled,
  };
  final out = File('tool/_calorie_fix_report.json');
  final encoder = const JsonEncoder.withIndent('  ');
  await out.writeAsString(encoder.convert(summary));
  stdout.writeln('Calorie fix complete. Report: ${out.path}');
  stdout.writeln(encoder.convert(summary));
}

num? _asNum(dynamic v) {
  if (v is int) return v.toDouble();
  if (v is double) return v;
  if (v is String) return num.tryParse(v);
  return null;
}
