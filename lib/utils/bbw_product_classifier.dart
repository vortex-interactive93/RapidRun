// File: lib/utils/bbw_product_classifier.dart

import 'bbw_taxonomy.dart';

class BbwProductClassifier {
  /// Evaluates an ingested JSON item across Name, URL, Category, and Unit
  /// using the single source of truth BbwTaxonomy.
  static List<String> classifyProduct(Map<String, dynamic> json) {
    return BbwTaxonomy.classifyProduct(json);
  }
}
