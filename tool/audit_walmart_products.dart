import 'dart:convert';
import 'dart:io';

/*
Audits all product JSON files referenced in walmart_categories.json for canonical schema compliance.
Canonical keys: id,name,brand,price,imageUrl,description,benefits,unit,storeId,category,subCategory
Reports per file: total items, canonical count, missing key counts, nonNumericPrice count, idPrefix violations.
Exit code 0 always (informational).
*/

const requiredKeys = [
  'id',
  'name',
  'brand',
  'price',
  'imageUrl',
  'description',
  'benefits',
  'unit',
  'storeId',
  'category',
  'subCategory',
];

Future<void> main(List<String> args) async {
  final mappingPath = 'assets/stores/walmart/walmart_categories.json';
  final mapFile = File(mappingPath);
  if (!mapFile.existsSync()) {
    stderr.writeln('Mapping not found: $mappingPath');
    return;
  }
  dynamic root;
  try {
    root = jsonDecode(await mapFile.readAsString());
  } catch (e) {
    stderr.writeln('Failed to parse mapping: $e');
    return;
  }
  if (root is! List) {
    stderr.writeln('Mapping root not list');
    return;
  }
  final paths = <String>{};
  for (final cat in root) {
    if (cat is! Map) continue;
    final sections = cat['sections'];
    if (sections is! List) continue;
    for (final sec in sections) {
      if (sec is! Map) continue;
      final pts = sec['productTypes'];
      if (pts is! List) continue;
      for (final pt in pts) {
        if (pt is! Map) continue;
        final fp = pt['filePath'];
        if (fp is String) paths.add(fp);
      }
    }
  }

  int totalFiles = 0;
  int totalItems = 0;
  int totalCanonical = 0;
  final perKeyMissingTotals = <String, int>{for (final k in requiredKeys) k: 0};
  int nonNumericPrice = 0;
  int idPrefixViolations = 0;
  final sampleProblems = <String, List<String>>{};

  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) {
      stderr.writeln('[MISSING] $p');
      continue;
    }
    totalFiles++;
    List data;
    try {
      data = jsonDecode(await f.readAsString()) as List;
    } catch (e) {
      stderr.writeln('[PARSE-ERROR] $p: $e');
      continue;
    }
    int fileCanonical = 0;
    for (final rec in data) {
      if (rec is! Map) continue;
      totalItems++;
      bool canonical = true;
      for (final k in requiredKeys) {
        if (!rec.containsKey(k)) {
          canonical = false;
          perKeyMissingTotals[k] = (perKeyMissingTotals[k] ?? 0) + 1;
          sampleProblems.putIfAbsent(p, () => []);
          if (sampleProblems[p]!.length < 3)
            sampleProblems[p]!.add('Missing key: ' + k);
        }
      }
      // price numeric check
      final price = rec['price'];
      if (price != null && price is! num) {
        canonical = false;
        nonNumericPrice++;
        sampleProblems.putIfAbsent(p, () => []);
        if (sampleProblems[p]!.length < 3)
          sampleProblems[p]!.add('Non-numeric price: ' + price.toString());
      }
      final id = rec['id'];
      if (id is String && !id.startsWith('walmart_')) {
        idPrefixViolations++;
        canonical = false;
        sampleProblems.putIfAbsent(p, () => []);
        if (sampleProblems[p]!.length < 3)
          sampleProblems[p]!.add('ID prefix violation: ' + id);
      }
      if (canonical) fileCanonical++;
    }
    totalCanonical += fileCanonical;
    final pct = data.isEmpty
        ? 0
        : (fileCanonical * 100 / data.length).toStringAsFixed(1);
    stdout.writeln(
      '[FILE] $p items=${data.length} canonical=$fileCanonical (${pct}%)',
    );
    if (sampleProblems.containsKey(p)) {
      for (final s in sampleProblems[p]!) {
        stdout.writeln('   - $s');
      }
    }
  }

  stdout.writeln('--- SUMMARY ---');
  stdout.writeln('files: $totalFiles');
  stdout.writeln('items: $totalItems');
  stdout.writeln('canonicalItems: $totalCanonical');
  final pctAll = totalItems == 0
      ? '0.0'
      : (totalCanonical * 100 / totalItems).toStringAsFixed(1);
  stdout.writeln('overallCanonicalPct: $pctAll%');
  stdout.writeln('nonNumericPrice: $nonNumericPrice');
  stdout.writeln('idPrefixViolations: $idPrefixViolations');
  stdout.writeln('Missing key totals:');
  for (final k in requiredKeys) {
    final v = perKeyMissingTotals[k] ?? 0;
    if (v > 0) stdout.writeln('  $k: $v');
  }
}
