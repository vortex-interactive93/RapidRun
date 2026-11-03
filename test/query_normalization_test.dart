import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/models/product.dart';
import 'package:rapidrun/services/product_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ProductSearchService.instance;
  const store = 'TestStore';

  final toiletPaper = Product(
    id: 'p1',
    name: 'Toilet Paper 12 Pack',
    store: store,
    category: 'household',
    subCategory: 'paper',
    price: 5.0,
    tags: const ['toilet paper'],
  );
  final paperTowel = Product(
    id: 'p2',
    name: 'Paper Towel Roll',
    store: store,
    category: 'household',
    subCategory: 'paper',
    price: 3.0,
    tags: const ['paper towel'],
  );

  setUp(() {
    service.setTestProducts(store, [toiletPaper, paperTowel]);
  });

  test('Hyphen normalization allows hyphenated query to match', () async {
    final results = await service.searchStore(
      store,
      'toilet-paper',
      boostPopularity: false,
      useCache: false,
    );
    expect(results.any((p) => p.id == 'p1'), isTrue);
  });

  test('Plural singular normalization collapses towels->towel', () async {
    final results = await service.searchStore(
      store,
      'paper towels',
      boostPopularity: false,
      useCache: false,
    );
    // Should prefer paper towel product first via prefix match.
    expect(results.first.id, 'p2');
  });
}
