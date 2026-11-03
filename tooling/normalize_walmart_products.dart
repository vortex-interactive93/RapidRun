import 'dart:convert';
import 'dart:io';

// Normalizes Walmart product JSON assets to match Aldi schema.
// Usage (from repo root):
//   dart run tooling/normalize_walmart_products.dart
// The script will:
//  * Iterate walmart product JSON files (excluding walmart_categories.json)
//  * Rename `image` -> `imageUrl`
//  * Add missing fields: id, description, benefits, price (numeric), unit, storeId, category, subCategory
//  * Derive id pattern: walmart_<base_name>_<index:000>
//  * Parse numeric price from strings like "current price $4.97" or "current price Now $3.96"
//  * Infer category/subCategory from filename using mapping below
//  * Leave unit/description/benefits null when unknown
//  * Attempt to extract a unit (e.g. "3 lb", "Each", "1 lb Container", "2 lb Bag") from the name if unit is null
//  * Generate a placeholder description when description is null
//  * Preserve original order by writing prettified JSON
// A backup of the original file is written with suffix .bak once (if not already present).

final walmartDir = Directory('assets/stores/walmart');

/// Mapping of filename stem (without 'walmart-' prefix) to category/subCategory pair.
final Map<String, ({String category, String subCategory})> categoryMap = {
  'fresh-fruit': (category: 'Fresh Produce', subCategory: 'Fresh Fruit'),
  'fresh-vegetables': (
    category: 'Fresh Produce',
    subCategory: 'Fresh Vegetables',
  ),
  'fresh-chicken': (category: 'Meat & Seafood', subCategory: 'Fresh Chicken'),
  'ground-beef': (category: 'Meat & Seafood', subCategory: 'Ground Beef'),
  'beef-steaks-beef-lamb': (
    category: 'Meat & Seafood',
    subCategory: 'Beef Steaks & Lamb',
  ),
  'beef-roast': (category: 'Meat & Seafood', subCategory: 'Beef Roast'),
  'pork': (category: 'Meat & Seafood', subCategory: 'Pork'),
  'turkey': (category: 'Meat & Seafood', subCategory: 'Turkey'),
  'ham': (category: 'Meat & Seafood', subCategory: 'Ham'),
  'bacon': (category: 'Meat & Seafood', subCategory: 'Bacon'),
  'sausages-bratwursts': (
    category: 'Meat & Seafood',
    subCategory: 'Sausages & Bratwursts',
  ),
  'hotdogs': (category: 'Meat & Seafood', subCategory: 'Hotdogs'),
  'fresh-fish': (category: 'Meat & Seafood', subCategory: 'Fresh Fish'),
  'crab-shellfish': (
    category: 'Meat & Seafood',
    subCategory: 'Crab & Shellfish',
  ),
  'fresh-seafood': (
    category: 'Meat & Seafood',
    subCategory: 'Fresh Seafood Variety',
  ),
  'prime-wagyu': (category: 'Meat & Seafood', subCategory: 'Prime & Wagyu'),
  'organic-plant-based-meat': (
    category: 'Meat & Seafood',
    subCategory: 'Organic & Plant-Based Meat',
  ),
  'frozen-chicken': (category: 'Meat & Seafood', subCategory: 'Frozen Chicken'),
  'frozen-seafood': (category: 'Meat & Seafood', subCategory: 'Frozen Seafood'),
};

void main() async {
  if (!walmartDir.existsSync()) {
    stderr.writeln('Directory not found: ${walmartDir.path}');
    exit(1);
  }

  final files =
      walmartDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .where((f) => !f.path.endsWith('walmart_categories.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stdout.writeln('No walmart product JSON files found.');
    return;
  }

  int totalUpdated = 0;

  for (final file in files) {
    final raw = await file.readAsString();
    late dynamic decoded;
    try {
      decoded = json.decode(raw);
    } catch (e) {
      stderr.writeln('Skipping (invalid JSON): ${file.path} - $e');
      continue;
    }
    if (decoded is! List) {
      stderr.writeln('Skipping (not a list): ${file.path}');
      continue;
    }

    final baseName = file.uri.pathSegments.last.replaceAll('.json', '');
    final stem = baseName.startsWith('walmart-')
        ? baseName.substring(8)
        : baseName;
    final mapping = categoryMap[stem];

    bool changed = false;

    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) continue;

      // Rename image -> imageUrl
      if (item.containsKey('image')) {
        item['imageUrl'] = item['image'];
        item.remove('image');
        changed = true;
      }

      // Normalize price
      final originalPrice = item['price'];
      double? numericPrice;
      if (originalPrice is String) {
        final match = RegExp(
          r'(\d+\.\d{1,2})',
        ).allMatches(originalPrice).lastOrNull;
        if (match != null) {
          try {
            numericPrice = double.parse(match.group(1)!);
          } catch (_) {}
        }
        // Additional patterns: $<int>, $<int>.<decimals>, standalone integers preceded by $
        if (numericPrice == null) {
          final dollarPattern = RegExp(r'\$\s*(\d+\.?\d{0,2})');
          final m = dollarPattern.firstMatch(originalPrice);
          if (m != null) {
            final g = m.group(1);
            if (g != null && g.isNotEmpty) {
              try {
                numericPrice = double.parse(
                  g.contains('.') ? g : g + (g.contains('.') ? '' : '.0'),
                );
              } catch (_) {}
            }
          }
        }
        // Fallback: first decimal or integer token that looks like a price and is preceded by words like 'price', 'was', 'now'
        if (numericPrice == null) {
          final contextual = RegExp(
            r'(?:price|was|now)\D+(\d+\.?\d{0,2})',
            caseSensitive: false,
          ).firstMatch(originalPrice);
          if (contextual != null) {
            final g = contextual.group(1);
            if (g != null) {
              try {
                numericPrice = double.parse(g.contains('.') ? g : g + '.0');
              } catch (_) {}
            }
          }
        }
      } else if (originalPrice is num) {
        numericPrice = originalPrice.toDouble();
      }
      if (numericPrice != null && originalPrice is String) {
        item['price'] = numericPrice; // replace with numeric
        changed = true;
      }

      // If price key missing or still not numeric, assign 0.0 sentinel to maintain schema and log for manual review
      if (!(item['price'] is num)) {
        item['price'] = 0.0;
        stdout.writeln(
          'MISSING_PRICE_ASSIGNED_ZERO: ${file.path}[$i] ${item['name']}',
        );
        changed = true;
      }

      // Add id
      if (!item.containsKey('id')) {
        final id = 'walmart_${stem}_${(i + 1).toString().padLeft(3, '0')}';
        item['id'] = id;
        changed = true;
      }

      // Ensure keys exist (leave null if unknown)
      item.putIfAbsent('description', () => null);
      item.putIfAbsent('benefits', () => null);
      item.putIfAbsent('unit', () => null);
      item['storeId'] = 'walmart';

      if (mapping != null) {
        item['category'] = mapping.category;
        item['subCategory'] = mapping.subCategory;
      } else {
        item.putIfAbsent('category', () => null);
        item.putIfAbsent('subCategory', () => null);
      }

      // Attempt unit extraction if still null
      if (item['unit'] == null && item['name'] is String) {
        final name = item['name'] as String;
        final extracted = _extractUnitFromName(name);
        if (extracted != null && extracted.isNotEmpty) {
          item['unit'] = extracted;
          changed = true;
        }
      }

      // Auto-generate placeholder description if null
      if (item['description'] == null && item['name'] is String) {
        final name = item['name'] as String;
        item['description'] =
            'Product: ' +
            name +
            '. Automatically generated placeholder description. Replace with real merchandising copy.';
        changed = true;
      }
    }

    if (changed) {
      final backup = File('${file.path}.bak');
      if (!backup.existsSync()) {
        await backup.writeAsString(raw);
      }
      // Write pretty JSON
      final encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(decoded) + '\n');
      totalUpdated++;
      stdout.writeln('Updated: ${file.path}');
    } else {
      stdout.writeln('No changes needed: ${file.path}');
    }
  }

  stdout.writeln(
    'Normalization complete. Files updated: $totalUpdated/${files.length}',
  );
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

// Heuristic unit extraction similar to simple parsing of trailing tokens after last comma
String? _extractUnitFromName(String name) {
  // If the name contains a comma, inspect the trailing segment
  String candidate = '';
  if (name.contains(',')) {
    candidate = name.split(',').last.trim();
  }
  final keywords = [
    'each',
    'lb',
    'bag',
    'bunch',
    'pack',
    'pk',
    'count',
    'ct',
    'tray',
    'container',
    'pint',
    'oz',
  ];
  bool plausible(String c) {
    if (c.isEmpty) return false;
    if (c.length > 35) return false;
    final l = c.toLowerCase();
    return keywords.any((k) => l.contains(k)) || RegExp(r'\d').hasMatch(l);
  }

  if (plausible(candidate)) {
    return candidate;
  }
  // Fallback: regex search inside full name
  final regex = RegExp(
    r'(\d+\s?(?:lb|lbs|oz|oz\.|pint|pints)\b(?:\s?(?:bag|pack|tray|container))?)',
    caseSensitive: false,
  );
  final m = regex.firstMatch(name);
  if (m != null) return m.group(0);
  // Another simple tokens pattern including 'each'
  final eachRegex = RegExp(r'\b(each)\b', caseSensitive: false);
  final m2 = eachRegex.firstMatch(name);
  if (m2 != null)
    return m2.group(0)![0].toUpperCase() +
        m2.group(0)!.substring(1).toLowerCase();
  return null;
}
