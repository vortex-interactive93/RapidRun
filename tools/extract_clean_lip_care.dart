// File: tools/extract_clean_lip_care.dart

import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/all_moisturizers.json');
  if (!file.existsSync()) {
    print('Error: assets/data/all_moisturizers.json not found');
    exit(1);
  }

  final List<dynamic> rawData = jsonDecode(file.readAsStringSync());
  final List<Map<String, dynamic>> lipItems = [];

  for (final raw in rawData) {
    final item = Map<String, dynamic>.from(raw as Map);
    final name = (item['name'] ?? '').toString();
    final lowerName = name.toLowerCase();

    if (lowerName.contains('lip') ||
        lowerName.contains('mentha') ||
        lowerName.contains('gloss') ||
        lowerName.contains('tint') ||
        lowerName.contains('balm')) {
      lipItems.add({
        ...item,
        'department': 'Lip Care',
        'category': 'Body Care',
        'subCategory': 'Lip Care',
        'productType': 'Lip Care',
        'unit': '0.34 fl oz / 10 mL',
        'unitShort': '0.34 oz',
        'price': (item['price'] ?? item['salePrice'] ?? 8.95) as num,
        'regularPrice': (item['price'] ?? item['salePrice'] ?? 8.95) as num,
        'salePrice': (item['price'] ?? item['salePrice'] ?? 8.95) as num,
        'hasSpecial': false,
        'promoBadge': '',
      });
    }
  }

  final outputFile = File('assets/data/lip_care.json');
  outputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lipItems));
  print('✅ Generated assets/data/lip_care.json with ${lipItems.length} authentic Lip Care products!');
}
