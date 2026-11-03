import 'package:flutter/material.dart';

enum ProductCertification {
  usdaChoice,
  usdaPrime,
  organic,
  grassFed,
  blackAngus,
  plantBased,
}

class ProductBadgeSpec {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const ProductBadgeSpec({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

class SanitizedProductData {
  final String heroTitle;
  final String brandLabel;
  final String? cleanDescription;
  final ProductBadgeSpec? primaryBadge;

  const SanitizedProductData({
    required this.heroTitle,
    required this.brandLabel,
    this.cleanDescription,
    this.primaryBadge,
  });
}

class ProductTitleSanitizer {
  static const Map<ProductCertification, ProductBadgeSpec> _badgeSpecs = {
    ProductCertification.usdaChoice: ProductBadgeSpec(
      label: 'USDA CHOICE',
      icon: Icons.verified_rounded,
      backgroundColor: Color(0xFF131E33),
      borderColor: Color(0xFFE6B450),
      textColor: Color(0xFFE6B450),
    ),
    ProductCertification.usdaPrime: ProductBadgeSpec(
      label: 'USDA PRIME',
      icon: Icons.workspace_premium_rounded,
      backgroundColor: Color(0xFF221706),
      borderColor: Color(0xFFFFD700),
      textColor: Color(0xFFFFD700),
    ),
    ProductCertification.organic: ProductBadgeSpec(
      label: 'ORGANIC',
      icon: Icons.eco_rounded,
      backgroundColor: Color(0xFF0F2618),
      borderColor: Color(0xFF4ADE80),
      textColor: Color(0xFF4ADE80),
    ),
    ProductCertification.grassFed: ProductBadgeSpec(
      label: 'GRASS-FED',
      icon: Icons.grass_rounded,
      backgroundColor: Color(0xFF14241B),
      borderColor: Color(0xFF86EFAC),
      textColor: Color(0xFF86EFAC),
    ),
    ProductCertification.blackAngus: ProductBadgeSpec(
      label: 'BLACK ANGUS',
      icon: Icons.stars_rounded,
      backgroundColor: Color(0xFF242424),
      borderColor: Color(0xFFB0B0B0),
      textColor: Colors.white,
    ),
    ProductCertification.plantBased: ProductBadgeSpec(
      label: 'PLANT-BASED',
      icon: Icons.local_florist_rounded,
      backgroundColor: Color(0xFF1E281C),
      borderColor: Color(0xFFA3E635),
      textColor: Color(0xFFA3E635),
    ),
  };

  static SanitizedProductData process({
    required String rawTitle,
    String? rawBrand,
    String? rawDescription,
  }) {
    String workingTitle = rawTitle;
    String workingBrand = rawBrand ?? '';
    String? cleanDesc = rawDescription;
    ProductBadgeSpec? detectedBadge;

    final combined = '$rawTitle $workingBrand'.toLowerCase();

    // 1. Detect Certification Badge
    if (combined.contains('usda prime')) {
      detectedBadge = _badgeSpecs[ProductCertification.usdaPrime];
    } else if (combined.contains('usda choice')) {
      detectedBadge = _badgeSpecs[ProductCertification.usdaChoice];
    } else if (combined.contains('organic')) {
      detectedBadge = _badgeSpecs[ProductCertification.organic];
    } else if (combined.contains('grass-fed') || combined.contains('grass fed')) {
      detectedBadge = _badgeSpecs[ProductCertification.grassFed];
    } else if (combined.contains('plant-based') || combined.contains('plant based')) {
      detectedBadge = _badgeSpecs[ProductCertification.plantBased];
    } else if (combined.contains('black angus')) {
      detectedBadge = _badgeSpecs[ProductCertification.blackAngus];
    }

    // 2. Extract and Isolate Brand
    String resolvedBrand = 'ALDI';
    if (workingTitle.toLowerCase().contains("cattlemen's ranch")) {
      resolvedBrand = "CATTLEMEN'S RANCH";
      workingTitle = workingTitle.replaceAll(RegExp(r"Cattlemen's Ranch", caseSensitive: false), '');
    } else if (workingTitle.toLowerCase().contains("black angus")) {
      resolvedBrand = "BLACK ANGUS";
      workingTitle = workingTitle.replaceAll(RegExp(r"Black Angus", caseSensitive: false), '');
    } else if (workingTitle.toLowerCase().contains("earth grown")) {
      resolvedBrand = "EARTH GROWN";
      workingTitle = workingTitle.replaceAll(RegExp(r"Earth Grown", caseSensitive: false), '');
    } else if (workingBrand.isNotEmpty && !workingBrand.toLowerCase().contains('choice') && !workingBrand.toLowerCase().contains('usda')) {
      resolvedBrand = workingBrand.toUpperCase();
    }

    // 3. Strip Certification Tokens and Unit Suffixes from Title
    String cleanHero = workingTitle
        .replaceAll(RegExp(r'\b(USDA\s+Prime|USDA\s+Choice|USDA\s+Organic|Organic|100%\s+Grass-Fed|Grass-Fed|Black\s+Angus|Plant-Based)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*per\s+lb\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bper\s+lb\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[,\-\s•]+'), '')
        .replaceAll(RegExp(r'[,\-\s•]+$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // 4. Clean Misattributed Catalog Descriptions
    if (cleanDesc != null && cleanDesc.toLowerCase().contains('fresh apples brimming with natural flavor')) {
      cleanDesc = 'Premium, tender beef selected for high quality, tenderness, and rich flavor. Perfect for searing, grilling, or roasting.';
    }

    return SanitizedProductData(
      heroTitle: cleanHero.isEmpty ? rawTitle : cleanHero,
      brandLabel: resolvedBrand,
      cleanDescription: cleanDesc,
      primaryBadge: detectedBadge,
    );
  }
}
