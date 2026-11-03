import 'dart:convert';
import 'dart:io';

/// Validates all JSON product files in assets/stores/walmart against the expected schema.
/// Expected per product object:
///   id: string matching ^walmart_[a-z0-9\-_]+_\d{3}$
///   name: non-empty string
///   price: number
///   imageUrl: non-empty string (http...)
///   description: nullable
///   benefits: nullable
///   unit: nullable or string
///   storeId: 'walmart'
///   category: string (not enforced to a fixed list here)
///   subCategory: string
/// Extra keys are allowed but warned.
///
/// Exit code 0 if all pass, 1 if any errors.
Future<void> main(List<String> args) async {
  final dir = Directory('assets/stores/walmart');
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: ${dir.path}');
    exit(1);
  }
  // ID format: walmart_<file-slug>_NNN (3 digits)
  final idPattern = RegExp(r'^walmart_[a-z0-9-_]+_\d{3}$');
  final requiredKeys = {
    'id',
    'name',
    'price',
    'imageUrl',
    'description',
    'benefits',
    'unit',
    'storeId',
    'category',
    'subCategory',
  };
  var errorCount = 0;
  var fileCount = 0;
  var productCount = 0;
  final globalIds = <String>{};

  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.json')) continue;
    final fileName = entity.uri.pathSegments.isNotEmpty
        ? entity.uri.pathSegments.last
        : entity.path.split(Platform.pathSeparator).last;
    if (fileName == 'walmart_categories.json') {
      // Skip meta/category reference file.
      continue;
    }
    fileCount++;
    List<dynamic> data;
    try {
      data = jsonDecode(entity.readAsStringSync()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('[ERROR] ${entity.path}: not a JSON array -> $e');
      errorCount++;
      continue;
    }
    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      if (row is! Map) {
        stderr.writeln('[ERROR] ${entity.path}[$i]: not an object');
        errorCount++;
        continue;
      }
      productCount++;
      // Required keys
      for (final k in requiredKeys) {
        if (!row.containsKey(k)) {
          stderr.writeln('[ERROR] ${entity.path}[$i]: missing key "$k"');
          errorCount++;
        }
      }
      final id = row['id'];
      if (id is! String || id.isEmpty) {
        stderr.writeln('[ERROR] ${entity.path}[$i]: invalid id');
        errorCount++;
      } else {
        if (!idPattern.hasMatch(id)) {
          stderr.writeln(
            '[ERROR] ${entity.path}[$i]: id does not match pattern walmart_<slug>_NNN -> $id',
          );
          errorCount++;
        }
        if (!globalIds.add(id)) {
          stderr.writeln(
            '[ERROR] ${entity.path}[$i]: duplicate id globally -> $id',
          );
          errorCount++;
        }
      }
      final name = row['name'];
      if (name is! String || name.trim().isEmpty) {
        stderr.writeln('[ERROR] ${entity.path}[$i]: invalid name');
        errorCount++;
      }
      final price = row['price'];
      if (price is! num) {
        stderr.writeln('[ERROR] ${entity.path}[$i]: price not numeric');
        errorCount++;
      }
      final imageUrl = row['imageUrl'];
      if (imageUrl is! String || !imageUrl.startsWith('http')) {
        stderr.writeln('[ERROR] ${entity.path}[$i]: invalid imageUrl');
        errorCount++;
      }
      final storeId = row['storeId'];
      if (storeId != 'walmart') {
        stderr.writeln('[ERROR] ${entity.path}[$i]: storeId != walmart');
        errorCount++;
      }
      // Optional warnings
      final extraKeys = row.keys
          .where((k) => !requiredKeys.contains(k))
          .toList();
      if (extraKeys.isNotEmpty) {
        stderr.writeln(
          '[WARN] ${entity.path}[$i]: extra keys: ${extraKeys.join(', ')}',
        );
      }
    }
  }

  stdout.writeln('Validated $productCount products across $fileCount files.');
  if (errorCount > 0) {
    stderr.writeln('Validation failed with $errorCount error(s).');
    exit(1);
  } else {
    stdout.writeln('All Walmart product files passed validation.');
  }
}
