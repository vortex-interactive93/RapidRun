import 'dart:convert';
import 'dart:io';

// One-off normalizer for body-washes.json to match previously normalized Bath & Body schema
// without reassigning IDs in already-normalized files.
// It scans existing Bath & Body files for the highest numeric id suffix and continues.

const existingFiles = [
  'exfoliators.json',
  'hand-sanitizers.json',
  'hand-soaps.json',
  'self-tanners-bronzers.json',
  'bar-soaps.json',
  'bath-bombs.json',
  'bathing-supplies.json',
  'body-lotions-butters.json',
];

const targetFile = 'body-washes.json';
final dir = Directory('assets/stores/walmart');

Future<void> main() async {
  if (!dir.existsSync()) {
    stderr.writeln('Missing walmart dir');
    exit(1);
  }
  int maxId = await _findMaxId();
  final file = File('${dir.path}/$targetFile');
  if (!file.existsSync()) {
    stderr.writeln('Missing $targetFile');
    exit(2);
  }
  List<dynamic> raw;
  try {
    raw = json.decode(await file.readAsString()) as List<dynamic>;
  } catch (e) {
    stderr.writeln('Decode error: $e');
    exit(3);
  }
  final seen = <String>{};
  final normalized = <Map<String, dynamic>>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = entry.cast<String, dynamic>();
    final name = (map['name'] ?? '').toString().trim();
    final image = (map['image'] ?? map['imageUrl'] ?? '').toString().trim();
    if (name.isEmpty || image.isEmpty) continue;
    final sig = '$name::$image';
    if (!seen.add(sig)) continue;
    final priceVal = _parsePrice(map['price']);
    final unit = _extractUnit(name);
    maxId++;
    normalized.add({
      'name': name,
      'price': priceVal,
      'imageUrl': image,
      'id': 'walmart_bath_body_${maxId.toString().padLeft(4, '0')}',
      'description': map['description'],
      'benefits': map['benefits'],
      'unit': unit,
      'storeId': 'walmart',
      'category': 'Personal Care',
      'subCategory': 'Bath & Body',
    });
  }
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(normalized),
  );
  stdout.writeln(
    'Normalized ${normalized.length} items in $targetFile (starting after previous max id).',
  );
}

Future<int> _findMaxId() async {
  final re = RegExp(r'walmart_bath_body_(\d{4})');
  int maxId = 0;
  for (final f in existingFiles) {
    final file = File('${dir.path}/$f');
    if (!file.existsSync()) continue;
    try {
      final data = json.decode(await file.readAsString());
      if (data is List) {
        for (final item in data) {
          if (item is Map && item['id'] is String) {
            final m = re.firstMatch(item['id']);
            if (m != null) {
              final val = int.tryParse(m.group(1)!);
              if (val != null && val > maxId) maxId = val;
            }
          }
        }
      }
    } catch (_) {
      // ignore decode errors on existing normalized files
    }
  }
  return maxId;
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
    if (parsed != null) last = parsed;
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
