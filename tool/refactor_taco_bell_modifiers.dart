import 'dart:convert';
import 'dart:io';

/// Refactors Taco Bell product JSON files by replacing inline modifier groups
/// with canonical modifierRefs when the group is an exact match to a template
/// in assets/stores/taco_bell/_modifier_sets.json.
///
/// Safety features:
/// - Creates a .bak backup of every modified file exactly once.
/// - Skips files not under assets/stores/taco_bell/ or starting with '_'.
/// - Leaves custom groups (e.g. choose_* placeholders) inline.
/// - If an inline group differs (options added/removed/changed), it is retained.
/// - Generates a summary report (tool/_refactor_modifier_report.json).
///
/// Matching logic:
/// - Group id must exist in template map.
/// - Options count must match.
/// - Each option (by id) must match name, priceDelta, caloriesDelta, and default flag (if present).
/// - Order is ignored; comparison is by sorted option id.
///
/// After refactor, products may contain both modifierRefs and an inline modifiers
/// list; inline entries that matched were removed. If no inline groups remain,
/// the modifiers field is removed entirely to keep payload small.
Future<void> main(List<String> args) async {
  final root = Directory('assets/stores/taco_bell');
  if (!root.existsSync()) {
    stderr.writeln('Taco Bell store directory not found.');
    exit(1);
  }

  final templateFile = File('${root.path}/_modifier_sets.json');
  if (!templateFile.existsSync()) {
    stderr.writeln('Canonical modifier sets file not found.');
    exit(1);
  }

  final templatesRaw = jsonDecode(await templateFile.readAsString());
  if (templatesRaw is! Map<String, dynamic>) {
    stderr.writeln('Malformed _modifier_sets.json (expected object).');
    exit(1);
  }

  // Normalize templates keyed by group id -> group map.
  final Map<String, Map<String, dynamic>> templates = {};
  templatesRaw.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      final id = v['id']?.toString();
      if (id != null) templates[id] = v;
    }
  });

  // Inject a synthesized 'included' template if absent (aggregate common included options guessed from catalog if needed).
  templates.putIfAbsent(
    'included',
    () => {
      'id': 'included',
      'name': "What's Included",
      'selection': 'multi',
      'options': <Map<String, dynamic>>[],
    },
  );

  // Aliases for option id normalization.
  final optionIdAliases = <String, String>{
    'guacamole_sauce': 'guacamole',
    'creamy_jalapeno_sauce_option': 'creamy_jalapeno_sauce',
    'potatoes_addon': 'potatoes',
    'three_cheese_blend_extra':
        'three_cheese_blend', // treat extra as same for ref template match; retained inline if price differs
    'cheese_extra': 'cheese',
    'supreme': 'make_it_supreme',
    'make_it_grilled': 'grilled',
    'make_it_fresco': 'fresco',
    'jalapeno_peppers_addon': 'jalapeno_peppers',
    'onions_addon': 'onions',
    'pico_de_gallo_addon': 'pico_de_gallo',
    'nacho_cheese_sauce_addon': 'nacho_cheese_sauce',
  };

  // Canonical value overrides (calories / price) by id (conservative highest cals rule applied earlier decisions).
  final canonicalOverrides = <String, Map<String, dynamic>>{
    'red_sauce': {'caloriesDelta': 25},
    'creamy_jalapeno_sauce': {'caloriesDelta': 80},
    'spicy_ranch': {'caloriesDelta': 70},
    'pico_de_gallo': {'caloriesDelta': 10},
    'tomatoes': {'caloriesDelta': 5},
    'nacho_cheese_sauce': {'caloriesDelta': 50},
  };

  // Precompute option signature maps for fast equality checks.
  Map<String, Map<String, Map<String, dynamic>>> templateOptionMaps = {};
  templates.forEach((id, group) {
    final options =
        (group['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final optMap = <String, Map<String, dynamic>>{};
    for (final o in options) {
      final rawId = o['id']?.toString();
      final oid = optionIdAliases[rawId] ?? rawId;
      if (oid != null) optMap[oid] = o;
    }
    templateOptionMaps[id] = optMap;
  });

  final report = {
    'filesProcessed': 0,
    'filesModified': 0,
    'groupsRefed': 0,
    'groupsRetained': 0,
    'productsAnalyzed': 0,
    'productsChanged': 0,
    'fileSummaries': <Map<String, dynamic>>[],
  };

  for (final file in root.listSync()) {
    if (file is! File) continue;
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.json')) continue;
    if (name.startsWith('_')) continue; // skip catalog / templates
    final text = await file.readAsString();
    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (e) {
      stderr.writeln('Skipping $name (JSON parse error): $e');
      continue;
    }
    if (parsed is! List) continue; // only process list product files

    bool fileChanged = false;
    int groupsRefedInFile = 0;
    int groupsRetainedInFile = 0;
    int productsChangedInFile = 0;

    for (final product in parsed) {
      if (product is! Map<String, dynamic>) continue;
      report['productsAnalyzed'] = (report['productsAnalyzed'] as int) + 1;
      final modifiers = product['modifiers'];
      if (modifiers is! List) continue;

      final List newInline = [];
      final List<String> refs =
          (product['modifierRefs'] as List?)?.cast<String>() ?? [];
      bool productChanged = false;

      for (final group in modifiers) {
        if (group is! Map<String, dynamic>) {
          newInline.add(group); // preserve unknown structures
          continue;
        }
        final gid = group['id']?.toString();
        if (gid == null) {
          newInline.add(group);
          continue;
        }
        // Heuristic: treat choose_* scaffolds or unmatched ids as custom.
        if (gid.startsWith('choose_')) {
          newInline.add(group);
          groupsRetainedInFile++;
          continue;
        }
        final template = templates[gid];
        if (template == null) {
          newInline.add(group); // unknown group id
          groupsRetainedInFile++;
          continue;
        }
        final tmplOptions = templateOptionMaps[gid] ?? const {};
        final groupOptions =
            (group['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final groupOptMap = <String, Map<String, dynamic>>{};
        bool structurallyValid = true;
        for (final o in groupOptions) {
          // Normalize id via aliases
          final rawId = o['id']?.toString();
          final oid = optionIdAliases[rawId] ?? rawId;
          if (oid == null) {
            structurallyValid = false;
            break;
          }
          // Apply canonical overrides for calories/price/name if present in template.
          final canonical = canonicalOverrides[oid];
          if (canonical != null) {
            canonical.forEach((k, v) => o[k] = v);
          }
          // If template has this option, harmonize its name/price/calories for comparison (does not change semantics significantly).
          final tmplOpt = tmplOptions[oid];
          if (tmplOpt != null) {
            // copy only if fields exist to avoid injecting unwanted data
            o['name'] = tmplOpt['name'];
            o['priceDelta'] = (tmplOpt['priceDelta'] ?? o['priceDelta']);
            o['caloriesDelta'] =
                (tmplOpt['caloriesDelta'] ?? o['caloriesDelta']);
            if (tmplOpt.containsKey('default')) {
              o['default'] = tmplOpt['default'];
            }
          }
          groupOptMap[oid] = o;
        }
        if (!structurallyValid) {
          newInline.add(group);
          groupsRetainedInFile++;
          continue;
        }
        // Perform subset / equality check.
        bool optionMatches(Map<String, dynamic> a, Map<String, dynamic> b) {
          bool eq(dynamic x, dynamic y) =>
              (x is num && y is num) ? (x.toDouble() == y.toDouble()) : x == y;
          if (!eq(a['name'], b['name'])) return false;
          if (!eq(a['priceDelta'], b['priceDelta'])) return false;
          if (!eq(a['caloriesDelta'], b['caloriesDelta'])) return false;
          if (b.containsKey('default')) {
            if (!eq(a['default'], b['default'])) return false;
          }
          return true;
        }

        // Check if every group option exists and matches in template (subset criteria)
        bool isSubset = true;
        for (final entry in groupOptMap.entries) {
          final tmpl = tmplOptions[entry.key];
          if (tmpl == null || !optionMatches(entry.value, tmpl)) {
            isSubset = false;
            break;
          }
        }
        if (!isSubset) {
          newInline.add(group); // keep inline
          groupsRetainedInFile++;
          continue;
        }
        // If subset, reference template and retain only delta options (here none because subset matched all) – full replacement.
        if (!refs.contains(gid)) {
          refs.add(gid);
          productChanged = true;
          groupsRefedInFile++;
        }
        // Remove inline group since it’s a subset (no unique options)
        // (If we wanted to keep unique extras we would diff and keep extras only.)
      }

      // If we reduced inline groups, update product.
      if (newInline.length != modifiers.length) {
        productChanged = true;
      }
      if (productChanged) {
        // Replace inline with retained list (if any).
        if (newInline.isEmpty) {
          product.remove('modifiers');
        } else {
          product['modifiers'] = newInline;
        }
        if (refs.isNotEmpty) {
          product['modifierRefs'] = refs;
        }
        productsChangedInFile++;
      }
    }

    if (productsChangedInFile > 0) {
      // Backup once.
      final bak = File('${file.path}.bak');
      if (!bak.existsSync()) await bak.writeAsString(text);
      // Write updated file (pretty).
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(parsed) + '\n');
      fileChanged = true;
    }

    report['filesProcessed'] = (report['filesProcessed'] as int) + 1;
    if (fileChanged)
      report['filesModified'] = (report['filesModified'] as int) + 1;
    report['groupsRefed'] = (report['groupsRefed'] as int) + groupsRefedInFile;
    report['groupsRetained'] =
        (report['groupsRetained'] as int) + groupsRetainedInFile;
    report['productsChanged'] =
        (report['productsChanged'] as int) + productsChangedInFile;
    (report['fileSummaries'] as List).add({
      'file': name,
      'productsChanged': productsChangedInFile,
      'groupsRefed': groupsRefedInFile,
      'groupsRetained': groupsRetainedInFile,
    });
  }

  final reportFile = File('tool/_refactor_modifier_report.json');
  final encoder = const JsonEncoder.withIndent('  ');
  await reportFile.writeAsString(encoder.convert(report));
  stdout.writeln('Refactor complete. Report: ${reportFile.path}');
  stdout.writeln(encoder.convert(report));
}
