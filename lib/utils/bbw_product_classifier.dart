// File: lib/utils/bbw_product_classifier.dart

class BbwProductClassifier {
  /// Evaluates an ingested JSON item across Name, URL, Category, and Unit
  /// to assign deterministic, verified subcategory tags.
  static List<String> classifyProduct(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().toLowerCase();
    final url = (json['productUrl'] ?? '').toString().toLowerCase();
    final unit = (json['unitShort'] ?? json['unit'] ?? '').toString().toLowerCase();
    final dept = (json['department'] ?? json['category'] ?? '').toString().toLowerCase();

    final tags = <String>{'All'};

    // =========================================================================
    // 1. CANDLES (candles.json)
    // =========================================================================
    if (dept.contains('candle') || name.contains('candle') || url.contains('-candle-')) {
      if (name.contains('3-wick') || url.contains('-3-wick-')) {
        tags.add('3-Wick Candles');
        tags.add('3-Wick');
      }
      if (name.contains('single wick') || url.contains('-single-wick-')) {
        tags.add('Single Wick Candles');
        tags.add('Single Wick');
      }
      if (name.contains('4-wick') || url.contains('-4-wick-')) {
        tags.add('4-Wick Candles');
        tags.add('4-Wick');
      }
      if (name.contains('holder') ||
          name.contains('pedestal') ||
          name.contains('accessory') ||
          url.contains('-holder-')) {
        tags.add('Candle Holders & Accessories');
        tags.add('Holders & Accessories');
      }
    }

    // =========================================================================
    // 2. WALLFLOWERS & HOME FRAGRANCE (wallflowers_diffusers.json)
    // =========================================================================
    if (dept.contains('wallflower') ||
        dept.contains('diffuser') ||
        name.contains('wallflower') ||
        name.contains('room spray') ||
        name.contains('car fragrance')) {
      if (name.contains('wallflowers fragrance refill') ||
          url.contains('-wallflowers-fragrance-refill-') ||
          (name.contains('wallflowers') && name.contains('refill'))) {
        tags.add('Wallflowers Refills');
        tags.add('Wallflowers Fragrance Refills');
      }
      if (name.contains('wallflowers fragrance plug') ||
          name.contains('nightlight') ||
          name.contains('duo plug') ||
          url.contains('-fragrance-plug-')) {
        tags.add('Plugs & Nightlights');
        tags.add('Wallflowers Plugs');
      }
      if (name.contains('car fragrance') ||
          name.contains('car fragrance holder') ||
          url.contains('-car-fragrance-')) {
        tags.add('Car Fragrance');
        tags.add('Car Fragrance & Fresheners');
      }
      if (name.contains('concentrated room spray') ||
          name.contains('room mist') ||
          url.contains('-room-spray-') ||
          url.contains('-room-mist-')) {
        tags.add('Room Sprays & Mists');
        tags.add('Room Sprays');
      }
      if (name.contains('reeds') ||
          name.contains('reed vessel') ||
          url.contains('-reeds-') ||
          url.contains('-reed-vessel-')) {
        tags.add('Liquidless Reeds');
      }
    }

    // =========================================================================
    // 3. HAND SOAPS & SANITIZERS (hand_soaps_sanitizers.json)
    // =========================================================================
    if (dept.contains('soap') ||
        dept.contains('sanitizer') ||
        name.contains('soap') ||
        name.contains('pocketbac') ||
        name.contains('sanitizer')) {
      // Foaming Soaps (excludes refills)
      if (name.contains('foaming hand soap') && !name.contains('refill')) {
        tags.add('Foaming Soaps');
      }

      // Gel & Moisturizing Hand Soaps
      if ((name.contains('cleansing gel hand soap') ||
              name.contains('daily moisturizing hand soap') ||
              name.contains('revitalizing hand soap') ||
              name.contains('gel hand soap')) &&
          !name.contains('refill')) {
        tags.add('Gel & Moisturizing Soaps');
      }

      // PocketBac Hand Sanitizers (Gel bottles, excludes holders)
      if (name.contains('pocketbac') &&
          !name.contains('holder') &&
          !name.contains('clip')) {
        tags.add('PocketBac Sanitizers');
        tags.add('PocketBacs');
        tags.add('PocketBac Hand Sanitizers');
      }

      // Hand Sanitizer Sprays, PocketSprays & Tabletop Pumps
      if (name.contains('sanitizer spray') ||
          name.contains('pocketspray') ||
          name.contains('sanitizer with pump') ||
          url.contains('-hand-sanitizer-spray-') ||
          url.contains('-pocketspray-')) {
        tags.add('Sanitizer Sprays');
        tags.add('Hand Sanitizer Sprays');
      }

      // Soap Holders & Sanitizer Clip Accessories
      if (name.contains('pocketbac holder') ||
          name.contains('soap holder') ||
          name.contains('spray holder') ||
          name.contains('pocketspray holder') ||
          name.contains('wristlet') ||
          name.contains('lanyard') ||
          name.contains('snapcase')) {
        tags.add('Holders & Clips');
        tags.add('Soap Holders & Dispensers');
        tags.add('Hand Sanitizer Holders');
      }

      // Bulk Refill Cartons
      if (name.contains('refill') &&
          (name.contains('soap') || name.contains('foaming'))) {
        tags.add('Soap Refills');
        tags.add('Hand Soap Refills');
      }
    }

    // =========================================================================
    // 4. THE MEN'S SHOP (men_s_shop.json)
    // =========================================================================
    if (dept.contains('men') || url.contains('/mens-shop')) {
      if (name.contains('3-in-1') ||
          name.contains('bar soap') ||
          name.contains('cleansing bar')) {
        tags.add('3-in-1 Wash & Bar Soap');
      }
      if (name.contains('body spray') ||
          name.contains('deodorant') ||
          name.contains('antiperspirant')) {
        tags.add('Body Spray & Deodorant');
      }
      if (name.contains('cologne') ||
          name.contains('elixir') ||
          url.contains('-cologne-')) {
        tags.add('Cologne');
        tags.add('Colognes');
      }
      if (name.contains('body cream') ||
          name.contains('body lotion') ||
          name.contains('lotion')) {
        tags.add('Body Cream & Lotion');
        tags.add('Body Creams');
      }
      // Cross-over home/car/candle items found in the men's catalog
      if (name.contains('candle') ||
          name.contains('wallflower') ||
          name.contains('car fragrance') ||
          name.contains('room spray') ||
          name.contains('detergent')) {
        tags.add('Car & Home Fragrance');
      }
      if (name.contains('gift set') || url.contains('-gift-set-')) {
        tags.add("Men's Gift Sets");
      }
    }

    // =========================================================================
    // 5. HOME CARE (home_care.json)
    // =========================================================================
    if (dept.contains('home care') ||
        name.contains('laundry') ||
        name.contains('detergent') ||
        name.contains('booster')) {
      if (name.contains('laundry detergent') || url.contains('-laundry-detergent-')) {
        tags.add('Laundry Detergent');
      }
      if (name.contains('fragrance booster') || url.contains('-fragrance-booster-')) {
        tags.add('Fragrance Boosters');
      }
      if (name.contains('hand soap') ||
          name.contains('room spray') ||
          name.contains('single wick')) {
        tags.add('Soaps & Room Accents');
        tags.add('Room Sprays');
      }
    }

    // =========================================================================
    // 6. BODY CARE (body_care.json)
    // =========================================================================
    if (dept.contains('body care') && !dept.contains('men')) {
      if (name.contains('body wash') ||
          name.contains('shower soap') ||
          name.contains('foam bath') ||
          name.contains('cleansing bar') ||
          name.contains('shower steamers')) {
        tags.add('Bath & Shower');
        tags.add('Body Wash');
        tags.add('Body Wash & Shower Gel');
      }
      if (name.contains('body cream') ||
          name.contains('body lotion') ||
          name.contains('body butter') ||
          name.contains('hand cream') ||
          name.contains('glowtion') ||
          name.contains('massage oil')) {
        tags.add('Body Moisturizers');
        tags.add('Moisturizers');
        if (name.contains('butter') || name.contains('balm')) tags.add('Body Butter & Balm');
        if (name.contains('cream') && !name.contains('hand')) tags.add('Body Cream');
        if (name.contains('lotion')) tags.add('Body Lotion');
        if (name.contains('oil')) tags.add('Body Oil');
        if (name.contains('hand')) tags.add('Hand Cream');
      }
      if (name.contains('scrub')) {
        tags.add('Body Scrubs');
        tags.add('Body Butter & Scrubs');
      }
      if (name.contains('lip') ||
          name.contains('balm') ||
          name.contains('gloss') ||
          name.contains('tint')) {
        tags.add('Lip Care');
        tags.add('Lip Gloss');
      }
      if (name.contains('fine fragrance mist') || name.contains('perfume mist')) {
        tags.add('Fine Fragrance Mist');
        tags.add('Body Spray & Mist');
      }
    }

    // =========================================================================
    // 7. ALL FRAGRANCE (all_fragrance.json)
    // =========================================================================
    if (dept.contains('fragrance') && !dept.contains('home')) {
      if (name.contains('fine fragrance mist')) {
        tags.add('Fine Fragrance Mist');
        tags.add('Body Spray & Mist');
      }
      if (name.contains('eau de parfum') ||
          name.contains('perfume mist') ||
          name.contains('solid perfume') ||
          name.contains('shimmer mist')) {
        tags.add('Eau de Parfum & Perfume');
        tags.add('Eau de Parfum');
        if (name.contains('shimmer')) tags.add('Diamond Shimmer Mist');
        if (name.contains('solid')) tags.add('Solid Perfume');
      }
      if (name.contains('cologne')) {
        tags.add('Cologne');
        tags.add('Colognes');
      }
      if (name.contains('body spray') || name.contains('deodorant')) {
        tags.add('Body Sprays & Deodorant');
        tags.add('Body Spray & Mist');
        tags.add('Body Sprays');
      }
    }

    // =========================================================================
    // 8. GLOBAL TRAVEL & MINI SIZES (Cross-Cutting Across All Files)
    // =========================================================================
    if (name.contains('travel size') ||
        name.contains('mini') ||
        url.contains('-travel-size-') ||
        url.contains('-mini-') ||
        _isTravelVolume(unit)) {
      tags.add('Travel Size');
      tags.add('Travel & Rollerballs');
      tags.add('Mini & Travel Size');
    }

    return tags.toList();
  }

  static bool _isTravelVolume(String unit) {
    return unit.contains('1 oz') ||
        unit.contains('2.5 oz') ||
        unit.contains('3 oz') ||
        unit.contains('0.23 oz') ||
        unit.contains('0.25 oz') ||
        unit.contains('0.14 oz') ||
        unit.contains('0.47 oz') ||
        unit.contains('0.5 oz') ||
        unit.contains('75 ml') ||
        unit.contains('88 ml') ||
        unit.contains('7 ml');
  }
}
