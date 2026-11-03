import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/utils/password_strength.dart';

void main() {
  group('Password strength', () {
    test('Empty', () {
      final s = evaluatePassword('');
      expect(s.score, 0);
    });
    test('Weak short', () {
      final s = evaluatePassword('abc');
      expect(s.score, lessThanOrEqualTo(1));
    });
    test('Mixed good', () {
      final s = evaluatePassword('Abcdef12');
      expect(s.score, greaterThanOrEqualTo(3));
    });
    test('Strong long complex', () {
      final s = evaluatePassword('AbcdEF12!@');
      expect(s.score, 4);
    });
  });
}
