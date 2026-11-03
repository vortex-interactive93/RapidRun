// File: lib/services/bbw_catalog_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/product.dart';

class BBWCatalogService {
  BBWCatalogService._();
  static final BBWCatalogService instance = BBWCatalogService._();

  List<Product> _cached = const [];
  bool _loaded = false;

  List<Product> get products => _cached;

  Future<List<Product>> loadCatalog() async {
    if (_loaded) return _cached;
    try {
      final raw = await rootBundle.loadString(
        'assets/stores/bath_and_body_works/body_care/fragrance/fragrance.json',
      );
      final List<dynamic> list = json.decode(raw);
      _cached = list.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
      _loaded = true;
    } catch (e) {
      // Fallback safe graceful degrade
      _cached = const [];
    }
    return _cached;
  }

  Future<List<Product>> getEnrichedCatalog() => loadCatalog();
}
