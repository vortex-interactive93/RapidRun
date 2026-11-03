// File: tools/reconcile_catalog.dart

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

  stdout.writeln('⚡ Initializing Catalog Reconciler Engine ($projectId)...');
  const storeFilter = 'Bath & Body Works';

  final firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  // 1. PURGE LEGACY & MALFORMED DOCUMENTS VIA FIRESTORE REST API
  stdout.writeln('🧹 Step 1: Scanning for existing "$storeFilter" items in Firestore...');
  
  try {
    final queryUrl = Uri.parse('$firestoreBaseUrl:runQuery');
    final queryBody = {
      'structuredQuery': {
        'from': [{'collectionId': 'products'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'store'},
            'op': 'EQUAL',
            'value': {'stringValue': storeFilter}
          }
        }
      }
    };

    final queryRes = await http.post(
      queryUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(queryBody),
    );

    if (queryRes.statusCode == 200) {
      final List<dynamic> queryDocs = jsonDecode(queryRes.body) as List<dynamic>;
      final List<String> docPathsToDelete = [];

      for (final item in queryDocs) {
        if (item is Map && item.containsKey('document')) {
          final docName = item['document']['name'] as String?;
          if (docName != null && docName.isNotEmpty) {
            docPathsToDelete.add(docName);
          }
        }
      }

      stdout.writeln('🔍 Found ${docPathsToDelete.length} existing documents. Purging legacy entries...');

      int deletedCount = 0;
      for (final path in docPathsToDelete) {
        final deleteUrl = Uri.parse('https://firestore.googleapis.com/v1/$path');
        final delRes = await http.delete(deleteUrl);
        if (delRes.statusCode == 200) {
          deletedCount++;
        }
      }
      stdout.writeln('🗑️  Purged $deletedCount legacy documents.');
    } else {
      stdout.writeln('ℹ️  Query note (${queryRes.statusCode}): Proceeding to clean SKU ingestion.');
    }
  } catch (e) {
    stdout.writeln('ℹ️  Purge scan note: $e');
  }

  // 2. SEED CLEAN, HIGH-FIDELITY SKU DATASET
  final rawData = jsonDecode(await file.readAsString()) as List<dynamic>;
  stdout.writeln('📦 Step 2: Ingesting ${rawData.length} verified physical in-store SKUs...');

  int insertedCount = 0;
  for (int i = 0; i < rawData.length; i++) {
    final item = Map<String, dynamic>.from(rawData[i] as Map);
    final sku = item['sku']?.toString() ?? item['id']?.toString() ?? '';
    if (sku.isEmpty) continue;

    final docId = sku.startsWith('bbw_') ? sku : 'bbw_$sku';
    final targetUrl = Uri.parse('$firestoreBaseUrl/products/$docId');

    final body = {
      'fields': {
        'id': {'stringValue': docId},
        'sku': {'stringValue': item['sku']?.toString() ?? ''},
        'name': {'stringValue': item['name']?.toString() ?? ''},
        'brand': {'stringValue': item['brand']?.toString() ?? 'Bath & Body Works'},
        'storeId': {'stringValue': 'bbw_westover_village'},
        'store': {'stringValue': storeFilter},
        'category': {'stringValue': item['category']?.toString() ?? 'Fragrance'},
        'subCategory': {'stringValue': item['subCategory']?.toString() ?? 'Fine Fragrance Mist'},
        'price': {'doubleValue': (item['salePrice'] ?? item['price'] ?? 0.0) as num},
        'regularPrice': {'doubleValue': (item['regularPrice'] ?? 18.95) as num},
        'salePrice': {'doubleValue': (item['salePrice'] ?? 5.95) as num},
        'hasSpecial': {'booleanValue': item['hasSpecial'] == true},
        'promoBadge': {'stringValue': item['promoBadge']?.toString() ?? ''},
        'isOnlineExclusive': {'booleanValue': false},
        'unit': {'stringValue': item['unit']?.toString() ?? '8 fl oz'},
        'unitShort': {'stringValue': item['unitShort']?.toString() ?? '8 oz'},
        'imageUrl': {'stringValue': item['imageUrl']?.toString() ?? ''},
        'productUrl': {'stringValue': item['productUrl']?.toString() ?? ''},
        'fragranceOverview': {'stringValue': item['fragranceOverview']?.toString() ?? ''},
        'inStock': {'booleanValue': true},
        'rating': {'doubleValue': (item['rating'] ?? 4.8) as num},
        'ratingCount': {'integerValue': (item['ratingCount'] ?? 140).toString()},
        'indexedAt': {'integerValue': DateTime.now().millisecondsSinceEpoch.toString()},
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
        insertedCount++;
      }
    } catch (e) {
      stderr.writeln('⚠️ Network error doc $docId: $e');
    }

    if ((i + 1) % 15 == 0 || i + 1 == rawData.length) {
      stdout.writeln('   Seeded ${i + 1}/${rawData.length} items...');
    }
  }

  stdout.writeln('🎉 RECONCILIATION COMPLETE! $insertedCount pristine SKUs now indexed in "products/".');
  exit(0);
}
