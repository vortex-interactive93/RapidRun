import 'dart:math';
import '../models/product.dart';

/// Lightweight in-memory collaborative filtering (user-item) prototype.
/// Not production-grade; aims to provide deterministic sample recommendations
/// until backend / Firestore driven signals are wired in.
class CollaborativeFiltering {
  /// userId -> map(productId -> rating 1-5)
  final Map<String, Map<String, double>> userRatings;

  CollaborativeFiltering({Map<String, Map<String, double>>? seed})
    : userRatings = seed ?? {};

  void addRating(String userId, String productId, double rating) {
    final r = rating.clamp(1, 5);
    userRatings.putIfAbsent(userId, () => {})[productId] = r.toDouble();
  }

  /// Returns top-N recommended product IDs for the target user.
  List<String> recommend(String userId, {int topN = 6}) {
    if (!userRatings.containsKey(userId) || userRatings[userId]!.isEmpty) {
      // Cold start: return top-rated globally
      return _topRatedProducts(limit: topN);
    }

    final targetRatings = userRatings[userId]!;
    // Compute similarity between target user and all other users (cosine)
    final similarities = <String, double>{};
    userRatings.forEach((otherUser, ratings) {
      if (otherUser == userId) return;
      final sim = _cosineSimilarity(targetRatings, ratings);
      if (sim > 0) similarities[otherUser] = sim;
    });

    if (similarities.isEmpty) {
      return _topRatedProducts(limit: topN);
    }

    // Score unseen products via weighted sum of neighbor ratings * similarity
    final scores = <String, double>{};
    for (final entry in similarities.entries) {
      final neighborUser = entry.key;
      final weight = entry.value;
      userRatings[neighborUser]!.forEach((pid, rating) {
        if (targetRatings.containsKey(pid)) return; // already rated/seen
        scores.update(
          pid,
          (v) => v + rating * weight,
          ifAbsent: () => rating * weight,
        );
      });
    }

    if (scores.isEmpty) {
      return _topRatedProducts(limit: topN);
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(topN).map((e) => e.key).toList();
  }

  double _cosineSimilarity(Map<String, double> a, Map<String, double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (final entry in a.entries) {
      final rA = entry.value;
      normA += rA * rA;
      final rB = b[entry.key];
      if (rB != null) {
        dot += rA * rB;
      }
    }
    for (final r in b.values) {
      normB += r * r;
    }
    if (dot == 0 || normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  List<String> _topRatedProducts({int limit = 6}) {
    // For now just sample from repository highest rating
    final prods = ProductRepository.sampleProducts;
    final sorted = [...prods]
      ..sort((a, b) {
        final ar = a.rating ?? 0;
        final br = b.rating ?? 0;
        final cmp = br.compareTo(ar);
        if (cmp != 0) return cmp;
        return a.name.compareTo(b.name);
      });
    return sorted.take(limit).map((p) => p.id).toList();
  }
}

/// Simple facade combining model scoring with product lookup.
class RecommendationEngine {
  final CollaborativeFiltering cf;
  RecommendationEngine(this.cf);

  List<Product> recommendProducts(String userId, {int topN = 6}) {
    final ids = cf.recommend(userId, topN: topN);
    final all = {for (final p in ProductRepository.sampleProducts) p.id: p};
    return ids.map((id) => all[id]).whereType<Product>().toList();
  }
}

/// Seed helper building a deterministic mini user ratings matrix.
CollaborativeFiltering buildSeededCF() {
  final cf = CollaborativeFiltering();
  // Users u1-u4 with overlapping tastes
  cf.addRating('u1', 'aldi_milk_1', 5);
  cf.addRating('u1', 'aldi_eggs_1', 4);
  cf.addRating('u1', 'target_cereal_1', 4);

  cf.addRating('u2', 'aldi_milk_1', 4);
  cf.addRating('u2', 'target_cereal_1', 5);
  cf.addRating('u2', 'target_shampoo_1', 4);

  cf.addRating('u3', 'target_shampoo_1', 5);
  cf.addRating('u3', 'bbw_lotion_1', 5);
  cf.addRating('u3', 'restaurant_burger_1', 3);

  cf.addRating('u4', 'restaurant_burger_1', 5);
  cf.addRating('u4', 'restaurant_salad_1', 4);
  cf.addRating('u4', 'aldi_eggs_1', 3);

  return cf;
}
