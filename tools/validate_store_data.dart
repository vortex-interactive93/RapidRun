import 'dart:convert';
import 'dart:io';

// Canonical nutrition keys used throughout the app.
const canonicalNutritionKeys = <String>{
  'calories',
  'fat_total_g',
  'fat_saturated_g',
  'trans_fat_g',
  'cholesterol_mg',
  'sodium_mg',
  'carbs_total_g',
  'fiber_g',
  'sugar_g',
  'added_sugar_g',
  'protein_g',
  'serving_size',
};

// Synonym mapping allowed on input; will warn and suggest canonical key.
const nutritionSynonyms = <String, String>{
  'fat_g': 'fat_total_g',
  'saturated_fat_g': 'fat_saturated_g',
  'carbs_g': 'carbs_total_g',
};

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart validate_store_data.dart <store_name>');
    exit(1);
  }

  final storeName = args[0];
  final root = Directory('assets/stores/$storeName');
  final categoriesFile = File('${root.path}/${storeName}_categories.json');

  if (!categoriesFile.existsSync()) {
    print('ERROR: Categories file not found: ${categoriesFile.path}');
    exit(1);
  }

  final categories = json.decode(categoriesFile.readAsStringSync()) as List;
  final validCategories = <String>{};
  final validSections = <String, Set<String>>{};

  // Collect valid categories and sections
  for (final cat in categories) {
    final categoryName = cat['categoryName'] as String?;
    if (categoryName == null) continue;
    validCategories.add(categoryName);

    for (final section in (cat['sections'] as List? ?? [])) {
      final sectionName = section['sectionName'] as String?;
      if (sectionName == null) continue;

      validSections
          .putIfAbsent(categoryName, () => <String>{})
          .add(sectionName);
    }
  }

  // Validate product files
  for (final cat in categories) {
    for (final section in (cat['sections'] as List? ?? [])) {
      for (final pt in (section['productTypes'] as List? ?? [])) {
        final filePath = pt['filePath'] as String?;
        if (filePath == null) continue;

        final productFile = File(filePath);
        if (!productFile.existsSync()) {
          print('MISSING FILE: $filePath');
          continue;
        }

        try {
          final products = json.decode(productFile.readAsStringSync()) as List;
          for (final product in products) {
            final category = product['category'] as String?;
            final subCategory = product['subCategory'] as String?;
            final nutrition = product['nutrition'];

            if (category == null || !validCategories.contains(category)) {
              print(
                'INVALID CATEGORY: Product in $filePath references unknown category "$category"',
              );
            }

            if (subCategory == null ||
                !(validSections[category]?.contains(subCategory) ?? false)) {
              print(
                'INVALID SUBCATEGORY: Product in $filePath references unknown subCategory "$subCategory"',
              );
            }

            // Nutrition validation (optional fields but structured if present)
            if (nutrition != null && nutrition is! Map) {
              print(
                'INVALID NUTRITION FORMAT in $filePath product ${product['id']}',
              );
            } else if (nutrition is Map) {
              final keys = nutrition.keys.cast<String>().toSet();
              // Warn about unknown keys
              for (final k in keys) {
                if (!canonicalNutritionKeys.contains(k) &&
                    !nutritionSynonyms.containsKey(k)) {
                  print(
                    'UNKNOWN NUTRITION KEY "$k" in $filePath product ${product['id']}',
                  );
                }
              }
              // Suggest synonym normalization
              for (final entry in nutritionSynonyms.entries) {
                if (keys.contains(entry.key)) {
                  print(
                    'NUTRITION SYNONYM ${entry.key} -> ${entry.value} in $filePath product ${product['id']}',
                  );
                }
              }
              // Missing core keys (non-fatal)
              const core = [
                'calories',
                'fat_total_g',
                'carbs_total_g',
                'protein_g',
              ];
              final missing = core.where((c) => !keys.contains(c)).toList();
              if (missing.isNotEmpty) {
                print(
                  'MISSING CORE NUTRITION KEYS ${missing.join(', ')} in $filePath product ${product['id']}',
                );
              }
              // Value checks
              for (final key in keys) {
                if (key == 'serving_size') continue;
                final val = nutrition[key];
                num? numeric;
                if (val is num) {
                  numeric = val;
                } else if (val is String) {
                  numeric = num.tryParse(val);
                }
                if (numeric == null) {
                  print(
                    'NON-NUMERIC NUTRITION VALUE "$key" ($val) in $filePath product ${product['id']}',
                  );
                  continue;
                }
                if (numeric < 0) {
                  print(
                    'NEGATIVE NUTRITION VALUE "$key" = $numeric in $filePath product ${product['id']}',
                  );
                }
                // Simple heuristic bounds (per serving):
                if ({'calories'}.contains(key) && numeric > 1500) {
                  print(
                    'IMPROBABLE CALORIES $numeric in $filePath product ${product['id']}',
                  );
                } else if (key.endsWith('_g') && numeric > 150) {
                  print(
                    'IMPROBABLE GRAM VALUE $key=$numeric in $filePath product ${product['id']}',
                  );
                } else if (key.endsWith('_mg') && numeric > 5000) {
                  print(
                    'IMPROBABLE MG VALUE $key=$numeric in $filePath product ${product['id']}',
                  );
                }
              }
            }
          }
        } catch (e) {
          print('INVALID JSON: $filePath - ${e.toString()}');
        }
      }
    }
  }

  print('Validation complete.');
}
