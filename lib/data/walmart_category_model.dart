import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class WalmartCategoryData {
  final List<WalmartCategory> categories;
  WalmartCategoryData(this.categories);
  static Future<WalmartCategoryData> load() async {
    final raw = await rootBundle.loadString(
      'assets/stores/walmart/walmart_categories.json',
    );
    final decoded = json.decode(raw);
    List<dynamic> sourceList;
    if (decoded is List) {
      sourceList = decoded;
    } else if (decoded is Map && decoded['categories'] is List) {
      sourceList = decoded['categories'];
    } else {
      sourceList = const [];
    }
    final cats = sourceList
        .whereType<Map<String, dynamic>>()
        .map(WalmartCategory.fromJson)
        .toList();
    return WalmartCategoryData(cats);
  }
}

class WalmartCategory {
  final String name;
  final List<WalmartSection> sections;
  WalmartCategory({required this.name, required this.sections});
  factory WalmartCategory.fromJson(Map<String, dynamic> j) => WalmartCategory(
    name: (j['name'] ?? j['categoryName'] ?? '').toString(),
    sections: ((j['sections'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalmartSection.fromJson)
        .toList(),
  );
}

class WalmartSection {
  final String name;
  final List<WalmartProductType> productTypes;
  WalmartSection({required this.name, required this.productTypes});
  factory WalmartSection.fromJson(Map<String, dynamic> j) => WalmartSection(
    name: (j['name'] ?? j['sectionName'] ?? '').toString(),
    productTypes: ((j['productTypes'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalmartProductType.fromJson)
        .toList(),
  );
}

class WalmartProductType {
  final String name;
  final String filePath;
  WalmartProductType({required this.name, required this.filePath});
  factory WalmartProductType.fromJson(Map<String, dynamic> j) =>
      WalmartProductType(
        name: (j['name'] ?? '').toString(),
        filePath: (j['filePath'] ?? '').toString(),
      );
}
