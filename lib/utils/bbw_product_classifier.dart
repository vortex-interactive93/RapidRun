// File: lib/utils/bbw_product_classifier.dart

class BbwProductClassifier {
  /// Analyzes name, productUrl slug, unit, and department to assign canonical filter tags
  static List<String> classifyProduct(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().toLowerCase();
    final url = (json['productUrl'] ?? '').toString().toLowerCase();
    final unit = (json['unitShort'] ?? json['unit'] ?? '').toString().toLowerCase();
    final dept = (json['department'] ?? json['category'] ?? '').toString().toLowerCase();

    final tags = <String>{'All'};

    // 1. LIP CARE CLASSIFICATION (Body Care subcategory)
    if (name.contains('lip') ||
        url.contains('-lip-') ||
        name.contains('balm') ||
        name.contains('lip gloss') ||
        name.contains('lip oil') ||
        name.contains('lip mask') ||
        name.contains('lip tint') ||
        name.contains('peptide lip')) {
      tags.add('Lip Care');
    }

    // 2. BATH & SHOWER (Body Care subcategory)
    if (name.contains('body wash') ||
        name.contains('shower soap') ||
        name.contains('foam bath') ||
        name.contains('shower gel') ||
        name.contains('cleansing bar') ||
        (name.contains('bar soap') && !dept.contains('men')) ||
        name.contains('shower steamers') ||
        url.contains('-body-wash-') ||
        url.contains('-shower-soap-')) {
      tags.add('Bath & Shower');
      tags.add('Body Wash');
    }

    // 3. BODY MOISTURIZERS (Body Care subcategory)
    if (name.contains('body cream') ||
        name.contains('body lotion') ||
        name.contains('body butter') ||
        name.contains('hand cream') ||
        name.contains('massage oil') ||
        name.contains('glowtion') ||
        url.contains('-body-cream-') ||
        url.contains('-body-lotion-') ||
        url.contains('-body-butter-') ||
        url.contains('-hand-cream-')) {
      tags.add('Body Moisturizers');
      tags.add('Moisturizers');
      if (name.contains('butter') || name.contains('balm')) tags.add('Body Butter & Balm');
      if (name.contains('cream') && !name.contains('hand')) tags.add('Body Cream');
      if (name.contains('lotion')) tags.add('Body Lotion');
      if (name.contains('oil')) tags.add('Body Oil');
      if (name.contains('hand')) tags.add('Hand Cream');
    }

    // 4. BODY SCRUBS (Body Care subcategory)
    if (name.contains('scrub') || url.contains('-body-scrub-')) {
      tags.add('Body Scrubs');
      tags.add('Body Butter & Scrubs');
    }

    // 5. FRAGRANCE & MISTS (Fragrance / Body Care)
    if (name.contains('fine fragrance mist') || url.contains('-fine-fragrance-mist-')) {
      tags.add('Fine Fragrance Mist');
      tags.add('Body Spray & Mist');
    }
    if (name.contains('eau de parfum') ||
        name.contains('perfume mist') ||
        name.contains('solid perfume') ||
        url.contains('-eau-de-parfum-') ||
        url.contains('-perfume-mist-')) {
      tags.add('Eau de Parfum & Perfume');
      tags.add('Eau de Parfum');
    }
    if (name.contains('cologne') || url.contains('-cologne-')) {
      tags.add('Cologne');
    }
    if (name.contains('body spray') || name.contains('deodorant') || name.contains('antiperspirant')) {
      tags.add('Body Sprays & Deodorant');
      tags.add('Body Spray & Mist');
    }

    // 6. TRAVEL & MINIS (Cross-cutting)
    if (name.contains('travel size') ||
        name.contains('mini') ||
        url.contains('-travel-size-') ||
        url.contains('-mini-') ||
        unit.contains('1 oz') ||
        unit.contains('2.5 oz') ||
        unit.contains('3 oz') ||
        unit.contains('0.23 oz') ||
        unit.contains('0.25 oz') ||
        unit.contains('0.14 oz') ||
        unit.contains('0.47 oz') ||
        unit.contains('0.5 oz') ||
        unit.contains('75 ml') ||
        unit.contains('88 ml') ||
        unit.contains('7 ml')) {
      tags.add('Travel Size');
      tags.add('Travel & Rollerballs');
      tags.add('Mini & Travel Size');
    }

    // 7. HAND SOAPS & SANITIZERS
    if (name.contains('foaming hand soap') && !name.contains('refill')) {
      tags.add('Foaming Soaps');
    }
    if ((name.contains('cleansing gel') ||
            name.contains('daily moisturizing hand soap') ||
            name.contains('revitalizing hand soap')) &&
        !name.contains('refill')) {
      tags.add('Gel & Moisturizing Soaps');
    }
    if (name.contains('pocketbac') && !name.contains('holder')) {
      tags.add('PocketBac Sanitizers');
      tags.add('PocketBacs');
    }
    if (name.contains('sanitizer spray') ||
        name.contains('pocketspray') ||
        name.contains('with pump') ||
        url.contains('-hand-sanitizer-spray-') ||
        url.contains('-pocketspray-')) {
      tags.add('Sanitizer Sprays');
    }
    if (name.contains('holder') ||
        name.contains('wristlet') ||
        name.contains('lanyard') ||
        name.contains('snapcase') ||
        url.contains('-holder-')) {
      tags.add('Soap & Sanitizer Holders');
      tags.add('Holders & Clips');
      tags.add('Holders & Accessories');
    }
    if (name.contains('refill') && (name.contains('soap') || dept.contains('soap'))) {
      tags.add('Soap Refills');
    }

    // 8. CANDLES
    if (name.contains('3-wick') || url.contains('-3-wick-')) {
      tags.add('3-Wick Candles');
      tags.add('3-Wick');
    }
    if (name.contains('single wick') || url.contains('-single-wick-')) {
      tags.add('Single Wick Candles');
      tags.add('Single Wick');
    }

    // 9. WALLFLOWERS & HOME FRAGRANCE
    if (name.contains('wallflowers fragrance refill') || url.contains('-wallflowers-fragrance-refill-')) {
      tags.add('Wallflowers Refills');
    }
    if (name.contains('wallflowers fragrance plug') ||
        name.contains('nightlight') ||
        url.contains('-wallflowers-fragrance-plug-')) {
      tags.add('Plugs & Nightlights');
    }
    if (name.contains('car fragrance') || url.contains('-car-fragrance-')) {
      tags.add('Car Fragrance');
    }
    if (name.contains('concentrated room spray') ||
        name.contains('room mist') ||
        url.contains('-room-spray-')) {
      tags.add('Room Sprays & Mists');
      tags.add('Room Sprays');
    }
    if (name.contains('reeds') || name.contains('vessel')) {
      tags.add('Liquidless Reeds');
    }

    // 10. THE MEN'S SHOP
    if (dept.contains('men') || url.contains('/mens-shop')) {
      if (name.contains('3-in-1') || name.contains('bar soap')) {
        tags.add('3-in-1 Wash & Bar Soap');
      }
      if (name.contains('body spray') || name.contains('deodorant') || name.contains('antiperspirant')) {
        tags.add('Body Spray & Deodorant');
      }
      if (name.contains('cologne')) {
        tags.add('Cologne');
        tags.add('Colognes');
      }
      if (name.contains('body cream') || name.contains('lotion')) {
        tags.add('Body Cream & Lotion');
        tags.add('Body Creams');
      }
      if (name.contains('candle') ||
          name.contains('wallflowers') ||
          name.contains('room spray') ||
          name.contains('car fragrance')) {
        tags.add('Car & Home Fragrance');
      }
    }

    return tags.toList();
  }
}
