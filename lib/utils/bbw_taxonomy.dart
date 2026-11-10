// File: lib/utils/bbw_taxonomy.dart

import '../models/product.dart';

/// Master Canonical Departments for Bath & Body Works
enum BbwDepartment {
  candles('Candles', ['candle', 'candles']),
  wallflowers('Wallflowers & Diffusers', ['wallflower', 'wallflowers', 'diffuser', 'diffusers', 'plug']),
  bodyCare('Body Care', ['body care', 'body', 'skincare', 'shower', 'moisturizer']),
  fragrance('Fragrance', ['fragrance', 'perfume', 'cologne', 'mist']),
  handSoaps('Hand Soaps & Sanitizers', ['soap', 'soaps', 'sanitizer', 'sanitizers', 'pocketbac']),
  mensShop("The Men's Shop", ["men's", 'mens', 'men']),
  homeCare('Home Care', ['home care', 'laundry', 'detergent', 'cleaning']);

  final String label;
  final List<String> matchKeywords;
  const BbwDepartment(this.label, this.matchKeywords);

  static BbwDepartment? fromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.toLowerCase().trim();
    for (final dept in BbwDepartment.values) {
      if (dept.label.toLowerCase() == clean) return dept;
      if (dept.matchKeywords.any((kw) => clean == kw || clean.contains(kw))) {
        return dept;
      }
    }
    return null;
  }
}

/// Canonical Subcategory Filter Specification
class BbwSubcategorySpec {
  final String label;
  final List<String> positivePatterns;
  final List<String> negativePatterns;

  const BbwSubcategorySpec({
    required this.label,
    required this.positivePatterns,
    this.negativePatterns = const [],
  });

  bool matches(Product product) {
    final target = '${product.name} ${product.productType ?? ''} ${product.unit ?? ''} ${product.productUrl ?? ''}'.toLowerCase();

    // Check negatives first (immediate rejection)
    for (final neg in negativePatterns) {
      if (_hasWordOrPhrase(target, neg)) return false;
    }

    // Check positive matches
    for (final pos in positivePatterns) {
      if (_hasWordOrPhrase(target, pos)) return true;
    }
    return false;
  }

  static bool _hasWordOrPhrase(String text, String phrase) {
    if (phrase.contains(' ') || phrase.contains('-')) {
      return text.contains(phrase.toLowerCase());
    }
    return RegExp(r'\b' + RegExp.escape(phrase.toLowerCase()) + r'\b').hasMatch(text);
  }
}

/// The Master Registry: Maps every Department to its exact subcategory specs.
class BbwTaxonomy {
  static final Map<BbwDepartment, List<BbwSubcategorySpec>> registry = {
    // -------------------------------------------------------------------------
    // 1. CANDLES
    // -------------------------------------------------------------------------
    BbwDepartment.candles: const [
      BbwSubcategorySpec(
        label: '3-Wick Candles',
        positivePatterns: ['3-wick', '3 wick'],
        negativePatterns: ['single wick', 'holder', 'pedestal'],
      ),
      BbwSubcategorySpec(
        label: 'Single Wick Candles',
        positivePatterns: ['single wick', 'single-wick'],
        negativePatterns: ['3-wick', 'holder'],
      ),
      BbwSubcategorySpec(
        label: '4-Wick Candles',
        positivePatterns: ['4-wick', '4 wick'],
      ),
      BbwSubcategorySpec(
        label: 'Holders & Accessories',
        positivePatterns: ['holder', 'pedestal', 'sleeve', 'lid'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 2. WALLFLOWERS & DIFFUSERS
    // -------------------------------------------------------------------------
    BbwDepartment.wallflowers: const [
      BbwSubcategorySpec(
        label: 'Wallflowers Refills',
        positivePatterns: ['wallflowers fragrance refill', 'wallflower refill', 'fragrance refill'],
        negativePatterns: ['car fragrance', 'hand soap refill', 'plug'],
      ),
      BbwSubcategorySpec(
        label: 'Plugs & Nightlights',
        positivePatterns: ['plug', 'nightlight', 'scent control', 'duo plug'],
        negativePatterns: ['refill', 'candle'],
      ),
      BbwSubcategorySpec(
        label: 'Room Sprays & Mists',
        positivePatterns: ['concentrated room spray', 'room spray', 'room mist'],
        negativePatterns: ['fine fragrance mist', 'body spray', 'essential oil mist'],
      ),
      BbwSubcategorySpec(
        label: 'Car Fragrance',
        positivePatterns: ['car fragrance', 'car fragrance refill', 'car fragrance holder'],
        negativePatterns: ['wallflower', 'candle'],
      ),
      BbwSubcategorySpec(
        label: 'Liquidless Reeds',
        positivePatterns: ['liquidless reeds', 'reed vessel', 'reeds', 'hanging fragrance diffuser'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 3. BODY CARE
    // -------------------------------------------------------------------------
    BbwDepartment.bodyCare: const [
      BbwSubcategorySpec(
        label: 'Body Wash & Shower',
        positivePatterns: ['body wash', 'shower gel', 'cleansing bar', 'bar soap', 'shower steamers', 'foam bath'],
        negativePatterns: ['hand soap', 'car fragrance'],
      ),
      BbwSubcategorySpec(
        label: 'Body Cream & Lotion',
        positivePatterns: ['body cream', 'body lotion', 'body butter', 'glowtion'],
        negativePatterns: ['hand cream', 'lip'],
      ),
      BbwSubcategorySpec(
        label: 'Body Scrubs',
        positivePatterns: ['body scrub', 'sugar scrub', 'glow body scrub', 'creamy body scrub'],
      ),
      BbwSubcategorySpec(
        label: 'Hand Creams',
        positivePatterns: ['hand cream'],
        negativePatterns: ['body lotion', 'body cream'],
      ),
      BbwSubcategorySpec(
        label: 'Lip Care',
        positivePatterns: ['lip gloss', 'lip balm', 'lip oil', 'lip mask', 'lip tint', 'peptide lip'],
      ),
      BbwSubcategorySpec(
        label: 'Fine Fragrance Mists',
        positivePatterns: ['fine fragrance mist', 'shimmer mist', 'body mist'],
        negativePatterns: ['room spray', 'cologne'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 4. FRAGRANCE (PERFUMES & COLOGNES)
    // -------------------------------------------------------------------------
    BbwDepartment.fragrance: const [
      BbwSubcategorySpec(
        label: 'Fine Fragrance Mists',
        positivePatterns: ['fine fragrance mist', 'diamond shimmer mist', 'perfume mist'],
        negativePatterns: ['room spray', 'cologne'],
      ),
      BbwSubcategorySpec(
        label: 'Eau de Parfum',
        positivePatterns: ['eau de parfum', 'mini eau de parfum', 'solid perfume', 'rollerball'],
        negativePatterns: ['mist', 'wash'],
      ),
      BbwSubcategorySpec(
        label: 'Cologne',
        positivePatterns: ['cologne', 'cologne mist', 'mini cologne'],
      ),
      BbwSubcategorySpec(
        label: 'Aromatherapy Mists',
        positivePatterns: ['essential oil mist'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 5. HAND SOAPS & SANITIZERS
    // -------------------------------------------------------------------------
    BbwDepartment.handSoaps: const [
      BbwSubcategorySpec(
        label: 'Foaming Hand Soaps',
        positivePatterns: ['foaming hand soap', 'gentle & clean foaming'],
        negativePatterns: ['refill', 'gel hand soap'],
      ),
      BbwSubcategorySpec(
        label: 'Gel & Moisturizing Soaps',
        positivePatterns: ['cleansing gel hand soap', 'daily moisturizing hand soap', 'revitalizing hand soap'],
        negativePatterns: ['foaming', 'refill'],
      ),
      BbwSubcategorySpec(
        label: 'Soap Refills',
        positivePatterns: ['foaming refill', 'hand soap refill', '32 fl oz'],
      ),
      BbwSubcategorySpec(
        label: 'PocketBacs (Sanitizers)',
        positivePatterns: ['pocketbac', 'hand sanitizer', 'pocketspray', 'sanitizer spray'],
        negativePatterns: ['holder'],
      ),
      BbwSubcategorySpec(
        label: 'Sanitizer Holders',
        positivePatterns: ['pocketbac holder', 'spray holder', 'soap holder', 'wristlet'],
        negativePatterns: ['refill', 'soap'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 6. THE MEN'S SHOP
    // -------------------------------------------------------------------------
    BbwDepartment.mensShop: const [
      BbwSubcategorySpec(
        label: '3-in-1 Hair & Body Wash',
        positivePatterns: ['3-in-1', 'hair, face & body wash', 'bar soap'],
      ),
      BbwSubcategorySpec(
        label: 'Body Spray & Deodorant',
        positivePatterns: ['deodorizing body spray', 'antiperspirant deodorant'],
      ),
      BbwSubcategorySpec(
        label: 'Men\'s Cologne',
        positivePatterns: ['cologne', 'mini cologne'],
      ),
      BbwSubcategorySpec(
        label: 'Body Cream & Beard Care',
        positivePatterns: ['hydration body cream', 'body cream', 'body lotion'],
      ),
    ],

    // -------------------------------------------------------------------------
    // 7. HOME CARE & LAUNDRY
    // -------------------------------------------------------------------------
    BbwDepartment.homeCare: const [
      BbwSubcategorySpec(
        label: 'Laundry Detergent',
        positivePatterns: ['laundry detergent', 'detergent'],
      ),
      BbwSubcategorySpec(
        label: 'Fragrance Boosters',
        positivePatterns: ['fragrance booster', 'scent booster'],
      ),
    ],
  };

  /// Returns canonical filter chips for any department string
  static List<String> getChipsForDepartment(String rawDepartment) {
    final dept = BbwDepartment.fromString(rawDepartment);
    if (dept == null) return const ['All'];

    final specs = registry[dept] ?? [];
    return ['All', ...specs.map((s) => s.label)];
  }

  /// Classifies a raw product into a department and tag list
  static List<String> classifyProduct(Map<String, dynamic> json) {
    final tags = <String>{'All'};
    final name = (json['name'] ?? '').toString();
    final deptRaw = (json['department'] ?? json['category'] ?? '').toString();
    final resolvedDept = BbwDepartment.fromString(deptRaw);

    final mockProduct = Product(
      id: json['id']?.toString() ?? '',
      name: name,
      productType: json['productType']?.toString(),
      productUrl: json['productUrl']?.toString(),
      unit: json['unit']?.toString(),
      price: 0.0,
    );

    if (resolvedDept != null && registry.containsKey(resolvedDept)) {
      tags.add(resolvedDept.label);
      for (final spec in registry[resolvedDept]!) {
        if (spec.matches(mockProduct)) {
          tags.add(spec.label);
        }
      }
    }

    for (final entry in registry.entries) {
      for (final spec in entry.value) {
        if (spec.matches(mockProduct)) {
          tags.add(spec.label);
          tags.add(entry.key.label);
        }
      }
    }

    return tags.toList();
  }
}
