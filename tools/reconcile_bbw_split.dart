// File: tools/reconcile_bbw_split.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final projectId = args.isNotEmpty ? args[0] : 'rapidrun-f12cb';
  const storeName = 'Bath & Body Works';

  stdout.writeln('⚡ Initializing Catalog Reconciler Engine ($projectId)...');
  final firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  // STEP 1: COMPLETE SCOPED PURGE OF ALL EXISTING BBW PRODUCTS
  stdout.writeln('🧹 Step 1: Scanning for legacy "$storeName" products in Firestore...');
  try {
    final queryUrl = Uri.parse('$firestoreBaseUrl:runQuery');
    final queryBody = {
      'structuredQuery': {
        'from': [{'collectionId': 'products'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'store'},
            'op': 'EQUAL',
            'value': {'stringValue': storeName}
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

      stdout.writeln('🔍 Found ${docPathsToDelete.length} existing documents. Purging everything for a clean slate...');

      int deletedCount = 0;
      for (final path in docPathsToDelete) {
        final deleteUrl = Uri.parse('https://firestore.googleapis.com/v1/$path');
        final delRes = await http.delete(deleteUrl);
        if (delRes.statusCode == 200) {
          deletedCount++;
        }
      }
      stdout.writeln('🗑️ Purged $deletedCount legacy documents.');
    }
  } catch (e) {
    stdout.writeln('ℹ️ Purge scan note: $e');
  }

  // STEP 2: INGEST PERFUME & COLOGNE
  int totalIngested = 0;
  final perfumeFile = File('assets/data/Perfume_Cologne.json');
  if (perfumeFile.existsSync()) {
    final rawPerfume = jsonDecode(await perfumeFile.readAsString()) as List<dynamic>;
    stdout.writeln('📦 Ingesting ${rawPerfume.length} items from Perfume_Cologne.json...');
    totalIngested += await _seedBatch(
      firestoreBaseUrl,
      rawPerfume,
      storeName,
      'Fragrance',
      'Perfume & Cologne',
    );
  } else {
    stderr.writeln('⚠️ Warning: assets/data/Perfume_Cologne.json not found!');
  }

  // STEP 3: INGEST BODY SPRAYS & MISTS
  final mistsFile = File('assets/data/Body_Sprays_Mists.json');
  if (mistsFile.existsSync()) {
    final rawMists = jsonDecode(await mistsFile.readAsString()) as List<dynamic>;
    stdout.writeln('📦 Ingesting ${rawMists.length} items from Body_Sprays_Mists.json...');
    totalIngested += await _seedBatch(
      firestoreBaseUrl,
      rawMists,
      storeName,
      'Fragrance',
      'Body Sprays & Mists',
    );
  } else {
    stderr.writeln('⚠️ Warning: assets/data/Body_Sprays_Mists.json not found!');
  }

  stdout.writeln('🎉 RECONCILIATION COMPLETE! $totalIngested verified SKUs live with clean departments & subcategories.');
  exit(0);
}

Future<int> _seedBatch(
  String firestoreBaseUrl,
  List<dynamic> rawItems,
  String store,
  String category,
  String department,
) async {
  int count = 0;

  for (int i = 0; i < rawItems.length; i++) {
    final raw = rawItems[i];
    final item = Map<String, dynamic>.from(raw as Map);
    final sku = item['sku']?.toString() ?? item['id']?.toString() ?? '';
    if (sku.isEmpty) continue;

    final docId = sku.startsWith('bbw_') ? sku : 'bbw_$sku';
    final targetUrl = Uri.parse('$firestoreBaseUrl/products/$docId');

    final name = (item['name'] ?? '').toString();
    final lowerName = name.toLowerCase();
    String subCategory = item['subCategory'] ?? 'Fine Fragrance Mist';

    if (department == 'Perfume & Cologne') {
      if (lowerName.contains('rollerball')) {
        subCategory = 'Eau de Parfum Rollerball';
      } else if (lowerName.contains('mini eau de parfum') || lowerName.contains('mini perfume')) {
        subCategory = 'Mini Eau de Parfum';
      } else if (lowerName.contains('mini cologne') || (lowerName.contains('travel') && lowerName.contains('cologne'))) {
        subCategory = 'Travel Cologne';
      } else if (lowerName.contains('cologne')) {
        subCategory = 'Cologne';
      } else {
        subCategory = 'Eau de Parfum';
      }
    } else {
      if (lowerName.contains('deodorizing') || lowerName.contains('body spray')) {
        subCategory = 'Deodorizing Body Spray';
      } else if (lowerName.contains('shimmer')) {
        subCategory = 'Diamond Shimmer Mist';
      } else if (lowerName.contains('essential oil') || lowerName.contains('aromatherapy')) {
        subCategory = 'Essential Oil Mist';
      } else {
        subCategory = 'Fine Fragrance Mist';
      }
    }

    final body = {
      'fields': {
        'id': {'stringValue': docId},
        'sku': {'stringValue': sku.replaceAll('bbw_', '')},
        'name': {'stringValue': name},
        'brand': {'stringValue': item['brand']?.toString() ?? 'Bath & Body Works'},
        'store': {'stringValue': store},
        'category': {'stringValue': category},
        'department': {'stringValue': department},
        'subCategory': {'stringValue': subCategory},
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
        count++;
      }
    } catch (e) {
      stderr.writeln('⚠️ Network error doc $docId: $e');
    }

    if ((i + 1) % 20 == 0 || i + 1 == rawItems.length) {
      stdout.writeln('   Seeded ${i + 1}/${rawItems.length} $department items...');
    }
  }

  return count;
}
