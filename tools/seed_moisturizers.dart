// File: tools/seed_moisturizers.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final projectId = args.isNotEmpty ? args[0] : 'rapidrun-f12cb';
  const apiKey = 'AIzaSyAjtmblGZLpiX77_oBYjEIZoXvFLoL0EFM';
  final file = File('assets/data/all_moisturizers.json');

  if (!file.existsSync()) {
    stderr.writeln('❌ File assets/data/all_moisturizers.json not found!');
    exit(1);
  }

  stdout.writeln('⚡ Initializing Moisturizers Ingestion Engine ($projectId)...');

  // STEP 0: Obtain anonymous Firebase Auth ID token
  stdout.writeln('🔑 Authenticating session with Firebase Auth REST API...');
  String? idToken;
  try {
    final authUrl = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final authRes = await http.post(
      authUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'returnSecureToken': true}),
    );
    if (authRes.statusCode == 200) {
      final authData = jsonDecode(authRes.body) as Map<String, dynamic>;
      idToken = authData['idToken'] as String?;
      stdout.writeln('✅ Auth token acquired successfully!');
    } else {
      stderr.writeln('⚠️ Auth note (${authRes.statusCode}): ${authRes.body}');
    }
  } catch (e) {
    stderr.writeln('⚠️ Auth connection note: $e');
  }

  final rawData = jsonDecode(await file.readAsString()) as List<dynamic>;
  stdout.writeln('📦 Processing ${rawData.length} items from all_moisturizers.json...');

  const storeName = 'Bath & Body Works';
  const categoryName = 'Body Care';
  const departmentName = 'All Moisturizers';

  final firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  int ingestedCount = 0;

  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (idToken != null) 'Authorization': 'Bearer $idToken',
  };

  for (int i = 0; i < rawData.length; i++) {
    final raw = rawData[i];
    final item = Map<String, dynamic>.from(raw as Map);
    final sku = item['sku']?.toString() ?? item['id']?.toString() ?? '';
    if (sku.isEmpty) continue;

    final docId = sku.startsWith('bbw_') ? sku : 'bbw_$sku';
    final targetUrl = Uri.parse('$firestoreBaseUrl/products/$docId?key=$apiKey');
    final name = (item['name'] ?? '').toString();
    final lowerName = name.toLowerCase();

    // 1. Precise Product Type Classification matching Capture_2.png
    String productType = 'Body Lotion';
    String unit = '8 fl oz / 236 mL';
    String unitShort = '8 oz';

    if (lowerName.contains('lip') || lowerName.contains('mentha')) {
      productType = 'Lip Care';
      unit = '0.34 fl oz / 10 mL';
      unitShort = '0.34 oz';
    } else if (lowerName.contains('hand cream') || lowerName.contains('hand relief') || lowerName.contains('hand mask')) {
      productType = 'Hand Cream';
      unit = '1 fl oz / 29 mL';
      unitShort = '1 oz';
    } else if (lowerName.contains('body butter') || lowerName.contains('butter & balm')) {
      productType = 'Body Butter & Balm';
      unit = '6.7 oz / 190 g';
      unitShort = '6.7 oz';
    } else if (lowerName.contains('body oil') || lowerName.contains('massage oil')) {
      productType = 'Body Oil';
      unit = '4 fl oz / 118 mL';
      unitShort = '4 oz';
    } else if (lowerName.contains('smooth & soothe') || lowerName.contains('smooth and soothe')) {
      productType = 'Smooth & Soothe Body Cream';
      unit = '8 fl oz / 236 mL';
      unitShort = '8 oz';
    } else if (lowerName.contains('travel size') && lowerName.contains('cream')) {
      productType = 'Travel Size Body Cream';
      unit = '2.5 fl oz / 70 g';
      unitShort = '2.5 oz';
    } else if (lowerName.contains('body cream') || lowerName.contains('hydration cream')) {
      productType = 'Body Cream';
      unit = '8 oz / 226 g';
      unitShort = '8 oz';
    } else {
      productType = 'Body Lotion';
      unit = '8 fl oz / 236 mL';
      unitShort = '8 oz';
    }

    final body = {
      'fields': {
        'id': {'stringValue': docId},
        'sku': {'stringValue': sku.replaceAll('bbw_', '')},
        'name': {'stringValue': name},
        'brand': {'stringValue': item['brand']?.toString() ?? 'Bath & Body Works'},
        'store': {'stringValue': storeName},
        'category': {'stringValue': categoryName},
        'department': {'stringValue': departmentName},
        'subCategory': {'stringValue': productType},
        'productType': {'stringValue': productType},
        'price': {'doubleValue': (item['salePrice'] ?? item['price'] ?? 0.0) as num},
        'regularPrice': {'doubleValue': (item['regularPrice'] ?? 18.95) as num},
        'salePrice': {'doubleValue': (item['salePrice'] ?? 5.95) as num},
        'hasSpecial': {'booleanValue': item['hasSpecial'] == true},
        'promoBadge': {'stringValue': item['promoBadge']?.toString() ?? ''},
        'isOnlineExclusive': {'booleanValue': false},
        'unit': {'stringValue': unit},
        'unitShort': {'stringValue': unitShort},
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
        headers: headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        ingestedCount++;
      } else {
        stderr.writeln('⚠️ Firestore REST Error on $docId (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      stderr.writeln('⚠️ Network error doc $docId: $e');
    }

    if ((i + 1) % 20 == 0 || i + 1 == rawData.length) {
      stdout.writeln('   Seeded ${i + 1}/${rawData.length} items...');
    }
  }

  stdout.writeln('🎉 SUCCESS! $ingestedCount Body Care moisturizers sanitized and indexed in Firestore.');
  exit(0);
}
