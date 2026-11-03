// File: tool/minify_catalogs.dart

import 'dart:convert';
import 'dart:io';

void main() async {
  final dir = Directory('assets/data');
  if (!dir.existsSync()) {
    print('Directory assets/data not found.');
    return;
  }

  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));

  for (final file in files) {
    try {
      final content = await file.readAsString();
      final dynamic decoded = jsonDecode(content);

      if (decoded is List) {
        // Writes each product on its own single line within a valid standard JSON array
        final buffer = StringBuffer('[\n');
        for (int i = 0; i < decoded.length; i++) {
          buffer.write('  ${jsonEncode(decoded[i])}');
          if (i < decoded.length - 1) buffer.write(',');
          buffer.write('\n');
        }
        buffer.write(']\n');

        await file.writeAsString(buffer.toString());
        print('⚡ Flattened ${file.path.split(Platform.pathSeparator).last} (${decoded.length} items)');
      }
    } catch (e) {
      print('❌ Failed processing ${file.path}: $e');
    }
  }

  print('\n✨ All catalog assets compressed to single-line format.');
}
