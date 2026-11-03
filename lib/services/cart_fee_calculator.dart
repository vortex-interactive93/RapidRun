// File: lib/services/cart_fee_calculator.dart

class CartHeavyCargoResult {
  final double estimatedTotalWeightLbs;
  final double surcharge;
  final bool isHeavy;
  final String? reason;

  const CartHeavyCargoResult({
    required this.estimatedTotalWeightLbs,
    required this.surcharge,
    required this.isHeavy,
    this.reason,
  });
}

class CartFeeCalculator {
  /// Known heavy SKU baseline weight mappings (lbs)
  static const Map<String, double> _knownItemWeights = {
    'case_water_40': 43.5,
    'case_water_24': 27.5,
    'case_soda_12': 10.2,
    'milk_gallon': 8.6,
    'pet_food_large': 35.0,
    'water_softener_salt': 40.0,
    'cat_litter_large': 38.0,
  };

  /// Calculates total weight and dynamic heavy surcharge
  static CartHeavyCargoResult evaluateWeight(Map<String, int> cartItems, Map<String, dynamic> productCatalog) {
    double totalWeight = 0.0;
    int heavyItemCount = 0;

    cartItems.forEach((productId, qty) {
      final p = productCatalog[productId];
      final name = (p?['name'] ?? '').toString().toLowerCase();
      final unit = (p?['unit'] ?? '').toString().toLowerCase();

      double itemWeight = 1.0; // Standard 1 lb baseline fallback

      // Rule-based weight detection
      if (name.contains('40 count') || name.contains('40 pack') || name.contains('40 ct')) {
        itemWeight = _knownItemWeights['case_water_40']!;
        heavyItemCount += qty;
      } else if (name.contains('24 count') || name.contains('24 pack') || name.contains('24 ct')) {
        itemWeight = _knownItemWeights['case_water_24']!;
        heavyItemCount += qty;
      } else if (name.contains('gallon') && (name.contains('milk') || name.contains('water'))) {
        itemWeight = _knownItemWeights['milk_gallon']!;
      } else if (name.contains('dog food') || name.contains('cat food')) {
        if (name.contains('30 lb') || name.contains('35 lb') || name.contains('40 lb')) {
          itemWeight = _knownItemWeights['pet_food_large']!;
          heavyItemCount += qty;
        }
      } else if (unit.contains('lb')) {
        final match = RegExp(r'(\d+(?:\.\d+)?)\s*lb').firstMatch(unit);
        if (match != null) {
          itemWeight = double.tryParse(match.group(1)!) ?? 1.0;
        }
      }

      totalWeight += itemWeight * qty;
    });

    if (totalWeight >= 70.0 || heavyItemCount >= 2) {
      return CartHeavyCargoResult(
        estimatedTotalWeightLbs: totalWeight,
        surcharge: 8.50,
        isHeavy: true,
        reason: 'Heavy Batch: ${totalWeight.round()} lbs (Multiple cases/bulk items)',
      );
    } else if (totalWeight >= 40.0 || heavyItemCount >= 1) {
      return CartHeavyCargoResult(
        estimatedTotalWeightLbs: totalWeight,
        surcharge: 4.50,
        isHeavy: true,
        reason: 'Heavy Order: ${totalWeight.round()} lbs',
      );
    }

    return CartHeavyCargoResult(
      estimatedTotalWeightLbs: totalWeight,
      surcharge: 0.0,
      isHeavy: false,
    );
  }
}
