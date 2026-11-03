// Uses flutter_test (which bundles the Dart test framework) rather than the
// standalone `test` package entrypoint so we can run via `flutter test` without
// adding an explicit dev_dependency on `test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/utils/multipack_detection.dart';

void main() {
  group('Multipack detection positive cases', () {
    final positives = <List<String?>>[
      ['(3 pack) Fancy Towels', null],
      ['Great Value 12 pk Bottled Water', null],
      ['Value Pack Toothbrushes', null],
      ['Some Brand pack of 4 Bars', null],
      ['Twin Pack Deodorant', null],
      ['Triple Pack Snacks', null],
      ['Quad Pack Light Bulbs', null],
      ['(2-pack) Sponges', null],
    ];
    for (final p in positives) {
      test('Detects "${p[0]}"', () {
        expect(isMultipackName(p[0], p[1]), isTrue);
      });
    }
  });

  group('Multipack detection negative cases', () {
    final negatives = <List<String?>>[
      ['Family Size Cereal', null],
      ['Party Size Chips 18oz', null],
      ['Bulk Rice 20 lb', null],
      ['Multipurpose Cleaner 2x Strength', null],
      ['Single Serve Oatmeal', null],
      ['(Value size) Laundry Detergent', null],
    ];
    for (final n in negatives) {
      test('Does NOT detect "${n[0]}"', () {
        expect(isMultipackName(n[0], n[1]), isFalse);
      });
    }
  });
}
