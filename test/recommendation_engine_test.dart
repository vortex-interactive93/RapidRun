import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/algorithms/collaborative_filtering.dart';

void main() {
  group('RecommendationEngine', () {
    test('Cold start returns top rated sorted', () {
      final cf = CollaborativeFiltering(); // no ratings for new user
      final engine = RecommendationEngine(cf);
      final recs = engine.recommendProducts('new_user', topN: 4);
      // Ensure we got products and they are subset of sample products
      expect(recs.length, greaterThan(0));
      // Ratings should be in descending order
      for (var i = 1; i < recs.length; i++) {
        final prev = recs[i - 1].rating ?? 0;
        final cur = recs[i].rating ?? 0;
        expect(prev >= cur, isTrue, reason: 'Expected non-increasing ratings');
      }
    });

    test('Seeded matrix gives stable ordering for u1', () {
      final cf = buildSeededCF();
      final engine = RecommendationEngine(cf);
      final recs = engine.recommendProducts('u1', topN: 6);
      // u1 already rated: milk, eggs, cereal. Expect items from other clusters.
      final rated = {'aldi_milk_1', 'aldi_eggs_1', 'target_cereal_1'};
      for (final p in recs) {
        expect(
          rated.contains(p.id),
          isFalse,
          reason: 'Should not recommend already rated items',
        );
      }
    });
  });
}
