import 'dart:convert';
import 'dart:io';

// Simple validation script to ensure Walmart product JSON files conform to expected schema.
// Usage: dart run tooling/validate_walmart_products.dart
// Reports any missing or null critical fields.

final requiredStringFields = [
  'id',
  'name',
  'imageUrl',
  'storeId',
  'category',
  'subCategory',
];
final requiredNumericFields = ['price'];

void main() async {
  final dir = Directory('assets/stores/walmart');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => !f.path.endsWith('walmart_categories.json'))
      .toList();
  int issues = 0;
  for (final file in files) {
    late dynamic decoded;
    try {
      decoded = json.decode(await file.readAsString());
    } catch (e) {
      print('INVALID_JSON: ${file.path} -> $e');
      issues++;
      continue;
    }
    if (decoded is! List) {
      print('NOT_A_LIST: ${file.path}');
      issues++;
      continue;
    }
    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) {
        print('ITEM_NOT_OBJECT: ${file.path}[$i]');
        issues++;
        continue;
      }
      for (final f in requiredStringFields) {
        if (!item.containsKey(f) ||
            item[f] == null ||
            (item[f] is String && (item[f] as String).trim().isEmpty)) {
          print('MISSING_FIELD: ${file.path}[$i].$f');
          issues++;
        }
      }
      for (final f in requiredNumericFields) {
        final v = item[f];
        if (v == null || (v is! num)) {
          print('MISSING_NUMERIC: ${file.path}[$i].$f');
          issues++;
        }
      }
    }
  }
  if (issues == 0) {
    print('Validation passed: All Walmart product files look good.');
  } else {
    print('Validation complete: Found $issues issue(s).');
  }
}
