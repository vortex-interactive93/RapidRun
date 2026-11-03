import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/services/merge_utils.dart';

void main() {
  group('mergeFavorites', () {
    test('Union basic', () {
      final merged = mergeFavorites({'a', 'b'}, ['b', 'c']);
      expect(merged.containsAll({'a', 'b', 'c'}), isTrue);
      expect(merged.length, 3);
    });
    test('Empty remote', () {
      final merged = mergeFavorites({'a'}, []);
      expect(merged, {'a'});
    });
    test('Empty local', () {
      final merged = mergeFavorites({}, ['x']);
      expect(merged, {'x'});
    });
  });

  group('mergeCartQuantities', () {
    test('Prefers larger remote', () {
      final merged = mergeCartQuantities({'p1': 1}, {'p1': 3});
      expect(merged['p1'], 3);
    });
    test('Keeps larger local', () {
      final merged = mergeCartQuantities({'p1': 5}, {'p1': 2});
      expect(merged['p1'], 5);
    });
    test('Adds missing keys', () {
      final merged = mergeCartQuantities({'p1': 1}, {'p2': 2});
      expect(merged, {'p1': 1, 'p2': 2});
    });
    test('Filters zero / negative (defensive)', () {
      final merged = mergeCartQuantities({'p1': 1}, {'p2': 0, 'p3': -2});
      expect(merged, {'p1': 1});
    });
  });
}
