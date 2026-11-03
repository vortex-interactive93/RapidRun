class NutritionInfo {
  final Map<String, num> values; // canonical key -> numeric value
  final String? servingSize;

  NutritionInfo({required this.values, this.servingSize});

  /// Canonical order & keys used in UI (corresponding to typical US label)
  static const canonicalOrder = [
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
  ];

  static const labels = {
    'calories': 'Calories',
    'fat_total_g': 'Fat (g)',
    'fat_saturated_g': 'Sat Fat (g)',
    'trans_fat_g': 'Trans Fat (g)',
    'cholesterol_mg': 'Cholesterol (mg)',
    'sodium_mg': 'Sodium (mg)',
    'carbs_total_g': 'Carbs (g)',
    'fiber_g': 'Fiber (g)',
    'sugar_g': 'Sugar (g)',
    'added_sugar_g': 'Added Sugar (g)',
    'protein_g': 'Protein (g)',
  };

  /// Input synonyms mapping -> canonical key
  static const Map<String, String> _synonyms = {
    'fat_g': 'fat_total_g',
    'saturated_fat_g': 'fat_saturated_g',
    'carbs_g': 'carbs_total_g',
  };

  factory NutritionInfo.fromDynamic(dynamic raw) {
    if (raw is! Map) return NutritionInfo(values: {});
    final map = raw.cast<String, dynamic>();
    final serving = map['serving_size']?.toString();
    final values = <String, num>{};
    map.forEach((origKey, v) {
      if (origKey == 'serving_size') return;
      final k = _synonyms[origKey] ?? origKey; // normalize
      if (v is num) {
        values[k] = v;
      } else if (v is String) {
        final parsed = num.tryParse(v.trim());
        if (parsed != null) values[k] = parsed;
      }
    });
    return NutritionInfo(values: values, servingSize: serving);
  }
}
