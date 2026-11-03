import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Clean reverted model: single categories JSON file.
class AldiCategoryData {
  final List<AldiCategory> categories;
  AldiCategoryData(this.categories);

  static Future<AldiCategoryData> load() async {
    final raw = await rootBundle.loadString(
      'assets/stores/aldi/aldi_categories.json',
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
        .map(AldiCategory.fromJson)
        .toList();
    return AldiCategoryData(cats);
  }
}

class AldiCategory {
  final String name;
  final List<AldiSection> sections;
  final int? iconCodePoint;
  AldiCategory({
    required this.name,
    required this.sections,
    this.iconCodePoint,
  });
  factory AldiCategory.fromJson(Map<String, dynamic> j) => AldiCategory(
    name: (j['name'] ?? j['categoryName'] ?? '').toString(),
    iconCodePoint: j['iconCodePoint'] is int ? j['iconCodePoint'] as int : null,
    sections: ((j['sections'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AldiSection.fromJson)
        .toList(),
  );
}

class AldiSection {
  final String name;
  final List<AldiProductType> productTypes;
  AldiSection({required this.name, required this.productTypes});
  factory AldiSection.fromJson(Map<String, dynamic> j) => AldiSection(
    name: (j['name'] ?? j['sectionName'] ?? '').toString(),
    productTypes: ((j['productTypes'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AldiProductType.fromJson)
        .toList(),
  );
}

class AldiProductType {
  final String name;
  final String filePath; // asset path
  final int? iconCodePoint;
  AldiProductType({
    required this.name,
    required this.filePath,
    this.iconCodePoint,
  });
  factory AldiProductType.fromJson(Map<String, dynamic> j) => AldiProductType(
    name: (j['name'] ?? '').toString(),
    filePath: (j['filePath'] ?? '').toString(),
    iconCodePoint: j['iconCodePoint'] is int ? j['iconCodePoint'] as int : null,
  );
}
