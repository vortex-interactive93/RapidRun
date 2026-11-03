import 'dart:convert';
import 'dart:io';

/// Normalizes Taco Bell product JSON files by:
/// 1. Adding minCalories / maxCalories fields (derived from description calorie text or existing calories field)
/// 2. Ensuring category naming consistency (e.g., "Side and Sweets" -> "Sides & Sweets")
/// 3. Keeping existing structure otherwise intact.
///
/// Run with: dart run tool/normalize_taco_bell_products.dart
void main(List<String> args) {
  final dir = Directory('assets/stores/taco_bell');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }

  final calorieRegex = RegExp(r'(\d+)(?:-(\d+))?\s*Cal', caseSensitive: false);

  int filesProcessed = 0;
  int productsScanned = 0;
  int addedCalorieRanges = 0;
  int normalizedCategories = 0;

  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith('taco-bell-') || !name.endsWith('.json')) continue;
    // Skip meta or category mapping files if any (underscore leading or special names)
    if (name.startsWith('_')) continue;

    final raw = entity.readAsStringSync();
    List<dynamic> data;
    try {
      data = json.decode(raw) as List<dynamic>;
    } catch (_) {
      // Not an array file; skip silently.
      continue;
    }

    bool fileChanged = false;
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      productsScanned++;

      // Normalize category naming
      final category = item['category'];
      if (category == 'Side and Sweets') {
        item['category'] = 'Sides & Sweets';
        if (item['subCategory'] == 'Side and Sweets') {
          item['subCategory'] = 'Sides & Sweets';
        }
        normalizedCategories++;
        fileChanged = true;
      }

      // Skip if already has both minCalories and maxCalories
      if (item.containsKey('minCalories') && item.containsKey('maxCalories'))
        continue;

      int? minC;
      int? maxC;

      // Try description first
      final desc = item['description'];
      if (desc is String) {
        final m = calorieRegex.firstMatch(desc);
        if (m != null) {
          minC = int.tryParse(m.group(1)!);
          if (m.group(2) != null) {
            maxC = int.tryParse(m.group(2)!);
          } else {
            maxC = minC;
          }
        }
      }

      // Fallback to existing 'calories' field
      if (minC == null) {
        final cal = item['calories'];
        if (cal is int) {
          minC = cal;
          maxC = cal;
        }
      }

      if (minC != null && maxC != null) {
        // Preserve existing single calories field as lower bound (update if needed)
        item['calories'] = minC;
        item['minCalories'] = minC;
        item['maxCalories'] = maxC;
        addedCalorieRanges++;
        fileChanged = true;
      }
    }

    if (fileChanged) {
      // Write with pretty JSON for readability.
      final encoder = const JsonEncoder.withIndent('  ');
      entity.writeAsStringSync(encoder.convert(data) + '\n');
      filesProcessed++;
    }
  }

  stdout.writeln('Normalization complete');
  stdout.writeln('Files updated: $filesProcessed');
  stdout.writeln('Products scanned: $productsScanned');
  stdout.writeln('Calorie ranges added: $addedCalorieRanges');
  stdout.writeln('Categories normalized: $normalizedCategories');
}
