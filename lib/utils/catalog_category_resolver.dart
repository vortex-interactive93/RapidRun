// File: lib/utils/catalog_category_resolver.dart

class CatalogCategoryResolver {
  /// Resolves the primary Tier 1 department for any SKU
  static String resolvePrimaryDepartment(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().toLowerCase();
    final type = (item['productType'] ?? item['category'] ?? '').toString().toLowerCase();
    final dept = (item['department'] ?? '').toString().toLowerCase();

    if (dept.contains('men') || type.contains('men') || name.contains("men's")) {
      return "The Men's Shop";
    }
    if (type.contains('laundry') || name.contains('laundry') || type.contains('booster')) {
      return "Home Care";
    }
    if (name.contains('candle') || type.contains('candle') || (name.contains('pedestal') && !name.contains('soap'))) {
      return "Candles";
    }
    if (name.contains('soap') || name.contains('pocketbac') || name.contains('sanitizer')) {
      return "Hand Soaps & Sanitizers";
    }
    if (name.contains('wallflower') || name.contains('room spray') || name.contains('car fragrance')) {
      return "Wallflowers & Diffusers";
    }
    if (type.contains('eau de parfum') || type.contains('cologne') || name.contains('fine fragrance mist') || name.contains('perfume mist')) {
      return "All Fragrances";
    }
    return "Body Care";
  }

  /// Returns the matching subcategory filter tags for an item
  static List<String> resolveSubcategoryTags(Map<String, dynamic> item) {
    final tags = <String>{'All'};
    final name = (item['name'] ?? '').toString().toLowerCase();
    final type = (item['productType'] ?? '').toString().toLowerCase();
    final unit = (item['unitShort'] ?? item['unit'] ?? '').toString().toLowerCase();

    // Candles
    if (name.contains('3-wick') || type.contains('3-wick')) tags.add('3-Wick');
    if (name.contains('single wick') || type.contains('single wick')) tags.add('Single Wick');
    if (name.contains('4-wick') || type.contains('4-wick')) tags.add('4-Wick');
    if (name.contains('holder') || name.contains('pedestal')) tags.add('Holders & Pedestals');

    // Body Care
    if (name.contains('body cream') || name.contains('body lotion') || name.contains('body butter')) {
      tags.add('Moisturizers');
    }
    if (name.contains('body wash') || name.contains('shower soap') || name.contains('foam bath')) {
      tags.add('Body Wash');
    }
    if (name.contains('scrub')) tags.add('Body Scrubs');
    if (name.contains('lip')) tags.add('Lip Care');

    // Travel Size (under 3.5 oz or named travel)
    if (name.contains('travel') || name.contains('mini') || unit.contains('1 oz') || unit.contains('2.5 oz') || unit.contains('0.23 oz')) {
      tags.add('Travel Size');
    }

    // Fragrance
    if (name.contains('fine fragrance mist') || name.contains('perfume mist')) tags.add('Fine Fragrance Mist');
    if (name.contains('eau de parfum')) tags.add('Eau de Parfum');
    if (name.contains('cologne')) tags.add('Cologne');
    if (name.contains('body spray')) tags.add('Body Sprays');

    // Hand Soaps & Sanitizers
    if (name.contains('foaming hand soap')) tags.add('Foaming Soaps');
    if (name.contains('pocketbac')) tags.add('PocketBac Sanitizers');
    if (name.contains('sanitizer spray') || name.contains('pocketspray')) tags.add('Sanitizer Sprays');
    if (name.contains('refill')) tags.add('Soap Refills');

    // Wallflowers
    if (name.contains('wallflowers fragrance refill')) tags.add('Wallflowers Refills');
    if (name.contains('wallflowers fragrance plug') || name.contains('nightlight')) tags.add('Plugs & Nightlights');
    if (name.contains('room spray') || name.contains('room mist')) tags.add('Room Sprays');
    if (name.contains('car fragrance')) tags.add('Car Fragrance');

    return tags.toList();
  }
}
