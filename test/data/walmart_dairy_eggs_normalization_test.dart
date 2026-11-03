import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No duplicate normalized names in Walmart dairy & eggs related files', () {
    final dir = Directory('assets/stores/walmart');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'Walmart assets directory missing',
    );

    final targetPattern = RegExp(
      r'^walmart-(milk|non-dairy-milk|yogurt|cheese|cream-cheese|cream-and-creamers|butter-margarine|sourcream-dips|eggs|pudding-and-desserts)(-part\d+)?\.json$',
    );

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => targetPattern.hasMatch(f.uri.pathSegments.last))
        .toList();

    for (final file in files) {
      final content = file.readAsStringSync();
      List<dynamic> data;
      try {
        data = json.decode(content) as List<dynamic>;
      } catch (e) {
        fail('Invalid JSON in ${file.path}: $e');
      }
      final seen = <String, int>{};
      int index = 0;
      for (final item in data) {
        if (item is! Map) {
          index++;
          continue;
        }
        final name = (item['name'] ?? '').toString();
        if (name.isEmpty) {
          index++;
          continue;
        }
        final norm = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (seen.containsKey(norm)) {
          fail(
            'Duplicate product (normalized) name "${norm}" in ${file.path} at indices ${seen[norm]} and $index',
          );
        }
        seen[norm] = index;
        index++;
      }
    }
  });
}
