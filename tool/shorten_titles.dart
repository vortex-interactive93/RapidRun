import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

const String _forceFlag = 'force';
const String _dryRunFlag = 'dry-run';
const String _mappingFileArg = 'mapping';
const String _prettyFlag = 'pretty';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag(
      _forceFlag,
      abbr: 'f',
      help: 'Overwrite existing shortened titles.',
      negatable: false,
    )
    ..addFlag(
      _dryRunFlag,
      abbr: 'd',
      help: 'Print the changes without writing to files.',
      negatable: false,
    )
    ..addFlag(
      _prettyFlag,
      abbr: 'p',
      help: 'Pretty print the JSON output.',
      negatable: false,
    )
    ..addOption(
      _mappingFileArg,
      abbr: 'm',
      help: 'Path to the category mapping file.',
    );

  final argResults = parser.parse(arguments);

  final force = argResults[_forceFlag] as bool;
  final dryRun = argResults[_dryRunFlag] as bool;
  final pretty = argResults[_prettyFlag] as bool;
  final mappingFile = argResults[_mappingFileArg] as String?;

  if (mappingFile == null) {
    print('Usage: dart run tool/shorten_titles.dart --mapping <file>');
    print(parser.usage);
    exit(1);
  }

  final stopwatch = Stopwatch()..start();
  final processor = TitleShortener(
    force: force,
    dryRun: dryRun,
    pretty: pretty,
  );

  processor.process(mappingFile);

  stopwatch.stop();
  print('Title shortening complete in ${stopwatch.elapsedMilliseconds} ms');
  print('  filesProcessed: ${processor.filesProcessed}');
  print('  productsScanned: ${processor.productsScanned}');
  print('  productsUpdated: ${processor.productsUpdated}');
  print('  dryRun: ${processor.dryRun}');
}

class TitleShortener {
  final bool force;
  final bool dryRun;
  final bool pretty;

  int filesProcessed = 0;
  int productsScanned = 0;
  int productsUpdated = 0;

  TitleShortener({
    required this.force,
    required this.dryRun,
    required this.pretty,
  });

  void process(String mappingPath) {
    final mappingFile = File(mappingPath);
    if (!mappingFile.existsSync()) {
      print('Error: Mapping file not found at $mappingPath');
      exit(1);
    }

    final mappingData = jsonDecode(mappingFile.readAsStringSync()) as List;

    for (final category in mappingData) {
      final sections = category['sections'] as List?;
      if (sections == null) continue;

      for (final section in sections) {
        final productTypes = section['productTypes'] as List?;
        if (productTypes == null) continue;

        for (final productType in productTypes) {
          final filePath = productType['filePath'] as String?;
          final categoryName = productType['name'] as String?;
          if (filePath != null && categoryName != null) {
            _processProductFile(filePath, categoryName);
          }
        }
      }
    }
  }

  void _processProductFile(String path, String categoryName) {
    final file = File(path);
    if (!file.existsSync()) {
      print('WARN missing product file: $path');
      return;
    }

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      print('WARN empty product file: $path');
      return;
    }

    List<dynamic> products;
    try {
      products = jsonDecode(content) as List<dynamic>;
    } on FormatException catch (e) {
      print('ERROR parsing $path: $e');
      return;
    }

    bool fileUpdated = false;
    for (final product in products) {
      if (product is! Map<String, dynamic>) continue;
      productsScanned++;

      final currentName = product['name'] as String?;
      if (currentName == null) continue;

      // Restore original name from backup if it exists.
      // This is key to fixing the previous run's error.
      var originalName = product['originalName'] as String?;
      if (originalName != null) {
        product['name'] = originalName;
      } else {
        // If no backup, the current name is the original. Store it.
        originalName = currentName;
        product['originalName'] = originalName;
      }

      final brand = product['brand'] as String?;
      final shortenedName = _generateShortName(originalName, brand);

      // Only update if there's a change.
      if (product['shortName'] != shortenedName ||
          product['name'] != originalName) {
        product['name'] = originalName; // Ensure name is restored
        product['shortName'] = shortenedName;
        productsUpdated++;
        fileUpdated = true;
      }
    }

    if (fileUpdated && !dryRun) {
      final encoder = pretty
          ? const JsonEncoder.withIndent('  ')
          : const JsonEncoder();
      file.writeAsStringSync(encoder.convert(products));
    }
    filesProcessed++;
    print('[OK ] processed $path');
  }

  String _generateShortName(String title, String? brand) {
    // The short name is the brand if it exists, otherwise the full title.
    // This is a much safer and more descriptive approach.
    if (brand != null && brand.isNotEmpty) {
      return brand;
    }
    return title;
  }
}
