/// Normalizes legacy pharmacy / health product JSON files to canonical structure.
///
/// Usage:
///   dart run tool/normalize_pharmacy_assets.dart <file1.json> <file2.json> ... [--force] [--dry-run]
///
/// For each input file (an array of product objects with minimal fields like
///   { "image": "...", "name": "...", "price": "current price Now $12.88" }
/// it will:
///   - Deduplicate entries by (name,imageUrl)
///   - Add stable deterministic ids: walmart_<basename>_NNN
///   - Extract numeric price into `price` (double)
///   - Create `displayPrice` (e.g. $12.88)
///   - Rename `image` -> `imageUrl`
///   - Infer `brand` (heuristic list) if absent
///   - Attempt to extract a unit string (e.g. "90 ct", "15.22 fl oz") into `unit`
///   - Add `storeId`: "walmart" if missing
///   - Preserve pre-existing canonical fields (id/price etc.) unless --force passed
///
/// Skips records already possessing an `id` unless --force.
/// Writes files in-place (pretty JSON). Use --dry-run to preview actions.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final force = args.contains('--force');
  final dryRun = args.contains('--dry-run');
  final files = args.where((a) => !a.startsWith('--')).toList();
  if (files.isEmpty) {
    stderr.writeln('No input files provided.');
    exit(1);
  }

  for (final path in files) {
    await _processFile(path, force: force, dryRun: dryRun);
  }
}

Future<void> _processFile(
  String path, {
  required bool force,
  required bool dryRun,
}) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('WARN missing file: $path');
    return;
  }
  late final List data;
  try {
    data = jsonDecode(await file.readAsString()) as List;
  } catch (e) {
    stderr.writeln('ERROR parsing $path: $e');
    return;
  }
  final baseName = file.uri.pathSegments.last.replaceAll('.json', '');
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  int index = 0;
  int modified = 0;
  for (final raw in data) {
    if (raw is! Map) continue;
    final original = Map<String, dynamic>.from(raw);
    final alreadyCanonical = original.containsKey('id') && !force;
    if (alreadyCanonical) {
      // still normalize price/image name fields if lightly off
      _ensureDisplayPrice(original);
      final key = _dedupeKey(original);
      if (seen.add(key)) out.add(original);
      continue;
    }
    index += 1;
    final norm = <String, dynamic>{};
    final name = _asString(original['name']) ?? 'Unnamed';
    norm['name'] = name;
    // Deterministic id across runs based on order after dedupe.
    final id = 'walmart_${baseName}_${index.toString().padLeft(3, '0')}';
    norm['id'] = id;
    // Price handling
    final priceTuple = _extractPrice(original['price']);
    final price = priceTuple?.item1;
    final displayPrice = priceTuple?.item2 ?? '';
    if (price != null) norm['price'] = price;
    norm['displayPrice'] = displayPrice;
    // Image rename
    final imageUrl =
        _asString(original['image']) ?? _asString(original['imageUrl']) ?? '';
    if (imageUrl.isNotEmpty) norm['imageUrl'] = imageUrl;
    // Brand inference
    final brand = _inferBrand(name);
    if (brand != null) norm['brand'] = brand;
    // Unit extraction
    final unit = _extractUnit(name);
    if (unit != null) norm['unit'] = unit;
    norm['storeId'] = 'walmart';
    // Keep any unknown extra fields (except ones we replaced)
    for (final e in original.entries) {
      if (norm.containsKey(e.key)) continue;
      if (e.key == 'image') continue; // renamed
      if (e.key == 'price') continue; // rewired
      norm[e.key] = e.value;
    }
    final key = _dedupeKey(norm);
    if (!seen.add(key)) {
      continue; // duplicate
    }
    out.add(norm);
    modified += 1;
  }
  if (dryRun) {
    stdout.writeln(
      '[DRY-RUN] $path would write ${out.length} records (modified: $modified, was: ${data.length})',
    );
    return;
  }
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(out) + '\n');
  stdout.writeln(
    'Normalized $path -> ${out.length} records (modified: $modified, was: ${data.length})',
  );
}

String _dedupeKey(Map<String, dynamic> m) =>
    '${m['name']}|${m['imageUrl'] ?? ''}';

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num) return v.toString();
  return v.toString();
}

class _PriceTuple {
  final double item1;
  final String item2;
  _PriceTuple(this.item1, this.item2);
}

_PriceTuple? _extractPrice(dynamic priceRaw) {
  if (priceRaw == null) return null;
  if (priceRaw is num) {
    final d = priceRaw.toDouble();
    return _PriceTuple(d, _formatPrice(d));
  }
  final s = priceRaw.toString();
  final match = RegExp(r'(\d+\.?\d*)').firstMatch(s);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;
  return _PriceTuple(value, _formatPrice(value));
}

String _formatPrice(double value) =>
    '\$${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

void _ensureDisplayPrice(Map<String, dynamic> m) {
  if (m.containsKey('displayPrice')) return;
  final price = m['price'];
  if (price is num) {
    m['displayPrice'] = _formatPrice(price.toDouble());
  }
}

final List<String> _brandList = [
  // Longer / multi-word first for greedy match
  "Garden of Life",
  "The Relief Products",
  "Nature's Bounty",
  "Nature's Way",
  "Spring Valley",
  "One A Day",
  "MaryRuth's",
  "MaryRuth",
  "Centrum Silver",
  "Centrum Multi Plus Beauty",
  "Centrum Multigummies",
  "Centrum",
  "Equate",
  "OLLY",
  "Neuriva",
  "vitafusion",
  "Lil Critters",
  "Ocuvite",
];

String? _inferBrand(String name) {
  final lower = name.toLowerCase();
  for (final b in _brandList) {
    if (lower.startsWith(b.toLowerCase())) return b;
  }
  // Fallback: First token capitalized (excluding numbers & common words)
  final firstWord = name
      .split(RegExp(r'\s+'))
      .firstWhere((w) => w.isNotEmpty, orElse: () => '');
  if (firstWord.isEmpty) return null;
  if (firstWord.length < 3) return null;
  if (RegExp(r'^[0-9]').hasMatch(firstWord)) return null;
  return firstWord;
}

final _unitRegexes = [
  RegExp(r'(\b\d+(?:\.\d+)?\s?(?:fl ?oz|oz|ml|g|lb)\b)', caseSensitive: false),
  RegExp(r'(\b\d+\s?(?:ct|count)\b)', caseSensitive: false),
];

String? _extractUnit(String name) {
  for (final r in _unitRegexes) {
    final m = r.firstMatch(name);
    if (m != null) return m.group(1);
  }
  return null;
}
