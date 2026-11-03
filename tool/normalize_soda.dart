import 'dart:convert';
import 'dart:io';

/// Normalizes the walmart soda asset file to the standard product schema used
/// elsewhere in the project.
///
/// Input objects (raw) look like:
/// { "image": "url", "name": "...", "price": "current price Now $1.00" }
///
/// Output objects:
/// {
///   "id": "walmart_soda_0001",
///   "name": "...",                 // original name preserved
///   "brand": "...",                // heuristic extraction
///   "price": 1.00,                  // numeric
///   "imageUrl": "url",
///   "description": null,            // left null for later enrichment
///   "benefits": null,
///   "unit": "12 pack" | "2 L" | null,
///   "storeId": "walmart",
///   "category": "Grocery",
///   "subCategory": "Soda",
///   "shortName": "..."             // concise variant
/// }
///
/// Run with:
///   dart tool/normalize_soda.dart [--update]
/// If --update provided, will re-process even if file appears normalized
/// (Re-writes assets/stores/walmart/soda.json)
void main(List<String> args) async {
  final allowUpdate = args.contains('--update');
  final report = args.contains('--report');
  final file = File('assets/stores/walmart/soda.json');
  if (!await file.exists()) {
    stderr.writeln('soda.json not found');
    exit(1);
  }
  final raw = await file.readAsString();
  dynamic data;
  try {
    data = json.decode(raw);
  } catch (e) {
    stderr.writeln('Failed to parse JSON: $e');
    exit(1);
  }
  if (data is! List) {
    stderr.writeln('Expected top-level array');
    exit(1);
  }

  // Detect if already normalized (presence of id & imageUrl keys).
  final alreadyNormalized =
      data.isNotEmpty &&
      data.first is Map &&
      (data.first as Map).containsKey('id');
  if (alreadyNormalized && !allowUpdate) {
    stdout.writeln(
      'soda.json appears already normalized; pass --update to rebuild.',
    );
    return;
  }

  final List<Map<String, dynamic>> normalized = [];
  int brandVariantTrims = 0;
  int shortNameDuplicateCollapses = 0;
  final seenKeys = <String>{};
  int index = 1;
  for (final item in data) {
    if (item is! Map) continue;
    final name = (item['name'] ?? '').toString().trim();
    // Support both raw ('image') and already-normalized ('imageUrl') sources.
    final image = (item['image'] ?? item['imageUrl'] ?? '').toString().trim();
    final priceStr = (item['price'] ?? '').toString();

    // Extract numeric price (first number with optional decimals).
    final priceMatch = RegExp(r'(\d+\.\d+|\d+)').firstMatch(priceStr);
    final price = priceMatch != null
        ? double.parse(priceMatch.group(0)!)
        : null;

    final brand = _extractBrand(
      name,
      onVariantTrimmed: () => brandVariantTrims++,
    );
    final unit = _extractUnit(name);

    final id = 'walmart_soda_${index.toString().padLeft(4, '0')}';
    index++;

    final key = '$name|$image|$price';
    if (seenKeys.contains(key)) {
      // Skip exact duplicate entries.
      continue;
    }
    seenKeys.add(key);

    final shortName = _generateShortName(
      name,
      brand: brand,
      unit: unit,
      onDuplicateCollapse: () => shortNameDuplicateCollapses++,
    );

    final existingDescription = item['description'];
    normalized.add({
      'id': id,
      'name': name,
      'brand': brand,
      'price': price,
      'imageUrl': image,
      // Preserve prior description if present (avoid wiping enriched text on --update)
      'description':
          (existingDescription is String &&
              existingDescription.trim().isNotEmpty)
          ? existingDescription
          : null,
      'benefits': null,
      'unit': unit,
      'storeId': 'walmart',
      'category': 'Grocery',
      'subCategory': 'Soda',
      'shortName': shortName,
      'originalName': name,
    });
  }

  // Write pretty JSON.
  final encoder = const JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(normalized) + '\n');
  stdout.writeln(
    'Normalized ${normalized.length} soda items → assets/stores/walmart/soda.json',
  );
  if (report) {
    stdout.writeln(
      '[normalize_soda] variantTrims=$brandVariantTrims shortNameDuplicateCollapses=$shortNameDuplicateCollapses',
    );
  }
}

String? _extractBrand(String name, {void Function()? onVariantTrimmed}) {
  if (name.isEmpty) return null;
  final head = name.split(',').first.trim();
  final tokens = head.split(RegExp(r'\s+'));
  if (tokens.isEmpty) return null;
  final out = <String>[];
  for (final raw in tokens) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9&\-]'), '');
    if (cleaned.isEmpty) continue;
    final lower = cleaned.toLowerCase();
    if (out.isNotEmpty &&
        (_genericStopTokens.contains(lower) ||
            RegExp(r'^[0-9]').hasMatch(lower)))
      break;
    out.add(cleaned);
    // Special multi-word brand keep both words
    if (out.length >= 3) break; // cap
  }
  // Merge known two-word brands if split (Great Value, Dr Pepper, Mountain Dew, Canada Dry, Big Red, Root Beer treat only A&W root? we keep A&W separate)
  if (out.length >= 2) {
    final firstTwo = '${out[0]} ${out[1]}'.toLowerCase();
    if (_knownTwoWordBrands.contains(firstTwo)) {
      return out.take(2).join(' ');
    }
  }
  // Remove variant / flavor token if it accidentally became part of brand (e.g. "Coca-Cola Classic" -> "Coca-Cola")
  if (out.length >= 2) {
    final secondLower = out[1].toLowerCase();
    if (_variantTokens.contains(secondLower)) {
      out.removeRange(1, out.length); // keep only the core brand token
      onVariantTrimmed?.call();
    }
  }
  // Trim trailing generic tokens
  while (out.isNotEmpty && _genericTrail.contains(out.last.toLowerCase())) {
    out.removeLast();
  }
  if (out.isEmpty) return null;
  return out.join(' ');
}

String _generateShortName(
  String name, {
  String? brand,
  String? unit,
  void Function()? onDuplicateCollapse,
}) {
  if (name.isEmpty) return name;
  String working = name;
  if (brand != null && brand.isNotEmpty) {
    final pattern = RegExp(
      '^' + RegExp.escape(brand) + r'[,\s]+',
      caseSensitive: false,
    );
    working = working.replaceFirst(pattern, '');
  }
  // Remove commas -> split tokens
  final rawTokens = working.split(RegExp(r'[\s,]+'));
  final filtered = <String>[];
  for (final t in rawTokens) {
    final lower = t.toLowerCase();
    if (_genericNoise.contains(lower)) continue;
    if (RegExp(r'^(cans?|bottles?)$').hasMatch(lower)) continue;
    if (RegExp(r'^pack$', caseSensitive: false).hasMatch(lower)) continue;
    filtered.add(t);
  }
  // Re-add brand at front
  final pieces = <String>[];
  if (brand != null && brand.isNotEmpty) pieces.add(brand);
  // Flavor / variant tokens until we hit size indicators
  for (final t in filtered) {
    final lower = t.toLowerCase();
    if (_sizeIndicators.contains(lower) || RegExp(r'^[0-9]').hasMatch(lower))
      break;
    pieces.add(t);
    if (pieces.length >= 5) break; // cap length
  }
  // Append unit summary
  if (unit != null && unit.isNotEmpty) {
    final packMatch = RegExp(r'^(\d+) pack').firstMatch(unit);
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?) (fl oz|oz|l|liter)');
    final sm = sizeMatch.firstMatch(unit.toLowerCase());
    var packStr = '';
    if (packMatch != null) packStr = packMatch.group(1)! + 'pk';
    var sizeStr = '';
    if (sm != null) {
      var num = sm.group(1)!;
      var u = sm.group(2)!;
      if (u == 'liter') u = 'L';
      sizeStr = num + (u == 'fl oz' ? 'oz' : u);
    }
    final tail = [
      if (packStr.isNotEmpty) packStr,
      if (sizeStr.isNotEmpty) sizeStr,
    ].join(' ');
    if (tail.isNotEmpty) pieces.add(tail);
  }
  // Collapse adjacent duplicate tokens (case-insensitive)
  final collapsed = <String>[];
  for (final p in pieces) {
    if (collapsed.isNotEmpty &&
        collapsed.last.toLowerCase() == p.toLowerCase()) {
      onDuplicateCollapse?.call();
      continue;
    }
    collapsed.add(p);
  }
  var shortName = collapsed.join(' ');
  if (shortName.length > 64) shortName = shortName.substring(0, 64).trim();
  return shortName;
}

String? _extractUnit(String name) {
  // Look for pack counts like '12 Pack', '24 Pack Cans', '6 Pack Bottles'
  final packMatch = RegExp(
    r'(\d+)\s*(Pack|Count|pack|count)(?:\s*(Cans|Bottles|Mini|Mini Cans|Cans))?',
  ).firstMatch(name);
  final sizeMatch = RegExp(
    r'(\d+(?:\.\d+)?)\s*(fl oz|oz|L|Liter|ml|QT|qt)',
  ).firstMatch(name);
  String? pack;
  if (packMatch != null) {
    pack = '${packMatch.group(1)} pack';
  }
  String? size;
  if (sizeMatch != null) {
    size = '${sizeMatch.group(1)} ${sizeMatch.group(2)}';
  }
  if (pack != null && size != null) return '$pack / $size';
  return pack ?? size;
}

const _sizeIndicators = {
  'fl',
  'fl.',
  'oz',
  'pack',
  'packs',
  'count',
  'bottles',
  'cans',
  'liter',
  'liters',
  'l',
  'ml',
  'qt',
  'gallon',
};

const _genericStopTokens = {
  'soda',
  'pop',
  'cola',
  'drink',
  'soft',
  'fridge',
  'root',
  'beer',
  'mini',
  'zero',
  'sugar',
  'diet',
  'caffeine',
  'free',
};
const _genericTrail = {
  'soda',
  'pop',
  'cola',
  'drink',
  'soft',
  'fridge',
  'pack',
  'mini',
};
const _genericNoise = {
  'soda',
  'pop',
  'cola',
  'drink',
  'soft',
  'fridge',
  'pack',
  'mini',
  'cans',
  'can',
  'bottle',
  'bottles',
  'the',
};
const _knownTwoWordBrands = {
  'great value',
  'dr pepper',
  'dr thunder',
  'mountain dew',
  'canada dry',
  'big red',
  "sam's choice",
  "sam's cola",
};

// Single word tokens that should not extend the core brand when appearing
// immediately after the first token (flavors, variants, generic descriptors)
const _variantTokens = {
  'classic',
  'cream',
  'zero',
  'diet',
  'cherry',
  'vanilla',
  'original',
  'sugar',
  'free',
  'caffeine',
  'based',
  'prebiotic',
  'fuel',
  'cold',
  'thunder',
  'lime',
  'lemon',
  'plant',
  'matcha',
  'nutritional',
  'instant',
  'general',
  'wellness',
  'shake',
  'grape',
};
