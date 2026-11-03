import 'dart:convert';
import 'dart:io';

// Normalizes Walmart Bath & Body related JSON files to the canonical product schema
// similar to bacon.json.
// Fields produced per item:
//  id, name, price (double), imageUrl, description, benefits, unit, storeId, category, subCategory
// Skips entries missing either name or an image field (image/imageUrl).
// Attempts to extract a unit token from the name (oz, fl oz, g, ml, lb, count, ct) if present.
// Price strings like "current price Now $5.97" or "current price $5.97" are parsed to 5.97.

final bathBodyFiles = <String>[
  'exfoliators.json',
  'hand-sanitizers.json',
  'hand-soaps.json',
  'self-tanners-bronzers.json',
  'bar-soaps.json',
  'bath-bombs.json',
  'bathing-supplies.json',
  'body-lotions-butters.json',
];

final directory = Directory('assets/stores/walmart');

void main() async {
  if (!directory.existsSync()) {
    stderr.writeln('Directory not found: ${directory.path}');
    exit(1);
  }
  int globalIndex = 1;
  for (final fileName in bathBodyFiles) {
    final file = File('${directory.path}/$fileName');
    if (!file.existsSync()) {
      stderr.writeln('Missing file: $fileName (skipping)');
      continue;
    }
    List<dynamic> raw;
    try {
      raw = json.decode(await file.readAsString()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Failed to decode $fileName: $e');
      continue;
    }

    final seen = <String>{}; // dedupe by name+image
    final normalized = <Map<String, dynamic>>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final name = (map['name'] ?? '').toString().trim();
      final image = (map['image'] ?? map['imageUrl'] ?? '').toString().trim();
      if (name.isEmpty || image.isEmpty) continue; // skip incomplete

      final signature = '$name::$image';
      if (!seen.add(signature)) continue; // dedupe

      final priceVal = _parsePrice(map['price']);
      final unit = _extractUnit(name);
      final id = 'walmart_bath_body_${globalIndex.toString().padLeft(4, '0')}';
      globalIndex++;

      normalized.add({
        'name': name,
        'price': priceVal,
        'imageUrl': image,
        'id': id,
        'description': map['description'],
        'benefits': map['benefits'],
        'unit': unit,
        'storeId': 'walmart',
        'category': 'Personal Care',
        'subCategory': 'Bath & Body',
      });
    }

    // Overwrite original file with normalized content.
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized),
    );
    stdout.writeln('Normalized ${normalized.length} items in $fileName');
  }
}

double? _parsePrice(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  final s = raw.toString();
  final regex = RegExp(r'(\d+[\.,]?\d*)');
  double? last;
  for (final m in regex.allMatches(s)) {
    final val = m.group(1)!.replaceAll(',', '');
    final parsed = double.tryParse(val);
    if (parsed != null) last = parsed; // take last number in string
  }
  return last;
}

String? _extractUnit(String name) {
  final lower = name.toLowerCase();
  final unitRegex = RegExp(
    r'(\b\d+(?:\.\d+)?\s?(?:fl\.?\s?oz|oz|g|ml|lb|lbs|count|ct)\b)',
  );
  final matches = unitRegex.allMatches(lower).toList();
  if (matches.isEmpty) return null;
  return matches.last.group(1);
}
