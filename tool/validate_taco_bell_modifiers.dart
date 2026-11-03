import 'dart:convert';
import 'dart:io';

/// Validates Taco Bell product modifier normalization:
/// 1. Loads canonical templates from _modifier_sets.json.
/// 2. Scans all Taco Bell product JSON arrays.
/// 3. Finds any inline modifier groups whose id appears in templates and whose
///    options exactly match the template (indicating they could be replaced by
///    modifierRefs in a future cleanup pass).
/// 4. Reports summary counts and writes a detailed report to
///    tool/_modifier_validation_report.json.
///
/// Exit code:
///  - 0 if no redundant inline groups found.
///  - 2 if redundant groups detected (still prints report path).
Future<void> main() async {
  final storeDir = Directory('assets/stores/taco_bell');
  if (!storeDir.existsSync()) {
    stderr.writeln('Store directory not found.');
    exit(1);
  }
  final templateFile = File('${storeDir.path}/_modifier_sets.json');
  if (!templateFile.existsSync()) {
    stderr.writeln('Template file _modifier_sets.json missing.');
    exit(1);
  }
  dynamic tmplJson;
  try {
    tmplJson = jsonDecode(await templateFile.readAsString());
  } catch (e) {
    stderr.writeln('Failed to parse _modifier_sets.json: $e');
    exit(1);
  }
  if (tmplJson is! Map<String, dynamic>) {
    stderr.writeln('Malformed _modifier_sets.json (expected object).');
    exit(1);
  }

  // Build group id -> option signature map.
  Map<String, Map<String, Map<String, dynamic>>> templateOptions = {};
  tmplJson.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      final id = value['id']?.toString();
      if (id == null) return;
      final opts =
          (value['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final optMap = <String, Map<String, dynamic>>{};
      for (final o in opts) {
        final oid = o['id']?.toString();
        if (oid != null) optMap[oid] = o;
      }
      templateOptions[id] = optMap;
    }
  });

  final report = {
    'filesScanned': 0,
    'productsScanned': 0,
    'redundantGroups': 0,
    'groupFindings': <Map<String, dynamic>>[],
  };

  bool eq(dynamic a, dynamic b) =>
      (a is num && b is num) ? a.toDouble() == b.toDouble() : a == b;

  bool groupEqualsTemplate(
    Map<String, dynamic> group,
    Map<String, Map<String, dynamic>> tmpl,
  ) {
    final gOpts =
        (group['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (gOpts.length != tmpl.length) return false;
    for (final o in gOpts) {
      final oid = o['id']?.toString();
      if (oid == null) return false;
      final t = tmpl[oid];
      if (t == null) return false;
      if (!eq(o['name'], t['name']) ||
          !eq(o['priceDelta'], t['priceDelta']) ||
          !eq(o['caloriesDelta'], t['caloriesDelta']))
        return false;
      if (t.containsKey('default') && !eq(o['default'], t['default']))
        return false;
    }
    return true;
  }

  for (final entity in storeDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.json') || name.startsWith('_')) continue;
    report['filesScanned'] = (report['filesScanned'] as int) + 1;
    dynamic parsed;
    try {
      parsed = jsonDecode(await entity.readAsString());
    } catch (_) {
      continue; // skip malformed
    }
    if (parsed is! List) continue;
    for (final prod in parsed) {
      if (prod is! Map<String, dynamic>) continue;
      report['productsScanned'] = (report['productsScanned'] as int) + 1;
      final mods = prod['modifiers'];
      if (mods is! List) continue;
      for (final g in mods) {
        if (g is! Map<String, dynamic>) continue;
        final gid = g['id']?.toString();
        if (gid == null) continue;
        final tmpl = templateOptions[gid];
        if (tmpl == null) continue; // only consider groups with templates
        if (groupEqualsTemplate(g, tmpl)) {
          report['redundantGroups'] = (report['redundantGroups'] as int) + 1;
          (report['groupFindings'] as List).add({
            'file': name,
            'productId': prod['id'],
            'groupId': gid,
            'message':
                'Inline group identical to template; can be replaced by modifierRefs',
          });
        }
      }
    }
  }

  final outFile = File('tool/_modifier_validation_report.json');
  final encoder = const JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(report));
  stdout.writeln('Validation complete. Report: ${outFile.path}');
  stdout.writeln(encoder.convert(report));
  if ((report['redundantGroups'] as int) > 0) exit(2);
}
