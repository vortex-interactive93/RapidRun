import 'package:flutter/foundation.dart';
import '../utils/bbw_product_classifier.dart';

@immutable
class FragranceProfile {
  final String family;
  final List<String> topNotes;
  final List<String> heartNotes;
  final List<String> baseNotes;

  const FragranceProfile({
    required this.family,
    this.topNotes = const [],
    this.heartNotes = const [],
    this.baseNotes = const [],
  });

  factory FragranceProfile.fromJson(Map<String, dynamic> json) => FragranceProfile(
    family: (json['family'] ?? 'Fragrance').toString(),
    topNotes: (json['topNotes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    heartNotes: (json['heartNotes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    baseNotes: (json['baseNotes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'family': family,
    'topNotes': topNotes,
    'heartNotes': heartNotes,
    'baseNotes': baseNotes,
  };
}

/// Unified Product domain model (used for both sample in-memory data and
/// JSON asset catalog). Supports both standard and minified JSON keys seamlessly.
@immutable
class Product {
  final String id;
  final String name;
  final String? brand; // product brand (e.g. A&W, Bath & Body Works)
  final String? store; // store/brand identifier (e.g. "ALDI", "Bath & Body Works")
  final String? category; // broad category (e.g. "Candles")
  final String? subCategory; // refined grouping
  final String? productType; // specific product type (e.g. "3-Wick Candle")
  final double? price;
  final double? msrp;
  final double? rating; // 0-5 (optional)
  final List<String> tags; // descriptors (may be empty)
  final String? imageAsset; // local asset path (sample demo)
  final String? imageUrl; // remote / CDN URL (asset catalog)
  final String? description; // optional description
  final String? benefits; // marketing copy (nullable)
  final String? unit; // size/quantity description
  final String? unitShort; // concise unit for UI (e.g. "8 oz")
  // Optional configurable modifiers
  final List<ProductModifier> modifiers;
  // Combo modeling
  final bool isCombo;
  final List<String> includedItems;
  final List<ComboChoiceGroup> choiceGroups;
  // Bundle / wrapper support
  final bool isBundleWrapper;
  final String? bundleBaseProductId;
  final BundleRules? bundleRules;

  // Luxury & Beauty extensions
  final FragranceProfile? fragranceProfile;
  final List<String> cleanStandards;

  // Deep PDP & E-Commerce ingestion extensions
  final List<String> galleryImages;
  final String? productUrl;
  final String? fragranceOverview;
  final List<String> fragranceNotes;
  final String? ingredients;
  final String? howToUse;
  final String? editorialStory;

  // Pricing & Dual-MSRP Ingestion Extensions
  final double? regularPrice;
  final double? salePrice;
  final String? promoBadge;
  final bool? isOnlineExclusive;

  bool get hasSpecial {
    final curPrice = price ?? (salePrice ?? 0.0);
    final regPrice = msrp ?? (regularPrice ?? curPrice);
    return regPrice > curPrice && curPrice > 0;
  }

  const Product({
    required this.id,
    required this.name,
    this.brand,
    this.store,
    this.category,
    this.subCategory,
    this.productType,
    this.price,
    this.msrp,
    this.rating,
    this.tags = const [],
    this.imageAsset,
    this.imageUrl,
    this.description,
    this.benefits,
    this.unit,
    this.unitShort,
    this.modifiers = const [],
    this.isCombo = false,
    this.includedItems = const [],
    this.choiceGroups = const [],
    this.isBundleWrapper = false,
    this.bundleBaseProductId,
    this.bundleRules,
    this.fragranceProfile,
    this.cleanStandards = const [],
    this.galleryImages = const [],
    this.productUrl,
    this.fragranceOverview,
    this.fragranceNotes = const [],
    this.ingredients,
    this.howToUse,
    this.editorialStory,
    this.regularPrice,
    this.salePrice,
    this.promoBadge,
    this.isOnlineExclusive,
  });

  factory Product.fromJson(Map<String, dynamic> map) {
    final String rawPromo = (map['promoBadge'] ?? map['promo'] ?? '').toString().trim();
    final bool hasExplicitPromo = rawPromo.isNotEmpty;

    double curPrice = map['price'] is num
        ? (map['price'] as num).toDouble()
        : (map['salePrice'] is num ? (map['salePrice'] as num).toDouble() : 0.0);
    double listPrice = map['regularPrice'] is num
        ? (map['regularPrice'] as num).toDouble()
        : (map['msrp'] is num ? (map['msrp'] as num).toDouble() : curPrice);

    if (listPrice <= 0) listPrice = curPrice;

    // If there is no explicit promo badge or active special flag, use the regular retail price!
    if (!hasExplicitPromo && listPrice > 0) {
      curPrice = listPrice;
    }

    final String rawUnit = (map['unit'] ?? '').toString().trim();

    String shortUnit = (map['unitShort'] ?? '').toString().trim();
    if (shortUnit.isEmpty && rawUnit.isNotEmpty) {
      final match = RegExp(r'([0-9.]+\s*(?:fl\s*oz|oz|sheets|g|mL))', caseSensitive: false).firstMatch(rawUnit);
      shortUnit = match != null ? match.group(1)!.replaceAll(RegExp(r'fl\s*', caseSensitive: false), '').trim() : rawUnit;
    }

    final rawNotes = map['fragranceNotes'] ?? map['notes'];
    final List<String> notes = (rawNotes is List)
        ? rawNotes.map((e) => e.toString()).toList()
        : const [];

    final List<String> rawTags = (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final List<String> computedTags = BbwProductClassifier.classifyProduct(map);
    final Set<String> combinedTags = {...rawTags, ...computedTags};

    return Product(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? '').toString(),
      brand: map['brand']?.toString() ?? 'Bath & Body Works',
      store: (map['storeId'] ?? map['store'])?.toString() ?? 'Bath & Body Works',
      category: (map['category'] ?? map['cat'])?.toString(),
      subCategory: (map['subCategory'] ?? map['subCat'])?.toString(),
      productType: (map['productType'] ?? map['type'] ?? map['subCategory'])?.toString(),
      price: curPrice,
      msrp: listPrice,
      regularPrice: listPrice,
      salePrice: curPrice,
      promoBadge: rawPromo,
      isOnlineExclusive: map['isOnlineExclusive'] == true,
      unit: rawUnit.isNotEmpty ? rawUnit : 'Standard',
      unitShort: shortUnit.isNotEmpty ? shortUnit : 'Item',
      fragranceOverview: (map['fragranceOverview'] ?? map['overview'])?.toString(),
      fragranceNotes: notes,
      rating: map['rating'] is num ? (map['rating'] as num).toDouble() : 4.8,
      tags: combinedTags.toList(),
      imageAsset: map['imageAsset']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      description: map['description']?.toString(),
      benefits: map['benefits']?.toString(),
      modifiers: (map['modifiers'] as List?)
              ?.map((g) => ProductModifier.fromJson(g as Map<String, dynamic>))
              .toList() ?? const [],
      isCombo: map['isCombo'] == true,
      includedItems: (map['includedItems'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      choiceGroups: (map['choiceGroups'] as List?)
              ?.whereType<Map>()
              .map((e) => ComboChoiceGroup.fromJson(e.cast<String, dynamic>()))
              .toList() ?? const [],
      isBundleWrapper: map['isBundleWrapper'] == true,
      bundleBaseProductId: map['bundleBaseProductId']?.toString(),
      bundleRules: map['bundleRules'] is Map
          ? BundleRules.fromJson((map['bundleRules'] as Map).cast<String, dynamic>())
          : null,
      fragranceProfile: map['fragranceProfile'] is Map
          ? FragranceProfile.fromJson((map['fragranceProfile'] as Map).cast<String, dynamic>())
          : null,
      cleanStandards: (map['cleanStandards'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      galleryImages: (map['galleryImages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      productUrl: map['productUrl']?.toString(),
      ingredients: map['ingredients']?.toString(),
      howToUse: map['howToUse']?.toString(),
      editorialStory: map['editorialStory']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (brand != null) 'brand': brand,
    if (store != null) 'store': store,
    if (category != null) 'category': category,
    if (subCategory != null) 'subCategory': subCategory,
    if (productType != null) 'productType': productType,
    if (price != null) 'price': price,
    if (msrp != null) 'msrp': msrp,
    if (rating != null) 'rating': rating,
    if (tags.isNotEmpty) 'tags': tags,
    if (imageAsset != null) 'imageAsset': imageAsset,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (description != null) 'description': description,
    if (benefits != null) 'benefits': benefits,
    if (unit != null) 'unit': unit,
    if (unitShort != null) 'unitShort': unitShort,
    if (modifiers.isNotEmpty)
      'modifiers': modifiers.map((m) => m.toJson()).toList(),
    if (isCombo) 'isCombo': true,
    if (includedItems.isNotEmpty) 'includedItems': includedItems,
    if (choiceGroups.isNotEmpty)
      'choiceGroups': choiceGroups.map((g) => g.toJson()).toList(),
    if (isBundleWrapper) 'isBundleWrapper': true,
    if (bundleBaseProductId != null) 'bundleBaseProductId': bundleBaseProductId,
    if (bundleRules != null) 'bundleRules': bundleRules!.toJson(),
    if (fragranceProfile != null) 'fragranceProfile': fragranceProfile!.toJson(),
    if (cleanStandards.isNotEmpty) 'cleanStandards': cleanStandards,
    if (galleryImages.isNotEmpty) 'galleryImages': galleryImages,
    if (productUrl != null) 'productUrl': productUrl,
    if (fragranceOverview != null) 'fragranceOverview': fragranceOverview,
    if (fragranceNotes.isNotEmpty) 'fragranceNotes': fragranceNotes,
    if (ingredients != null) 'ingredients': ingredients,
    if (howToUse != null) 'howToUse': howToUse,
    if (editorialStory != null) 'editorialStory': editorialStory,
    if (regularPrice != null) 'regularPrice': regularPrice,
    if (salePrice != null) 'salePrice': salePrice,
    if (promoBadge != null) 'promoBadge': promoBadge,
    if (isOnlineExclusive == true) 'isOnlineExclusive': true,
  };
}

/// A group of configuration options (e.g. "Add Ons", "Make it Your Own").
@immutable
class ProductModifier {
  final String id;
  final String name;
  final String selection; // single | multi | toggle
  final int? min;
  final int? max;
  final List<ModifierOption> options;
  final bool included; // whether items are pre-included (informational)

  const ProductModifier({
    required this.id,
    required this.name,
    required this.selection,
    this.min,
    this.max,
    this.options = const [],
    this.included = false,
  });

  factory ProductModifier.fromJson(Map<String, dynamic> map) {
    // Support legacy / new schema using 'items' instead of 'options'.
    final rawList = (map['options'] as List?) ?? (map['items'] as List?);
    final opts =
        rawList
            ?.whereType<Map>()
            .map((o) => ModifierOption.fromJson(o.cast<String, dynamic>()))
            .toList() ??
        const <ModifierOption>[];
    return ProductModifier(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      selection: map['selection']?.toString() ?? 'multi',
      min: map['min'] is num ? (map['min'] as num).toInt() : null,
      max: map['max'] is num ? (map['max'] as num).toInt() : null,
      options: opts,
      included: map['included'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'selection': selection,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (included) 'included': true,
    if (options.isNotEmpty) 'options': options.map((o) => o.toJson()).toList(),
  };
}

/// Individual selectable add-on / customization.
@immutable
class ModifierOption {
  final String id;
  final String name;
  final double? priceDelta;
  final int? caloriesDelta; // may be negative
  final bool isDefault;
  final List<String> tags;

  const ModifierOption({
    required this.id,
    required this.name,
    this.priceDelta,
    this.caloriesDelta,
    this.isDefault = false,
    this.tags = const [],
  });

  factory ModifierOption.fromJson(Map<String, dynamic> map) => ModifierOption(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    priceDelta: map['priceDelta'] is num
        ? (map['priceDelta'] as num).toDouble()
        : null,
    caloriesDelta: map['caloriesDelta'] is num
        ? (map['caloriesDelta'] as num).toInt()
        : null,
    isDefault: map['default'] == true,
    tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (priceDelta != null) 'priceDelta': priceDelta,
    if (caloriesDelta != null) 'caloriesDelta': caloriesDelta,
    if (isDefault) 'default': true,
    if (tags.isNotEmpty) 'tags': tags,
  };
}

/// Combo choice group (e.g., "Drink", "Side").
@immutable
class ComboChoiceGroup {
  final String id;
  final String name;
  final int? min;
  final int? max;
  final List<ComboChoiceOption> options;
  final bool allowRepeat;
  const ComboChoiceGroup({
    required this.id,
    required this.name,
    this.min,
    this.max,
    this.options = const [],
    this.allowRepeat = false,
  });
  factory ComboChoiceGroup.fromJson(Map<String, dynamic> map) =>
      ComboChoiceGroup(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        min: map['min'] is num ? (map['min'] as num).toInt() : null,
        max: map['max'] is num ? (map['max'] as num).toInt() : null,
        options:
            (map['options'] as List?)
                ?.whereType<Map>()
                .map(
                  (o) => ComboChoiceOption.fromJson(o.cast<String, dynamic>()),
                )
                .toList() ??
            const [],
        allowRepeat: map['allowRepeat'] == true,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (options.isNotEmpty) 'options': options.map((o) => o.toJson()).toList(),
    if (allowRepeat) 'allowRepeat': true,
  };
}

/// Rules describing bundle-specific pricing/inclusions.
@immutable
class BundleRules {
  final bool includedRegularDrink;
  final double? largeDrinkUpgradeDelta;
  const BundleRules({
    required this.includedRegularDrink,
    this.largeDrinkUpgradeDelta,
  });
  factory BundleRules.fromJson(Map<String, dynamic> map) => BundleRules(
    includedRegularDrink: map['includedRegularDrink'] == true,
    largeDrinkUpgradeDelta: map['largeDrinkUpgradeDelta'] is num
        ? (map['largeDrinkUpgradeDelta'] as num).toDouble()
        : null,
  );
  Map<String, dynamic> toJson() => {
    'includedRegularDrink': includedRegularDrink,
    if (largeDrinkUpgradeDelta != null)
      'largeDrinkUpgradeDelta': largeDrinkUpgradeDelta,
  };
}

/// Individual combo choice option.
@immutable
class ComboChoiceOption {
  final String id;
  final String name;
  final String? refProductId;
  final String? imageUrl;
  final String? caloriesLabel;
  final double? priceDelta;
  final int? caloriesDelta;
  final bool isDefault;
  const ComboChoiceOption({
    required this.id,
    required this.name,
    this.refProductId,
    this.imageUrl,
    this.caloriesLabel,
    this.priceDelta,
    this.caloriesDelta,
    this.isDefault = false,
  });
  factory ComboChoiceOption.fromJson(Map<String, dynamic> map) =>
      ComboChoiceOption(
        id: (map['id'] ?? '').toString(),
        name: (map['label'] ?? map['name'] ?? '').toString(),
        refProductId: map['refProductId']?.toString(),
        imageUrl: map['imageUrl']?.toString(),
        caloriesLabel: (map['caloriesLabel'] ?? map['calories'])?.toString(),
        priceDelta: map['priceDelta'] is num
            ? (map['priceDelta'] as num).toDouble()
            : null,
        caloriesDelta: map['caloriesDelta'] is num
            ? (map['caloriesDelta'] as num).toInt()
            : null,
        isDefault: map['default'] == true,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (refProductId != null) 'refProductId': refProductId,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (caloriesLabel != null) 'caloriesLabel': caloriesLabel,
    if (priceDelta != null) 'priceDelta': priceDelta,
    if (caloriesDelta != null) 'caloriesDelta': caloriesDelta,
    if (isDefault) 'default': true,
  };
}

extension ProductPricing on Product {
  /// Compute total price including selected modifier option ids.
  double? totalPrice(Set<String> selectedOptionIds) {
    if (price == null) return null;
    var total = price!;
    for (final m in modifiers) {
      for (final o in m.options) {
        if (selectedOptionIds.contains(o.id) && o.priceDelta != null) {
          total += o.priceDelta!;
        }
      }
    }
    return total;
  }
}

/// In-memory sample catalog (small) retained for recommendation prototype.
class ProductRepository {
  static final List<Product> sampleProducts = [
    const Product(
      id: 'aldi_milk_1',
      name: 'Organic 2% Milk',
      brand: 'Generic',
      category: 'grocery',
      store: 'ALDI',
      price: 3.49,
      rating: 4.6,
      tags: ['dairy', 'organic', 'staple'],
      imageAsset: 'assets/products/milk.png',
      description: null,
    ),
    const Product(
      id: 'aldi_eggs_1',
      name: 'Cage-Free Eggs (12ct)',
      brand: 'Generic',
      category: 'grocery',
      store: 'ALDI',
      price: 2.79,
      rating: 4.4,
      tags: ['eggs', 'protein', 'breakfast'],
      imageAsset: 'assets/products/eggs.png',
      description: null,
    ),
    const Product(
      id: 'target_cereal_1',
      name: 'Honey Oat Cereal',
      brand: 'Generic',
      category: 'grocery',
      store: 'Target',
      price: 4.19,
      rating: 4.1,
      tags: ['cereal', 'breakfast', 'snack'],
      imageAsset: 'assets/products/cereal.png',
      description: null,
    ),
    const Product(
      id: 'target_shampoo_1',
      name: 'Moisturizing Shampoo',
      brand: 'Generic',
      category: 'beauty',
      store: 'Target',
      price: 7.99,
    ),
  ];
}
