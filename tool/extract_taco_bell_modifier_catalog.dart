import 'dart:convert';
import 'dart:io';

/// Scans Taco Bell product JSON files under assets/stores/taco_bell and
/// aggregates unique modifier group definitions into a single catalog file.
/// The catalog is written to assets/stores/taco_bell/_modifier_catalog.json
/// (overwritten if exists).
///
/// Merging strategy:
/// - Groups are keyed by group id.
/// - Name / selection must match; first occurrence wins; mismatches are logged.
/// - Options merged by option id; first occurrence wins; mismatches logged.
/// - A "_meta" section is added with statistics & any conflicts.
///
/// Run with: dart run tool/extract_taco_bell_modifier_catalog.dart
void main(List<String> args) {
  final baseDir = Directory('assets/stores/taco_bell');
  if (!baseDir.existsSync()) {
    stderr.writeln('Directory not found: ${baseDir.path}');
    exit(1);
  }

  final groupMap =
      <String, Map<String, dynamic>>{}; // id -> group (without meta)
  final groupConflicts = <String, List<String>>{}; // id -> conflict messages
  final optionConflicts = <String, List<String>>{}; // composite key -> messages

  int filesScanned = 0;
  int groupsSeen = 0;
  int optionsSeen = 0;

  for (final entity in baseDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith('taco-bell-') || !name.endsWith('.json')) continue;
    if (name.startsWith('_')) continue; // skip catalog or meta files
    List<dynamic> products;
    try {
      products = json.decode(entity.readAsStringSync()) as List<dynamic>;
    } catch (_) {
      continue; // skip non array files
    }
    filesScanned++;
    for (final p in products) {
      if (p is! Map<String, dynamic>) continue;
      final mods = p['modifiers'];
      if (mods is! List) continue;
      for (final g in mods) {
        if (g is! Map<String, dynamic>) continue;
        final gid = g['id'];
        final gname = g['name'];
        final selection = g['selection'];
        final options = (g['options'] as List?) ?? const [];
        if (gid is! String || gname is! String || selection is! String)
          continue;
        groupsSeen++;
        if (!groupMap.containsKey(gid)) {
          // store shallow copy without mutations
          groupMap[gid] = {
            'id': gid,
            'name': gname,
            'selection': selection,
            'options': [],
          };
        } else {
          final existing = groupMap[gid]!;
          if (existing['name'] != gname || existing['selection'] != selection) {
            groupConflicts
                .putIfAbsent(gid, () => [])
                .add(
                  'Name/selection mismatch: existing(name=${existing['name']}, sel=${existing['selection']}), new(name=$gname, sel=$selection) from file $name',
                );
          }
        }
        final existingOptions = (groupMap[gid]!['options'] as List)
            .cast<Map<String, dynamic>>();
        for (final o in options) {
          if (o is! Map<String, dynamic>) continue;
          final oid = o['id'];
          if (oid is! String) continue;
          optionsSeen++;
          final idx = existingOptions.indexWhere((e) => e['id'] == oid);
          if (idx == -1) {
            // add copy without extraneous keys except allowed
            existingOptions.add({
              'id': oid,
              'name': o['name'],
              'priceDelta': o['priceDelta'],
              'caloriesDelta': o['caloriesDelta'],
              if (o['default'] == true) 'default': true,
            });
          } else {
            final eo = existingOptions[idx];
            bool mismatch = false;
            if (eo['name'] != o['name'] ||
                eo['priceDelta'] != o['priceDelta'] ||
                eo['caloriesDelta'] != o['caloriesDelta']) {
              mismatch = true;
            }
            if (mismatch) {
              final key = '$gid::$oid';
              optionConflicts
                  .putIfAbsent(key, () => [])
                  .add(
                    'Mismatch in option $oid for group $gid in file $name (existing: name=${eo['name']}, priceDelta=${eo['priceDelta']}, cal=${eo['caloriesDelta']}; new: name=${o['name']}, priceDelta=${o['priceDelta']}, cal=${o['caloriesDelta']})',
                  );
            }
            // If default appears later and not set, keep existing default state (first wins)
          }
        }
        // sort options by id for consistency
        existingOptions.sort(
          (a, b) => (a['id'] as String).compareTo(b['id'] as String),
        );
      }
    }
  }

  // Sort groups by id
  final groups = groupMap.values.toList()
    ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final catalog = {
    '_meta': {
      'filesScanned': filesScanned,
      'groupsIngested': groupsSeen,
      'uniqueGroups': groups.length,
      'optionsIngested': optionsSeen,
      'groupConflicts': groupConflicts,
      'optionConflicts': optionConflicts,
      'generatedAt': DateTime.now().toIso8601String(),
      'note':
          'This catalog is an aggregation; first occurrence wins on conflicts.',
    },
    'groups': groups,
  };

  final outFile = File('assets/stores/taco_bell/_modifier_catalog.json');
  final encoder = const JsonEncoder.withIndent('  ');
  outFile.writeAsStringSync(encoder.convert(catalog) + '\n');

  stdout.writeln('Modifier catalog written: ${outFile.path}');
  stdout.writeln('Unique groups: ${groups.length}');
  stdout.writeln('Group conflicts: ${groupConflicts.length}');
  stdout.writeln('Option conflicts: ${optionConflicts.length}');
}
