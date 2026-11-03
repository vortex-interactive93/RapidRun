import 'dart:convert';
import 'dart:io';

/// Comprehensive schema validation for Taco Bell product JSON files.
///
/// Validates:
/// - File parsing (must be JSON array)
/// - Product required fields & types: id,name,storeId(price,calories,minCalories,maxCalories)
/// - storeId must equal 'taco_bell'
/// - price numeric >= 0
/// - calories numeric >= 0
/// - minCalories/maxCalories numeric and min <= calories <= max
/// - tags (if present) list of strings
/// - imageUrl (if present) starts with http
/// - modifiers (if present): list of groups with id, options[]; each option has id,name,priceDelta,caloriesDelta
/// - modifierRefs (if present) are strings referencing _modifier_sets.json template ids
/// - No duplicate product ids across all files
/// - No inline modifier group id duplicates an entry in modifierRefs (avoid duplication) unless group has extra options
/// - Option numeric deltas are numeric (allow negative caloriesDelta for removal scenarios)
///
/// Outputs JSON report to tool/_schema_validation_report.json and exits with:
///  - 0 if no errors
///  - 2 if any errors found
Future<void> main(List<String> args) async {
  final storeDir = Directory('assets/stores/taco_bell');
  if (!storeDir.existsSync()) {
    stderr.writeln('Store directory not found: ${storeDir.path}');
    exit(1);
  }

  // Load modifier templates for reference checks.
  final modifierTemplateFile = File('${storeDir.path}/_modifier_sets.json');
  Map<String, dynamic> modifierTemplates = {};
  if (modifierTemplateFile.existsSync()) {
    try {
      final raw = jsonDecode(await modifierTemplateFile.readAsString());
      if (raw is Map<String, dynamic>) modifierTemplates = raw;
    } catch (e) {
      stderr.writeln('Warning: Failed to parse _modifier_sets.json: $e');
    }
  }
  final templateIds = modifierTemplates.values
      .whereType<Map>()
      .map((e) => e['id'])
      .whereType<String>()
      .toSet();

  final report = <String, dynamic>{
    'filesScanned': 0,
    'productsScanned': 0,
    'errors': <Map<String, dynamic>>[],
    'warnings': <Map<String, dynamic>>[],
    'uniqueProductIds': 0,
  };

  final productIds = <String, String>{}; // id -> filename

  void addError(String file, String? productId, String message) {
    (report['errors'] as List).add({
      'file': file,
      if (productId != null) 'productId': productId,
      'message': message,
    });
  }

  void addWarning(String file, String? productId, String message) {
    (report['warnings'] as List).add({
      'file': file,
      if (productId != null) 'productId': productId,
      'message': message,
    });
  }

  num? asNum(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) {
      final parsed = num.tryParse(v);
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool isStringList(dynamic v) => v is List && v.every((e) => e is String);

  for (final entity in storeDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.json') || name.startsWith('_')) continue;
    // Skip category metadata files (not product arrays)
    if (name.contains('_categories')) continue;
    report['filesScanned'] = (report['filesScanned'] as int) + 1;

    dynamic parsed;
    try {
      parsed = jsonDecode(await entity.readAsString());
    } catch (e) {
      addError(name, null, 'JSON parse error: $e');
      continue;
    }
    if (parsed is! List) {
      addError(name, null, 'Root JSON is not an array');
      continue;
    }

    for (final prod in parsed) {
      if (prod is! Map<String, dynamic>) {
        addError(name, null, 'Product entry not an object');
        continue;
      }
      report['productsScanned'] = (report['productsScanned'] as int) + 1;
      final pid = prod['id']?.toString();
      if (pid == null || pid.isEmpty) {
        addError(name, null, 'Missing product id');
        continue; // cannot attribute more errors reliably
      }

      // Unique product id check
      final prev = productIds[pid];
      if (prev != null) {
        addError(name, pid, 'Duplicate product id also in $prev');
      } else {
        productIds[pid] = name;
      }

      // Required fields
      for (final field in [
        'name',
        'storeId',
        'category',
        'price',
        'calories',
      ]) {
        if (!prod.containsKey(field)) {
          addError(name, pid, 'Missing required field: $field');
        }
      }

      if (prod['storeId'] != 'taco_bell') {
        addError(name, pid, "storeId must be 'taco_bell'");
      }

      final price = asNum(prod['price']);
      if (price == null) {
        addError(name, pid, 'price not numeric');
      } else if (price < 0) {
        addError(name, pid, 'price negative');
      }

      final calories = asNum(prod['calories']);
      if (calories == null) {
        addError(name, pid, 'calories not numeric');
      } else if (calories < 0) {
        addError(name, pid, 'calories negative');
      }

      final minCalories = prod.containsKey('minCalories')
          ? asNum(prod['minCalories'])
          : calories;
      final maxCalories = prod.containsKey('maxCalories')
          ? asNum(prod['maxCalories'])
          : calories;
      if (minCalories == null || maxCalories == null) {
        addError(name, pid, 'minCalories/maxCalories not numeric');
      } else {
        if (minCalories > maxCalories) {
          addError(name, pid, 'minCalories > maxCalories');
        }
        if (calories != null) {
          if (calories < minCalories || calories > maxCalories) {
            addError(
              name,
              pid,
              'calories not within [minCalories,maxCalories]',
            );
          }
        }
      }

      final tags = prod['tags'];
      if (tags != null && !isStringList(tags)) {
        addError(name, pid, 'tags must be list of strings');
      }

      final imageUrl = prod['imageUrl'];
      if (imageUrl != null && imageUrl is String) {
        if (!imageUrl.startsWith('http')) {
          addError(name, pid, 'imageUrl must start with http');
        }
      }

      // Validate combo modeling (optional)
      final isCombo = prod['isCombo'] == true;
      if (isCombo) {
        // includedItems: simple list of strings describing fixed items
        final includedItems = prod['includedItems'];
        if (includedItems != null) {
          if (includedItems is! List ||
              !includedItems.every(
                (e) => e is String && e.toString().isNotEmpty,
              )) {
            addError(
              name,
              pid,
              'includedItems must be list of non-empty strings',
            );
          }
        }
        // choiceGroups: structured selectable groups inside the combo
        final choiceGroups = prod['choiceGroups'];
        if (choiceGroups != null) {
          if (choiceGroups is! List) {
            addError(name, pid, 'choiceGroups must be a list');
          } else {
            for (final g in choiceGroups) {
              if (g is! Map<String, dynamic>) {
                addError(name, pid, 'choiceGroup entry not object');
                continue;
              }
              final cgId = g['id']?.toString();
              if (cgId == null || cgId.isEmpty) {
                addError(name, pid, 'choiceGroup missing id');
              }
              final cgName = g['name']?.toString();
              if (cgName == null || cgName.isEmpty) {
                addError(name, pid, 'choiceGroup missing name');
              }
              final minSel = asNum(g['min']);
              final maxSel = asNum(g['max']);
              if (minSel == null || maxSel == null) {
                addError(name, pid, 'choiceGroup min/max not numeric');
              } else {
                if (minSel < 0 || maxSel < 0) {
                  addError(name, pid, 'choiceGroup min/max negative');
                }
                if (minSel > maxSel) {
                  addError(name, pid, 'choiceGroup min > max');
                }
              }
              final options = g['options'];
              if (options is! List || options.isEmpty) {
                addError(
                  name,
                  pid,
                  'choiceGroup options must be non-empty list',
                );
              } else {
                final optionIds = <String>{};
                for (final o in options) {
                  if (o is! Map<String, dynamic>) {
                    addError(name, pid, 'choiceGroup option not object');
                    continue;
                  }
                  final oid = o['id']?.toString();
                  if (oid == null || oid.isEmpty) {
                    addError(name, pid, 'choiceGroup option missing id');
                  } else if (!optionIds.add(oid)) {
                    addError(name, pid, 'choiceGroup duplicate option id $oid');
                  }
                  final label = o['label']?.toString();
                  if (label == null || label.isEmpty) {
                    addError(
                      name,
                      pid,
                      'choiceGroup option $oid missing label',
                    );
                  }
                  // Optional refProductId for future linking to other products
                  if (o.containsKey('refProductId')) {
                    final ref = o['refProductId'];
                    if (ref is! String || ref.isEmpty) {
                      addError(
                        name,
                        pid,
                        'choiceGroup option $oid refProductId invalid',
                      );
                    }
                  }
                  if (o.containsKey('priceDelta')) {
                    final pd = asNum(o['priceDelta']);
                    if (pd == null) {
                      addError(
                        name,
                        pid,
                        'choiceGroup option $oid priceDelta not numeric',
                      );
                    }
                  }
                  if (o.containsKey('caloriesDelta')) {
                    final cd = asNum(o['caloriesDelta']);
                    if (cd == null) {
                      addError(
                        name,
                        pid,
                        'choiceGroup option $oid caloriesDelta not numeric',
                      );
                    }
                  }
                }
              }
            }
          }
        }
        if (includedItems == null && choiceGroups == null) {
          addWarning(
            name,
            pid,
            'isCombo true but no includedItems or choiceGroups defined',
          );
        }
      }

      // Validate modifiers
      final modifiers = prod['modifiers'];
      if (modifiers != null) {
        if (modifiers is! List) {
          addError(name, pid, 'modifiers must be a list');
        } else {
          for (final g in modifiers) {
            if (g is! Map<String, dynamic>) {
              addError(name, pid, 'modifier group not object');
              continue;
            }
            final gid = g['id']?.toString();
            if (gid == null || gid.isEmpty) {
              addError(name, pid, 'modifier group missing id');
            }
            final options = g['options'];
            if (options is! List) {
              addError(name, pid, 'modifier group options not list');
            } else {
              for (final o in options) {
                if (o is! Map<String, dynamic>) {
                  addError(name, pid, 'modifier option not object');
                  continue;
                }
                final oid = o['id']?.toString();
                if (oid == null || oid.isEmpty) {
                  addError(name, pid, 'modifier option missing id');
                }
                if (o['name'] == null) {
                  addError(name, pid, 'modifier option $oid missing name');
                }
                final priceDelta = asNum(o['priceDelta']);
                if (priceDelta == null) {
                  addError(
                    name,
                    pid,
                    'modifier option $oid priceDelta not numeric',
                  );
                }
                final caloriesDelta = asNum(o['caloriesDelta']);
                if (caloriesDelta == null) {
                  addError(
                    name,
                    pid,
                    'modifier option $oid caloriesDelta not numeric',
                  );
                }
              }
            }
          }
        }
      }

      // Validate modifierRefs
      final modifierRefs = prod['modifierRefs'];
      if (modifierRefs != null) {
        if (modifierRefs is! List) {
          addError(name, pid, 'modifierRefs must be a list');
        } else {
          final seenRef = <String>{};
          for (final r in modifierRefs) {
            if (r is! String) {
              addError(name, pid, 'modifierRef not a string');
              continue;
            }
            if (!templateIds.contains(r)) {
              addError(name, pid, 'modifierRef $r not in templates');
            }
            if (!seenRef.add(r)) {
              addError(name, pid, 'duplicate modifierRef $r');
            }
          }
          // Ensure no inline group duplicates a ref id (avoid duplication of same group both ways)
          if (modifiers is List) {
            final inlineIds = modifiers
                .whereType<Map>()
                .map((g) => g['id'])
                .whereType<String>()
                .toSet();
            final dup = inlineIds.intersection(
              modifierRefs.whereType<String>().toSet(),
            );
            if (dup.isNotEmpty) {
              addWarning(
                name,
                pid,
                'Inline groups duplicate modifierRefs: ${dup.join(', ')} (consider refactor)',
              );
            }
          }
        }
      }
    }
  }

  report['uniqueProductIds'] = productIds.length;
  report['errorCount'] = (report['errors'] as List).length;
  report['warningCount'] = (report['warnings'] as List).length;

  final outFile = File('tool/_schema_validation_report.json');
  final encoder = const JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(report));
  stdout.writeln('Schema validation complete. Report: ${outFile.path}');
  stdout.writeln(encoder.convert(report));

  if ((report['errorCount'] as int) > 0) {
    exit(2);
  }
}
