// File: tools/seed_catalog.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final filePath = args.isNotEmpty 
      ? args[0] 
      : 'assets/data/bbw_instore_catalog.json';
  final projectId = args.length > 1 ? args[1] : 'rapidrun-dev';

  final file = File(filePath);
  if (!file.existsSync()) {
    stderr.writeln('❌ Target JSON file not found at: $filePath');
    exit(1);
  }

  stdout.writeln('📦 Reading harvested catalog from $filePath...');
  final rawData = jsonDecode(await file.readAsString()) as List<dynamic>;
  stdout.writeln('⚡ Ingesting ${rawData.length} SKUs into Cloud Firestore ($projectId)...');

  final baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/products';
  int successCount = 0;

  for (int i = 0; i < rawData.length; i++) {
    final item = Map<String, dynamic>.from(rawData[i] as Map);
    final sku = item['sku']?.toString() ?? item['id']?.toString() ?? '';
    if (sku.isEmpty) continue;

    final docId = sku.startsWith('bbw_') ? sku : 'bbw_$sku';
    final targetUrl = Uri.parse('$baseUrl/$docId');

    final body = {
      'fields': {
        'id': {'stringValue': docId},
        'sku': {'stringValue': item['sku']?.toString() ?? ''},
        'name': {'stringValue': item['name']?.toString() ?? ''},
        'brand': {'stringValue': item['brand']?.toString() ?? 'Bath & Body Works'},
        'store': {'stringValue': item['store']?.toString() ?? 'Bath & Body Works'},
        'category': {'stringValue': item['category']?.toString() ?? 'Fragrance'},
        'subCategory': {'stringValue': item['subCategory']?.toString() ?? 'Fine Fragrance Mist'},
        'price': {'doubleValue': (item['salePrice'] ?? item['price'] ?? 0.0) as num},
        'regularPrice': {'doubleValue': (item['regularPrice'] ?? 18.95) as num},
        'salePrice': {'doubleValue': (item['salePrice'] ?? 5.95) as num},
        'hasSpecial': {'booleanValue': item['hasSpecial'] == true},
        'isOnlineExclusive': {'booleanValue': false},
        'unit': {'stringValue': item['unit']?.toString() ?? '8 fl oz'},
        'unitShort': {'stringValue': item['unitShort']?.toString() ?? '8 oz'},
        'imageUrl': {'stringValue': item['imageUrl']?.toString() ?? ''},
        'productUrl': {'stringValue': item['productUrl']?.toString() ?? ''},
        'inStock': {'booleanValue': true},
        'fragranceNotes': {
          'arrayValue': {
            'values': (item['fragranceNotes'] as List? ?? [])
                .map((n) => {'stringValue': n.toString()})
                .toList()
          }
        }
      }
    };

    try {
      final res = await http.patch(
        targetUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        successCount++;
      } else {
        stderr.writeln('⚠️ Failed doc $docId (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      stderr.writeln('⚠️ Network error doc $docId: $e');
    }

    if ((i + 1) % 10 == 0 || i + 1 == rawData.length) {
      stdout.writeln('   Processed ${i + 1}/${rawData.length} items...');
    }
  }

  stdout.writeln('🎉 SUCCESS! Ingested $successCount / ${rawData.length} SKUs into Firestore.');
  exit(0);
}
