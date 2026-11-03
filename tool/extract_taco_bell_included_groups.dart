import 'dart:convert';
import 'dart:io';

/// Scans Taco Bell product JSON files for inline modifier groups with id 'included'.
/// Produces a summary report including:
/// - Total products with included group
/// - Distinct included option set signatures (sorted option ids joined by '+')
/// - Frequency of each signature
/// - Per-option occurrence counts and default=true counts
/// - Suggested canonical template union (highest caloriesDelta & priceDelta per option)
///
/// Writes report to tool/_included_groups_report.json.
Future<void> main() async {
  final dir = Directory('assets/stores/taco_bell');
  if (!dir.existsSync()) {
    stderr.writeln('Store directory not found.');
    exit(1);
  }
  int productsWithIncluded = 0;
  final signatureFreq = <String, int>{};
  final signatureExamples =
      <String, Map<String, dynamic>>{}; // first product example
  final optionStats = <String, Map<String, dynamic>>{}; // id -> stats
  final unionOptions =
      <String, Map<String, dynamic>>{}; // id -> canonical union

  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.json') || name.startsWith('_')) continue;
    dynamic parsed;
    try {
      parsed = jsonDecode(await entity.readAsString());
    } catch (_) {
      continue;
    }
    if (parsed is! List) continue;
    for (final prod in parsed) {
      if (prod is! Map<String, dynamic>) continue;
      final mods = prod['modifiers'];
      if (mods is! List) continue;
      for (final g in mods.whereType<Map<String, dynamic>>()) {
        if (g['id'] != 'included') continue;
        productsWithIncluded++;
        final opts =
            (g['options'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        final ids =
            opts
                .map((o) => o['id']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList()
              ..sort();
        final sig = ids.join('+');
        signatureFreq[sig] = (signatureFreq[sig] ?? 0) + 1;
        signatureExamples.putIfAbsent(
          sig,
          () => {'file': name, 'productId': prod['id'], 'options': ids},
        );
        // Option stats & union
        for (final o in opts) {
          final oid = o['id']?.toString();
          if (oid == null) continue;
          final caloriesDelta = _asNum(o['caloriesDelta']);
          final priceDelta = _asNum(o['priceDelta']);
          final isDefault = o['default'] == true;
          final stat = optionStats.putIfAbsent(
            oid,
            () => {
              'count': 0,
              'defaultCount': 0,
              'maxCaloriesDelta': caloriesDelta ?? 0,
              'maxPriceDelta': priceDelta ?? 0,
              'names': <String>{},
            },
          );
          stat['count'] = (stat['count'] as int) + 1;
          if (isDefault)
            stat['defaultCount'] = (stat['defaultCount'] as int) + 1;
          if (caloriesDelta != null &&
              caloriesDelta > (stat['maxCaloriesDelta'] as num)) {
            stat['maxCaloriesDelta'] = caloriesDelta;
          }
          if (priceDelta != null &&
              priceDelta > (stat['maxPriceDelta'] as num)) {
            stat['maxPriceDelta'] = priceDelta;
          }
          (stat['names'] as Set<String>).add(o['name']?.toString() ?? '');

          final union = unionOptions.putIfAbsent(
            oid,
            () => {
              'id': oid,
              'name': o['name'],
              'priceDelta': priceDelta ?? 0,
              'caloriesDelta': caloriesDelta ?? 0,
              'defaultFrequency': 0,
            },
          );
          // keep max calories/price as canonical
          if (caloriesDelta != null &&
              caloriesDelta > (union['caloriesDelta'] as num)) {
            union['caloriesDelta'] = caloriesDelta;
          }
          if (priceDelta != null && priceDelta > (union['priceDelta'] as num)) {
            union['priceDelta'] = priceDelta;
          }
          if (isDefault) {
            union['defaultFrequency'] = (union['defaultFrequency'] as int) + 1;
          }
        }
      }
    }
  }

  // Build sorted union list; decide default flag threshold (appears default in >=80% of appearances)
  final unionList = unionOptions.values.toList();
  unionList.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  final canonicalOptions = <Map<String, dynamic>>[];
  for (final o in unionList) {
    final oid = o['id'];
    final stats = optionStats[oid];
    final appearances = (stats?['count'] as int?) ?? 1;
    final defaultCount = (stats?['defaultCount'] as int?) ?? 0;
    final defaultRatio = defaultCount / appearances;
    final entry = {
      'id': oid,
      'name': o['name'],
      'priceDelta': o['priceDelta'],
      'caloriesDelta': o['caloriesDelta'],
      if (defaultRatio >= 0.8) 'default': true,
      'defaultFrequency': defaultCount,
      'appearanceCount': appearances,
    };
    canonicalOptions.add(entry);
  }

  final signatureList =
      signatureFreq.entries
          .map(
            (e) => {
              'signature': e.key,
              'count': e.value,
              'example': signatureExamples[e.key],
            },
          )
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

  final optionSummary =
      optionStats.entries
          .map(
            (e) => {
              'id': e.key,
              'count': e.value['count'],
              'defaultCount': e.value['defaultCount'],
              'maxCaloriesDelta': e.value['maxCaloriesDelta'],
              'maxPriceDelta': e.value['maxPriceDelta'],
              'names': (e.value['names'] as Set).toList(),
            },
          )
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

  final report = {
    'productsWithIncluded': productsWithIncluded,
    'distinctSignatures': signatureFreq.length,
    'signatures': signatureList,
    'optionStats': optionSummary,
    'suggestedCanonicalIncluded': {
      'id': 'included',
      'name': "What's Included",
      'selection': 'multi',
      'options': canonicalOptions,
      'notes':
          'default flags assigned when option default in >=80% of occurrences; calories/price pick max observed.',
    },
  };

  final outFile = File('tool/_included_groups_report.json');
  final encoder = const JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(report));
  stdout.writeln(
    'Included groups extraction complete. Report: ${outFile.path}',
  );
  stdout.writeln(encoder.convert(report));
}

num? _asNum(dynamic v) {
  if (v is int) return v.toDouble();
  if (v is double) return v;
  if (v is String) return num.tryParse(v);
  return null;
}
