import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/models/product.dart';
import 'package:rapidrun/services/product_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search popularity boost', () {
    final service = ProductSearchService.instance;
    const store = 'TestStore';

    final p1 = Product(
      id: 'p1',
      name: 'Alpha Snack',
      store: store,
      category: 'snacks',
      subCategory: 'chips',
      price: 1.0,
      tags: const [],
    );
    final p2 = Product(
      id: 'p2',
      name: 'Alpha Snack Deluxe',
      store: store,
      category: 'snacks',
      subCategory: 'chips',
      price: 1.5,
      tags: const [],
    );

    setUp(() {
      service.setTestProducts(store, [p1, p2]);
    });

    test(
      'Without popularity override lexical ordering prefers shorter exact prefix',
      () async {
        final results = await service.searchStore(
          store,
          'alpha snack',
          boostPopularity: false,
          useCache: false,
        );
        expect(results.first.id, 'p1'); // baseline shorter name / higher score
      },
    );

    test(
      'With popularity override second product boosted above first',
      () async {
        final results = await service.searchStore(
          store,
          'alpha snack',
          boostPopularity: true,
          popularityOverride: const {'p2': 5.0},
          useCache: false,
        );
        expect(results.first.id, 'p2');
      },
    );
  });
}
