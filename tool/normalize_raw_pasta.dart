import 'dart:convert';
import 'dart:io';

// Normalizes assets/stores/walmart/pasta.json (raw format with image/name/price strings)
// into the standard schema and overwrites the same file.
// Schema: id, name, price (num), imageUrl, description, benefits, unit, storeId, category, subCategory

final priceRegex = RegExp(r'(\d+\.\d{1,2})');
final unitRegex = RegExp(
  r'(\b\d+(?:\.\d+)?)(?:\s?)(oz|OZ|Oz|lb|LB|Lb|oz\sBox|oz\sBag|oz\sPouch|oz\sPack|Oz\sPack|oz\sPlastic\sPackage|oz\sPlastic\sPouch|oz\sCardboard\sBox|oz\sBag)',
);
final compactUnitRegex = RegExp(r'(\d+(?:\.\d+)?)(oz)');

String? extractUnit(String name) {
  var m = unitRegex.allMatches(name).toList();
  if (m.isEmpty) {
    final c = compactUnitRegex.firstMatch(name);
    if (c != null) {
      return '${c.group(1)} oz';
    }
    return null;
  }
  // prefer last occurrence
  final last = m.last;
  var number = last.group(1)!;
  var unit = last.group(2)!;
  unit = unit.toLowerCase();
  if (unit.startsWith('oz')) unit = 'oz';
  if (unit.contains('box')) unit = '${number} oz Box';
  if (unit.contains('bag') && !unit.contains('box')) unit = '${number} oz Bag';
  if (unit.contains('pouch')) unit = '${number} oz Pouch';
  if (unit.contains('pack') && !unit.contains('mega'))
    unit = '${number} oz Pack';
  if (unit == 'lb') return '$number lb';
  return '$number oz';
}

num? parsePrice(dynamic raw) {
  if (raw is num) return raw;
  if (raw is String) {
    final match = priceRegex.firstMatch(raw.replaceAll(',', ''));
    if (match != null) {
      return num.parse(match.group(1)!);
    }
  }
  return null;
}

Future<void> main() async {
  final file = File('assets/stores/walmart/pasta.json');
  if (!file.existsSync()) {
    stderr.writeln('Raw pasta.json not found');
    exit(1);
  }
  final raw = jsonDecode(await file.readAsString());
  if (raw is! List) {
    stderr.writeln('Raw pasta.json not an array');
    exit(1);
  }
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = (item['name'] ?? '').toString().trim();
    final img = (item['image'] ?? item['imageUrl'] ?? '').toString().trim();
    final price = parsePrice(item['price']);
    if (name.isEmpty || img.isEmpty || price == null) continue;
    if (!seen.add(name)) continue;
    final unit = extractUnit(name);
    out.add({
      'id': 'walmart_pasta_${(out.length + 1).toString().padLeft(3, '0')}',
      'name': name,
      'price': price,
      'imageUrl': img,
      'description': null,
      'benefits': null,
      'unit': unit,
      'storeId': 'walmart',
      'category': 'Pantry',
      'subCategory': 'Pasta',
    });
  }
  // overwrite
  final encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(out) + '\n');
  stdout.writeln('Normalized ${out.length} pasta items.');
}
