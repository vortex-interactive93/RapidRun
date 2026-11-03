// Wrapper to enrich all category mappings across stores.
import 'dart:io';
import 'enrich_descriptions.dart' as enrich;

Future<void> main(List<String> args) async {
  final mappings = <String>[];
  final root = Directory('assets/stores');
  if (root.existsSync()) {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('_categories.json')) {
        mappings.add(entity.path.replaceAll('\\', '/'));
      }
    }
  }
  if (mappings.isEmpty) {
    stderr.writeln('No *_categories.json mapping files found.');
    exit(1);
  }
  final fullArgs = [
    for (final m in mappings) ...['--mapping', m],
    '--force',
    '--report',
    '--pretty',
    ...args,
  ];
  await enrich.main(fullArgs);
}
