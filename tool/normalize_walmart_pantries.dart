import 'dart:convert';
import 'dart:io';

/// Normalizes raw Walmart pantry JSON files (with legacy keys) into the app's standard product schema.
/// Place raw files (e.g., pickles.json) in a source directory (default: ./raw_walmart_pantry) as arrays of objects
/// containing at minimum: name (or w_iuh7), image (or imageUrl), price (string like "current price Now $1.68").
/// Some provided raw files in the current workflow only contain price stubs; those will be skipped with a warning.
///
/// Output goes to assets/stores/walmart/<file>. The script will overwrite existing normalized files.
/// IDs follow pattern walmart_<slug>_NNN with slug derived from filename (without extension) and NNN 001+.
///
/// Run: dart run tool/normalize_walmart_pantries.dart --rawDir=./downloads/pantry
/// (Adjust rawDir to the folder containing the raw JSON attachments.)

class NormalizeConfigEntry {
  final String file; // target output filename
  final String subCategory; // default / base subCategory
  final String? rawFile; // optional alternate raw source filename
  final List<String> rawFiles; // optional multiple source filenames to merge
  final List<RegExp>
  excludeNamePatterns; // skip raw items whose name matches any pattern

  // Optional classification rules (applied only for this entry) to override subCategory based on name keywords.
  final List<ClassificationRule> classificationRules;
  final String?
  defaultSubCategory; // if classification rules present, fallback subCategory
  final bool
  splitPerSubCategory; // when classification rules produce multiple subCategories, write separate files

  NormalizeConfigEntry(
    this.file,
    this.subCategory, {
    this.rawFile,
    List<String>? rawFiles,
    List<RegExp>? excludeNamePatterns,
    List<ClassificationRule>? classificationRules,
    this.defaultSubCategory,
    this.splitPerSubCategory = false,
  }) : rawFiles = rawFiles ?? const [],
       excludeNamePatterns = excludeNamePatterns ?? const [],
       classificationRules = classificationRules ?? const [];
}

class ClassificationRule {
  final String subCategory;
  final List<RegExp> match; // any of these patterns triggers rule
  ClassificationRule(this.subCategory, this.match);
}

class AdvancedDedupeConfig {
  final bool enabled;
  final String mode; // conservative | aggressive
  final double priceVariancePct;
  final bool ignorePackDifferences;
  final List<RegExp> stopWords;
  AdvancedDedupeConfig({
    required this.enabled,
    required this.mode,
    required this.priceVariancePct,
    required this.ignorePackDifferences,
    required this.stopWords,
  });
  static AdvancedDedupeConfig disabled() => AdvancedDedupeConfig(
    enabled: false,
    mode: 'conservative',
    priceVariancePct: 5,
    ignorePackDifferences: false,
    stopWords: const [],
  );
}

class NormalizeConfig {
  final String storeId;
  final String category;
  final List<NormalizeConfigEntry> files;
  final AdvancedDedupeConfig advancedDedupe;
  NormalizeConfig(this.storeId, this.category, this.files, this.advancedDedupe);

  static NormalizeConfig load(File f) {
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

    AdvancedDedupeConfig adv = AdvancedDedupeConfig.disabled();
    if (data['advancedDedupe'] is Map) {
      final d = data['advancedDedupe'] as Map<String, dynamic>;
      final enabled = d['enabled'] == true;
      final stopWords = <RegExp>[];
      if (d['stopWords'] is List) {
        for (final s in (d['stopWords'] as List)) {
          if (s is String && s.trim().isNotEmpty) {
            stopWords.add(RegExp('\\b${RegExp.escape(s.toLowerCase())}\\b'));
          }
        }
      }
      adv = AdvancedDedupeConfig(
        enabled: enabled,
        mode: (d['mode'] as String?) ?? 'conservative',
        priceVariancePct: (d['priceVariancePct'] is num)
            ? (d['priceVariancePct'] as num).toDouble()
            : 5.0,
        ignorePackDifferences: d['ignorePackDifferences'] == true,
        stopWords: stopWords,
      );
    }

    List<NormalizeConfigEntry> entries = (data['files'] as List).map((e) {
      final patterns = <RegExp>[];
      if (e is Map && e['excludeNamePatterns'] is List) {
        for (final p in (e['excludeNamePatterns'] as List)) {
          if (p is String && p.trim().isNotEmpty) {
            patterns.add(RegExp(p, caseSensitive: false));
          }
        }
      }

      // classification rules
      final classificationRules = <ClassificationRule>[];
      if (e is Map && e['classificationRules'] is List) {
        for (final r in (e['classificationRules'] as List)) {
          if (r is Map && r['subCategory'] is String && r['match'] is List) {
            final matchRegex = <RegExp>[];
            for (final m in (r['match'] as List)) {
              if (m is String && m.trim().isNotEmpty) {
                matchRegex.add(RegExp(m, caseSensitive: false));
              }
            }
            if (matchRegex.isNotEmpty) {
              classificationRules.add(
                ClassificationRule(r['subCategory'] as String, matchRegex),
              );
            }
          }
        }
      }

      return NormalizeConfigEntry(
        e['file'],
        e['subCategory'],
        rawFile: e['rawFile'],
        rawFiles: (e['rawFiles'] is List)
            ? (e['rawFiles'] as List).whereType<String>().toList()
            : null,
        excludeNamePatterns: patterns,
        classificationRules: classificationRules,
        defaultSubCategory: e['defaultSubCategory'],
        splitPerSubCategory: e['splitPerSubCategory'] == true,
      );
    }).toList();

    return NormalizeConfig(
      data['storeId'] as String,
      data['category'] as String,
      entries,
      adv,
    );
  }
}

String slugFromFilename(String name) => name.replaceAll('.json', '');

final priceReg = RegExp(r'(\d+\.?\d*)');

num? parsePrice(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  final m = priceReg.firstMatch(s);
  if (m == null) return null;
  return num.tryParse(m.group(1)!);
}

String? extractUnit(String name) {
  if (name.isEmpty) return null;
  final lower = name.toLowerCase();
  // Normalize textual unit variants before regex extraction (e.g., "ounce", "ounces" -> "oz")
  final normalized = lower.replaceAll(RegExp(r'\bounces?\b'), 'oz');

  // 1. Multi-pack pattern e.g. "6 x 10 fl oz" or "6x10 oz" or "2-24 oz" (dash treated as x)
  final multiPack = RegExp(
    r'(\d+)\s*[x\-]\s*(\d+(?:\.\d+)?)\s*(fl\s*oz|oz|lb|g|kg|ml|l)',
  );
  final mp = multiPack.firstMatch(normalized);
  if (mp != null) {
    final count = int.tryParse(mp.group(1)!);
    final sizeVal = double.tryParse(mp.group(2)!);
    var unit = mp.group(3)!.replaceAll(RegExp(r'\s+'), ' ');
    if (count != null && sizeVal != null) {
      final total = count * sizeVal;
      // Normalize unit casing
      unit = normalizeUnit(unit);
      final sizeStr = _trimDouble(sizeVal);
      return '${count}x$sizeStr $unit (total ${_trimDouble(total)} $unit)';
    }
  }

  // 2. Count + size each pattern e.g. "12 ct / 1.5 oz each"
  final countEach = RegExp(
    r'(\d+)\s*(ct|count)\b.*?(\d+(?:\.\d+)?)\s*(fl\s*oz|oz|g|ml)',
  );
  final ce = countEach.firstMatch(normalized);
  if (ce != null) {
    final ct = int.tryParse(ce.group(1)!);
    final sizeVal = double.tryParse(ce.group(3)!);
    var unit = normalizeUnit(ce.group(4)!);
    if (ct != null && sizeVal != null) {
      final total = ct * sizeVal;
      return '${ct}x${_trimDouble(sizeVal)} $unit (total ${_trimDouble(total)} $unit)';
    }
  }

  // 3. Pack count detection. We support both forms:
  //    a) "24 pack 12 fl oz"  (count precedes the word pack)
  //    b) "pack of 24" / "pack 24" (count follows the word pack)
  final precedingPack = RegExp(r'(\d+)\s*(?:pack|pk|ct|count)\b');
  final trailingPack = RegExp(r'(?:pack(?: of)?|pk)\s*(\d+)');
  final pre = precedingPack.firstMatch(lower);
  final post = trailingPack.firstMatch(lower);
  int? detectedPackCount;
  if (pre != null) {
    detectedPackCount = int.tryParse(pre.group(1)!);
  } else if (post != null) {
    detectedPackCount = int.tryParse(post.group(1)!);
  }

  // 4. Simple single size
  final single = RegExp(
    r'(\d+(?:\.\d+)?)\s*(fl\s*oz|oz|lb|g|kg|ml|l|ct|count)',
  );
  // We iterate all matches so we can skip nutrition claims like "5g protein" and pick the next real size (e.g., "10 oz").
  final allSingles = single.allMatches(normalized).toList();
  for (final s in allSingles) {
    // If immediately followed by the word 'protein' treat as a nutrition claim, not a package size.
    final after = normalized.substring(s.end);
    if (RegExp(r'^\s*protein\b').hasMatch(after)) {
      continue; // skip this match, look for next candidate
    }
    final v = _trimDouble(double.tryParse(s.group(1)!) ?? 0);
    var unit = normalizeUnit(s.group(2)!);
    if (detectedPackCount != null && unit != 'ct' && unit != 'count') {
      final baseVal = double.tryParse(s.group(1)!) ?? 0.0;
      final total = detectedPackCount * baseVal;
      return '${detectedPackCount}x${v} $unit (total ${_trimDouble(total)} $unit)';
    }
    if (unit == 'count') unit = 'ct';
    return '$v $unit';
  }

  return null;
}

/// Detailed parsed unit info. Returns null if cannot parse meaningful quantity.
class ParsedUnitInfo {
  final double quantity; // single item size (or total if only single)
  final double? count; // number of items in multi-pack
  final double
  totalQuantity; // overall quantity (count * quantity if multi-pack)
  final String unit; // normalized unit (ml, fl oz, g, kg, oz, lb, ct)
  final String display; // human readable combined string
  final String
  baseUnit; // standardized base unit (metric: ml for volume, g for mass, ct for count)
  final double
  baseQuantity; // quantity converted to baseUnit (per item if multi) OR total? We'll store total
  final double baseTotalQuantity; // total quantity in baseUnit
  ParsedUnitInfo({
    required this.quantity,
    required this.count,
    required this.totalQuantity,
    required this.unit,
    required this.display,
    required this.baseUnit,
    required this.baseQuantity,
    required this.baseTotalQuantity,
  });

  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'count': count,
    'totalQuantity': totalQuantity,
    'unit': unit,
    'display': display,
    'baseUnit': baseUnit,
    'baseQuantity': baseQuantity,
    'baseTotalQuantity': baseTotalQuantity,
  };
}

ParsedUnitInfo? parseUnitStructured(String name) {
  final u = extractUnit(name);
  if (u == null) return null;
  // Attempt to re-interpret patterns we output in extractUnit
  // Patterns like: 6x12 fl oz (total 72 fl oz) OR 12 oz
  final multi = RegExp(
    r'^(\d+)x(\d+(?:\.\d+)?)\s*([a-z ]+)\s*\(total\s*(\d+(?:\.\d+)?)\s*([a-z ]+)\)$',
  );
  final m = multi.firstMatch(u.toLowerCase());
  double? count;
  double quantity;
  double total;
  String unit;
  if (m != null) {
    count = double.tryParse(m.group(1)!);
    quantity = double.tryParse(m.group(2)!) ?? 0;
    total = double.tryParse(m.group(4)!) ?? (count ?? 1) * quantity;
    unit = normalizeUnit(m.group(3)!);
  } else {
    final single = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z ]+)$');
    final s = single.firstMatch(u.toLowerCase());
    if (s == null) return null;
    quantity = double.tryParse(s.group(1)!) ?? 0;
    total = quantity;
    unit = normalizeUnit(s.group(2)!);
  }
  // Derive base unit conversions
  String baseUnit = unit;
  double baseQuantity = quantity;
  double baseTotalQuantity = total;
  // Volume: fl oz -> ml (29.5735), L -> ml *1000
  // Mass: lb -> g (453.592), kg -> g *1000, oz -> g (28.3495)
  if (unit == 'fl oz') {
    baseUnit = 'ml';
    baseQuantity = quantity * 29.5735;
    baseTotalQuantity = total * 29.5735;
  } else if (unit == 'L') {
    baseUnit = 'ml';
    baseQuantity = quantity * 1000;
    baseTotalQuantity = total * 1000;
  } else if (unit == 'lb') {
    baseUnit = 'g';
    baseQuantity = quantity * 453.592;
    baseTotalQuantity = total * 453.592;
  } else if (unit == 'kg') {
    baseUnit = 'g';
    baseQuantity = quantity * 1000;
    baseTotalQuantity = total * 1000;
  } else if (unit == 'oz') {
    baseUnit = 'g';
    baseQuantity = quantity * 28.3495;
    baseTotalQuantity = total * 28.3495;
  } else if (unit == 'ct') {
    baseUnit = 'ct';
  }
  return ParsedUnitInfo(
    quantity: quantity,
    count: count,
    totalQuantity: total,
    unit: unit,
    display: u,
    baseUnit: baseUnit,
    baseQuantity: baseQuantity,
    baseTotalQuantity: baseTotalQuantity,
  );
}

String normalizeUnit(String raw) {
  raw = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  switch (raw) {
    case 'floz':
    case 'fl.oz':
      return 'fl oz';
    case 'l':
      return 'L';
    case 'ml':
      return 'ml';
    case 'kg':
      return 'kg';
    case 'g':
      return 'g';
    case 'lb':
      return 'lb';
    case 'count':
      return 'ct';
    default:
      return raw; // oz, ct
  }
}

String _trimDouble(double v) {
  final s = v.toStringAsFixed(2);
  if (s.endsWith('00')) return v.toStringAsFixed(0);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}

Map<String, dynamic>? normalizeRawItem(
  Map<String, dynamic> raw, {
  required String id,
  required String storeId,
  required String category,
  required String subCategory,
}) {
  final name = (raw['name'] ?? raw['names'] ?? raw['w_iuh7'])?.toString();
  final image = (raw['imageUrl'] ?? raw['image'])?.toString();
  // Accept several potential price holder fields (price, name_1, priceText)
  final dynamic priceSource = raw.containsKey('price') && raw['price'] != null
      ? raw['price']
      : (raw.containsKey('name_1') && raw['name_1'] != null
            ? raw['name_1']
            : raw['priceText']);
  final price = parsePrice(priceSource);
  if (name == null || image == null || price == null) {
    return null; // insufficient data
  }
  return {
    'id': id,
    'name': name,
    'price': price,
    'imageUrl': image,
    'description': null,
    'benefits': null,
    'unit': extractUnit(name),
    'unitInfo': parseUnitStructured(name)?.toJson(),
    'storeId': storeId,
    'category': category,
    'subCategory': subCategory,
  };
}

Future<void> main(List<String> args) async {
  final argMap = <String, String>{};
  for (final a in args) {
    final parts = a.split('=');
    if (parts.length == 2 && parts[0].startsWith('--')) {
      argMap[parts[0].substring(2)] = parts[1];
    }
  }
  final rawDir = argMap['rawDir'] ?? './downloads/pantry';
  final configPath = argMap['config'] ?? 'tool/normalize_config.json';
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('Missing config file at $configPath');
    exit(1);
  }
  final config = NormalizeConfig.load(configFile);

  final outputDir = Directory('assets/stores/walmart');
  if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

  for (final entry in config.files) {
    final slug = slugFromFilename(entry.file);
    // Build list of source filenames (single rawFile, explicit list, or default to target file name)
    final sourceNames = <String>[];
    if (entry.rawFiles.isNotEmpty) {
      sourceNames.addAll(entry.rawFiles);
    } else if (entry.rawFile != null) {
      sourceNames.add(entry.rawFile!);
    } else {
      sourceNames.add(entry.file);
    }

    final aggregated = <dynamic>[];
    for (final rawName in sourceNames) {
      final rawSlug = slugFromFilename(rawName);
      final rawPathCandidates = <File>{
        File('$rawDir/$rawName'),
        File('$rawDir/${entry.file}'),
        File('$rawDir/$rawSlug.json'),
        File('$rawDir/$slug.json'),
      }.toList();
      File? rawFile;
      for (final c in rawPathCandidates) {
        if (c.existsSync()) {
          rawFile = c;
          break;
        }
      }
      if (rawFile == null) {
        stderr.writeln(
          '[WARN] Raw file missing for source $rawName (target ${entry.file})',
        );
        continue;
      }
      try {
        final list = jsonDecode(rawFile.readAsStringSync()) as List<dynamic>;
        aggregated.addAll(list);
      } catch (e) {
        stderr.writeln('[ERROR] Failed to parse ${rawFile.path}: $e');
      }
    }
    if (aggregated.isEmpty) {
      stderr.writeln('[WARN] No data aggregated for ${entry.file}');
      continue;
    }

    final normalized = <Map<String, dynamic>>[];
    final seenNames = <String>{};
    var counter = 0;
    for (final item in aggregated) {
      if (item is! Map<String, dynamic>) continue;
      final name = (item['name'] ?? item['names'] ?? item['w_iuh7'])
          ?.toString();
      if (name == null) continue;
      // Exclusion filters (by regex patterns).
      var excluded = false;
      for (final pat in entry.excludeNamePatterns) {
        if (pat.hasMatch(name)) {
          excluded = true;
          break;
        }
      }
      if (excluded) continue;
      if (seenNames.contains(name)) {
        continue; // dedupe by name
      }
      counter += 1;
      final id = 'walmart_${slug}_${counter.toString().padLeft(3, '0')}';
      // Determine subCategory (classification override if rules present)
      var effectiveSubCategory = entry.subCategory;
      if (entry.classificationRules.isNotEmpty) {
        final lname = name.toLowerCase();
        bool matched = false;
        for (final rule in entry.classificationRules) {
          for (final r in rule.match) {
            if (r.hasMatch(lname)) {
              effectiveSubCategory = rule.subCategory;
              matched = true;
              break;
            }
          }
          if (matched) break;
        }
        if (!matched && entry.defaultSubCategory != null) {
          effectiveSubCategory = entry.defaultSubCategory!;
        }
      }

      final normalizedItem = normalizeRawItem(
        item,
        id: id,
        storeId: config.storeId,
        category: config.category,
        subCategory: effectiveSubCategory,
      );
      if (normalizedItem != null) {
        normalized.add(normalizedItem);
        seenNames.add(name);
      }
    }

    // Advanced dedupe (second pass) if enabled.
    final beforeCount = normalized.length;
    final finalList = config.advancedDedupe.enabled
        ? _advancedDedupe(normalized, config.advancedDedupe)
        : normalized;
    final afterCount = finalList.length;
    if (beforeCount != afterCount) {
      _appendDedupeAudit(
        category: config.category,
        targetFile: entry.file,
        before: beforeCount,
        after: afterCount,
      );
    }

    if (entry.splitPerSubCategory) {
      // group by subCategory and write separate files derived from base slug + subcategory slug
      final bySub = <String, List<Map<String, dynamic>>>{};
      for (final item in finalList) {
        final sc = (item['subCategory'] ?? entry.subCategory) as String;
        bySub.putIfAbsent(sc, () => []).add(item);
      }
      for (final kv in bySub.entries) {
        final sc = kv.key;
        final items = kv.value;
        final scSlug = slugFromFilename(
          sc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        );
        final outFile = File('${outputDir.path}/${slug}__${scSlug}.json');
        outFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(items),
        );
        stdout.writeln(
          '[OK] (${config.category}) ${sc}: ${items.length} items (split) -> ${outFile.path}',
        );
      }
    } else {
      final outFile = File('${outputDir.path}/$slug.json');
      outFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(finalList),
      );
      stdout.writeln(
        '[OK] (${config.category}) ${entry.subCategory}: ${finalList.length} items (raw ${normalized.length}) -> ${outFile.path}',
      );
    }
  }

  stdout.writeln('Normalization complete.');
}

void _appendDedupeAudit({
  required String category,
  required String targetFile,
  required int before,
  required int after,
}) {
  try {
    final reportDir = Directory('assets/stores/walmart/reports');
    if (!reportDir.existsSync()) reportDir.createSync(recursive: true);
    final f = File('${reportDir.path}/dedupe_audit.jsonl');
    final delta = before - after;
    final pct = before == 0 ? 0 : (delta / before * 100);
    final line = jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'category': category,
      'targetFile': targetFile,
      'before': before,
      'after': after,
      'removed': delta,
      'removedPct': double.parse(pct.toStringAsFixed(2)),
    });
    f.writeAsStringSync(line + '\n', mode: FileMode.append, flush: true);
  } catch (e) {
    stderr.writeln('[WARN] Failed to write dedupe audit: $e');
  }
}

List<Map<String, dynamic>> _advancedDedupe(
  List<Map<String, dynamic>> items,
  AdvancedDedupeConfig cfg,
) {
  final result = <Map<String, dynamic>>[];
  final byKey = <String, Map<String, dynamic>>{};
  for (final item in items) {
    final name = (item['name'] ?? '').toString();
    final key = _baseKey(name, item['unit']?.toString(), cfg);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = item;
    } else {
      // Decide merge
      final p1 = (existing['price'] as num).toDouble();
      final p2 = (item['price'] as num).toDouble();
      final diffPct = (p1 == 0 || p2 == 0)
          ? 0
          : ((p1 - p2).abs() / (p1 < p2 ? p1 : p2) * 100);
      if (diffPct > cfg.priceVariancePct) {
        // treat as distinct despite same base key: create variant key with price suffix
        final variantKey = '$key#${p2.toStringAsFixed(2)}';
        if (!byKey.containsKey(variantKey)) byKey[variantKey] = item;
      } else {
        // choose better quality: has unit > missing unit, lower price favored
        final existingHasUnit = (existing['unit'] != null);
        final currentHasUnit = (item['unit'] != null);
        if (!existingHasUnit && currentHasUnit) {
          byKey[key] = item;
        } else if (existingHasUnit == currentHasUnit) {
          if (p2 < p1) byKey[key] = item; // cheaper
        }
      }
    }
  }
  result.addAll(byKey.values);
  return result;
}

String _baseKey(String name, String? unit, AdvancedDedupeConfig cfg) {
  var n = name.toLowerCase();
  // Remove punctuation
  n = n.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  // Remove stop words
  for (final sw in cfg.stopWords) {
    n = n.replaceAll(sw, ' ');
  }
  if (cfg.mode == 'conservative') {
    // Keep pack & size distinctions unless ignoring pack differences
    if (!cfg.ignorePackDifferences) {
      // leave as is
    }
  } else {
    // aggressive: remove common marketing terms
    n = n.replaceAll(
      RegExp(
        r'\b(family size|original|value pack|gluten free|non gmo|made with|naturally flavored)\b',
      ),
      ' ',
    );
  }
  // Collapse whitespace
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  return unit != null ? '$n|$unit' : n;
}
