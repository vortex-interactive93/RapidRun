// File: lib/services/data_seeder_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataSeederService {
  static bool _isSeeding = false;

  /// Main entry point to seed the full Bath & Body Works catalog into Cloud Firestore
  static Future<int> seedAllCatalogs() async {
    if (_isSeeding) return 0;
    _isSeeding = true;

    int totalIngested = 0;
    int totalPurged = 0;
    final Map<String, Map<String, dynamic>> masterRegistry = {};

    try {
      final catalogFiles = [
        'assets/data/candles.json',
        'assets/data/body_care.json',
        'assets/data/hand_soaps_sanitizers.json',
        'assets/data/wallflowers_diffusers.json',
        'assets/data/mens_shop.json',
        'assets/data/home_care.json',
        'assets/data/all_fragrance.json',
        'assets/data/mini_and_travel_size.json',
      ];

      for (final filePath in catalogFiles) {
        try {
          final jsonString = await rootBundle.loadString(filePath);
          final List<dynamic> items = jsonDecode(jsonString);

          for (final raw in items) {
            final item = Map<String, dynamic>.from(raw as Map);
            final sku = (item['sku'] ?? item['id'] ?? '').toString().trim();
            if (sku.isEmpty) continue;

            final docId = sku.startsWith('bbw_') ? sku : 'bbw_$sku';

            // Normalize category routing
            final String normalizedCategory = _resolveCategory(item);
            final String normalizedDepartment = item['department'] ?? normalizedCategory;
            final String productType = item['productType'] ?? 'General';
            final bool isAccessory = productType.contains('Accessories') ||
                productType.contains('Holder') ||
                productType.contains('Plug');

            // Sanitize fragrance notes: strip "Top  ", "Heart  ", "Base  ", "top:", "heart:", "base:"
            final List<dynamic> rawNotes = item['fragranceNotes'] ?? [];
            final List<String> cleanNotes = isAccessory
                ? []
                : rawNotes
                    .map((n) => n
                        .toString()
                        .replaceAll(RegExp(r'^\s*(?:top|heart|base|mid|dry)\s*[:\-–]?\s*', caseSensitive: false), '')
                        .trim())
                    .where((n) => n.isNotEmpty)
                    .toSet()
                    .toList();

            final Map<String, dynamic> rawTiers = Map<String, dynamic>.from(
                item['fragranceTiers'] ?? (item['fragranceProfile'] is Map ? item['fragranceProfile'] : {}));
            final Map<String, List<String>> cleanTiers = {'top': [], 'heart': [], 'base': []};

            for (final key in ['top', 'heart', 'base', 'topNotes', 'heartNotes', 'baseNotes']) {
              final targetKey = key.startsWith('top') ? 'top' : (key.startsWith('heart') ? 'heart' : 'base');
              if (rawTiers[key] is List) {
                final List<String> parsed = (rawTiers[key] as List)
                    .map((n) => n
                        .toString()
                        .replaceAll(RegExp(r'^\s*(?:top|heart|base|mid|dry)\s*[:\-–]?\s*', caseSensitive: false), '')
                        .trim())
                    .where((n) => n.isNotEmpty)
                    .toList();
                cleanTiers[targetKey]!.addAll(parsed);
              }
            }

            final double price = (item['price'] ?? item['salePrice'] ?? 0.0).toDouble();
            final double regularPrice = (item['regularPrice'] ?? price).toDouble();
            final String promoBadge = (item['promoBadge'] ?? '').toString().trim();

            final Map<String, dynamic> docData = {
              'id': docId,
              'sku': sku.replaceAll('bbw_', ''),
              'name': item['name'] ?? '',
              'brand': 'Bath & Body Works',
              'store': 'Bath & Body Works',
              'category': normalizedCategory,
              'department': normalizedDepartment,
              'subCategory': item['subCategory'] ?? productType,
              'productType': productType,
              'price': price,
              'salePrice': price,
              'regularPrice': regularPrice,
              'hasSpecial': promoBadge.isNotEmpty || (regularPrice - price) > 0.05,
              'promoBadge': promoBadge,
              'unit': (item['unit'] ?? '').toString().trim().isNotEmpty
                  ? item['unit']
                  : (isAccessory ? '1 pc' : 'Standard'),
              'unitShort': (item['unitShort'] ?? '').toString().trim().isNotEmpty
                  ? item['unitShort']
                  : (isAccessory ? 'Item' : 'Standard'),
              'imageUrl': item['imageUrl'] ?? '',
              'productUrl': item['productUrl'] ?? '',
              'fragranceNotes': cleanNotes,
              'fragranceOverview': isAccessory
                  ? 'Compatible with Bath & Body Works accessories and refills (sold separately).'
                  : (item['fragranceOverview'] ?? ''),
              'inStock': true,
              'isOnlineExclusive': false,
              'rating': 4.8,
              'ratingCount': 140,
              'updatedAt': FieldValue.serverTimestamp(),
              'indexedAt': DateTime.now().millisecondsSinceEpoch,
            };

            if (!isAccessory && (cleanTiers['top']!.isNotEmpty || cleanTiers['heart']!.isNotEmpty || cleanTiers['base']!.isNotEmpty)) {
              docData['fragranceProfile'] = {
                'family': normalizedCategory,
                'topNotes': cleanTiers['top']!.toSet().toList(),
                'heartNotes': cleanTiers['heart']!.toSet().toList(),
                'baseNotes': cleanTiers['base']!.toSet().toList(),
              };
              docData['fragranceTiers'] = {
                'top': cleanTiers['top']!.toSet().toList(),
                'heart': cleanTiers['heart']!.toSet().toList(),
                'base': cleanTiers['base']!.toSet().toList(),
              };
            }

            if (masterRegistry.containsKey(docId)) {
              final existing = masterRegistry[docId]!;
              final List<String> existingNotes = (existing['fragranceNotes'] as List?)?.cast<String>() ?? [];
              final List<String> bestNotes = cleanNotes.length >= existingNotes.length ? cleanNotes : existingNotes;
              docData['fragranceNotes'] = bestNotes;
            }

            masterRegistry[docId] = docData;
          }
        } catch (fileErr) {
          debugPrint('[DataSeeder] Skipping file $filePath: $fileErr');
        }
      }

      final firestore = FirebaseFirestore.instance;

      // 1. STALE DOCUMENT PURGE PASS (Delete retired SKUs)
      try {
        final existingDocsQuery = await firestore
            .collection('products')
            .where('store', isEqualTo: 'Bath & Body Works')
            .get();

        final List<DocumentReference> staleDocs = [];
        for (final doc in existingDocsQuery.docs) {
          if (!masterRegistry.containsKey(doc.id)) {
            staleDocs.add(doc.reference);
          }
        }

        if (staleDocs.isNotEmpty) {
          debugPrint('[DataSeeder] Found ${staleDocs.length} stale/retired Firestore docs to purge.');
          const purgeBatchSize = 400;
          final totalPurgeBatches = (staleDocs.length / purgeBatchSize).ceil();

          for (int i = 0; i < totalPurgeBatches; i++) {
            final batch = firestore.batch();
            final start = i * purgeBatchSize;
            final end = (start + purgeBatchSize < staleDocs.length) ? start + purgeBatchSize : staleDocs.length;
            final chunk = staleDocs.sublist(start, end);

            for (final docRef in chunk) {
              batch.delete(docRef);
              totalPurged++;
            }
            await batch.commit();
          }
          debugPrint('[DataSeeder] Successfully purged $totalPurged stale Firestore documents.');
        }
      } catch (purgeErr) {
        debugPrint('[DataSeeder] Purge pass notice: $purgeErr');
      }

      // 2. MASTER REFRESH WRITE PASS (Overwrite with exact new asset values)
      final docs = masterRegistry.values.toList();
      const batchSize = 400;
      final totalBatches = (docs.length / batchSize).ceil();

      for (int i = 0; i < totalBatches; i++) {
        final batch = firestore.batch();
        final start = i * batchSize;
        final end = (start + batchSize < docs.length) ? start + batchSize : docs.length;
        final chunk = docs.sublist(start, end);

        for (final product in chunk) {
          final docRef = firestore.collection('products').doc(product['id'] as String);
          batch.set(docRef, product); // Direct set (no merge) to overwrite stale fields completely
          totalIngested++;
        }

        await batch.commit();
      }

      debugPrint('[DataSeeder] Ingested & synchronized $totalIngested active products to Firestore.');
    } finally {
      _isSeeding = false;
    }

    return totalIngested;
  }

  static String _resolveCategory(Map<String, dynamic> item) {
    final rawCat = (item['category'] ?? '').toString().toLowerCase();
    final type = (item['productType'] ?? '').toString().toLowerCase();
    final name = (item['name'] ?? '').toString().toLowerCase();

    if (type.contains('detergent') || type.contains('booster') || type.contains('dryer sheet') || name.contains('laundry')) {
      return 'Laundry Care';
    }
    if (type.contains('candle') || name.contains('candle') || name.contains('3-wick') || name.contains('single wick') || type.contains('holder') || type.contains('pedestal')) {
      return 'Candles';
    }
    if (type.contains('soap') || type.contains('sanitizer') || type.contains('pocketbac') || name.contains('soap') || name.contains('sanitizer') || name.contains('foaming') || name.contains('cleansing bar')) {
      return 'Hand Soaps & Sanitizers';
    }
    if (type.contains('wallflower') || type.contains('plug') || type.contains('room spray') || type.contains('diffuser') || type.contains('car') || name.contains('wallflower') || name.contains('room spray') || name.contains('car fragrance') || name.contains('car clip') || name.contains('diffuser')) {
      return 'Wallflowers & Diffusers';
    }
    if (type.contains('cologne') || type.contains('eau de parfum') || type.contains('perfume')) {
      return 'Fragrance';
    }
    if (rawCat.contains('men') || name.contains("men's") || name.contains('cologne')) {
      return "Men's Shop";
    }
    return 'Body Care';
  }
}
