import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/models/nutrition.dart';

void main() {
  test(
    'parses numeric and string nutrition fields and normalizes synonyms',
    () {
      final raw = {
        'serving_size': '1 bar (40g)',
        'calories': '210',
        'fat_g': 9, // synonym
        'saturated_fat_g': '3', // synonym
        'carbs_g': 22, // synonym
        'protein_g': '12',
        'fiber_g': 5,
      };
      final info = NutritionInfo.fromDynamic(raw);
      expect(info.servingSize, '1 bar (40g)');
      expect(info.values['calories'], 210);
      expect(info.values['fat_total_g'], 9);
      expect(info.values['fat_saturated_g'], 3);
      expect(info.values['carbs_total_g'], 22);
      expect(info.values['protein_g'], 12);
      expect(info.values['fiber_g'], 5);
    },
  );
}
