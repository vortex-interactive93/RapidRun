import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/models/product.dart';
import 'package:rapidrun/services/product_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ProductSearchService.instance;
  const store = 'FuzzyStore';

  final chips = Product(
    id: 'c1',
    name: 'Crunchy Chips',
    store: store,
    category: 'snacks',
    subCategory: 'chips',
    price: 2.0,
    tags: const ['chips'],
  );

  setUp(() {
    service.setTestProducts(store, [chips]);
  });

  test('Exact query returns result without fuzzy', () async {
    final r = await service.searchStore(
      store,
      'chips',
      enableFuzzy: false,
      boostPopularity: false,
      useCache: false,
    );
    expect(r, isNotEmpty);
  });

  test('Slight misspelling only matches with fuzzy enabled', () async {
    final miss = 'chipz'; // edit distance 1 from 'chips'
    final noFuzzy = await service.searchStore(
      store,
      miss,
      enableFuzzy: false,
      boostPopularity: false,
      useCache: false,
    );
    expect(noFuzzy, isEmpty);
    final yesFuzzy = await service.searchStore(
      store,
      miss,
      enableFuzzy: true,
      boostPopularity: false,
      useCache: false,
    );
    expect(yesFuzzy.any((p) => p.id == 'c1'), isTrue);
  });
}
