// Description Enrichment Tool
// ---------------------------------------------------------------------------
// Generates neutral factual `description` text for products missing one
// (unless --force). Uses existing local metadata only (brand, name, pack/size)
// plus an optional usage sentence from a template JSON.
// Safe: no external fetching; deterministic & idempotent.
//
// Usage:
//   dart run tool/enrich_descriptions.dart \
//     --mapping assets/stores/walmart/walmart_categories.json \
//     [--mapping <other_mapping.json> ...] \
//     [--templates assets/config/description_templates.json] \
//     [--dry-run] [--force] [--pretty]
//
// Template JSON example (optional):
// {
//   "type:multivitamins": "Daily multivitamin support for overall wellness.",
//   "section:Vitamins": "Supports everyday vitamin & supplement needs.",
//   "category:Pharmacy": "Part of the pharmacy and health assortment."
// }
// Precedence: type > section > category. Fallback: generic sentence.

import 'dart:convert';
import 'dart:io';
import 'description_profiles.dart';

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------
class Args {
  final List<String> mappings;
  final bool dryRun;
  final bool force;
  final bool pretty;
  final String? templatesPath;
  final bool refresh; // regenerate even if existing differs stylistically
  final bool report;
  final bool concise;
  Args({
    required this.mappings,
    required this.dryRun,
    required this.force,
    required this.pretty,
    required this.templatesPath,
    required this.refresh,
    required this.report,
    required this.concise,
  });
  static Args parse(List<String> a) {
    final m = <String>[];
    bool dry = false, force = false, pretty = false;
    bool refresh = false, report = false, concise = false;
    String? tpl;
    for (int i = 0; i < a.length; i++) {
      switch (a[i]) {
        case '--mapping':
          if (i + 1 >= a.length) _fail('Missing value after --mapping');
          m.add(a[++i]);
          break;
        case '--dry-run':
          dry = true;
          break;
        case '--force':
          force = true;
          break;
        case '--pretty':
          pretty = true;
          break;
        case '--templates':
          if (i + 1 >= a.length) _fail('Missing value after --templates');
          tpl = a[++i];
          break;
        case '--refresh':
          refresh = true;
          break;
        case '--report':
          report = true;
          break;
        case '--concise':
          concise = true;
          break;
      }
    }
    if (m.isEmpty) m.add('assets/stores/walmart/walmart_categories.json');
    return Args(
      mappings: m,
      dryRun: dry,
      force: force,
      pretty: pretty,
      templatesPath: tpl,
      refresh: refresh,
      report: report,
      concise: concise,
    );
  }

  static Never _fail(String msg) {
    stderr.writeln(msg);
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
Future<void> main(List<String> raw) async {
  final cfg = Args.parse(raw);
  final templates = await _loadTemplates(cfg.templatesPath);
  final seen = <String>{};
  int files = 0, updated = 0, skipped = 0, scanned = 0;
  final profileStats = <String, int>{};
  final sw = Stopwatch()..start();
  for (final mappingPath in cfg.mappings) {
    final mf = File(mappingPath);
    if (!mf.existsSync()) {
      stderr.writeln('WARN mapping not found: $mappingPath');
      continue;
    }
    dynamic root;
    try {
      root = jsonDecode(await mf.readAsString());
    } catch (e) {
      stderr.writeln('ERROR parse mapping $mappingPath: $e');
      continue;
    }
    if (root is! List) {
      stderr.writeln('WARN mapping root not List: $mappingPath');
      continue;
    }
    for (final cat in root) {
      final category = cat['categoryName'] ?? 'Category';
      final sections = cat['sections'] as List? ?? const [];
      for (final sec in sections) {
        final section = sec['sectionName'] ?? 'Section';
        final types = sec['productTypes'] as List? ?? const [];
        for (final t in types) {
          final type = t['name'] ?? 'Type';
          final path = t['filePath'];
          if (path == null) continue;
          if (!seen.add(path)) continue; // de-dupe
          final pf = File(path);
          if (!pf.existsSync()) {
            stderr.writeln('WARN missing product file: $path');
            continue;
          }
          List data;
          try {
            data = jsonDecode(await pf.readAsString()) as List;
          } catch (e) {
            stderr.writeln('ERROR parse $path: $e');
            continue;
          }
          bool modified = false;
          for (final rec in data) {
            if (rec is! Map) continue;
            scanned++;
            final existing = rec['description'];
            if (!cfg.force &&
                !cfg.refresh &&
                existing is String &&
                existing.trim().isNotEmpty) {
              skipped++;
              continue;
            }
            final desc = _generateDescription(
              rec,
              category: category.toString(),
              section: section.toString(),
              type: type.toString(),
              templates: templates,
              concise: cfg.concise,
              profileStats: profileStats,
            );
            if (desc == null) continue;
            if (!cfg.refresh && existing == desc) continue;
            rec['description'] = desc;
            updated++;
            modified = true;
          }
          if (modified && !cfg.dryRun) {
            final enc = cfg.pretty
                ? const JsonEncoder.withIndent('  ')
                : const JsonEncoder();
            await pf.writeAsString(enc.convert(data) + '\n');
          }
          files++;
          stdout.writeln(
            '${cfg.dryRun ? '[DRY]' : '[OK ]'} ${modified ? 'updated' : 'nochange'} $path',
          );
        }
      }
    }
  }
  sw.stop();
  stdout.writeln(
    'Description enrichment complete in ${sw.elapsedMilliseconds} ms',
  );
  stdout.writeln('  filesProcessed: $files');
  stdout.writeln('  productsScanned: $scanned');
  stdout.writeln('  productsUpdated: $updated');
  stdout.writeln('  productsSkippedExisting: $skipped');
  stdout.writeln('  dryRun: ${cfg.dryRun}');
  if (cfg.report && profileStats.isNotEmpty) {
    stdout.writeln('Profile usage:');
    final keys = profileStats.keys.toList()..sort();
    for (final k in keys) {
      stdout.writeln('  $k: ${profileStats[k]}');
    }
  }
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------
Future<Map<String, dynamic>> _loadTemplates(String? path) async {
  if (path == null) return {};
  final f = File(path);
  if (!f.existsSync()) {
    stderr.writeln('Template file not found: $path (continuing)');
    return {};
  }
  try {
    final d = jsonDecode(await f.readAsString());
    if (d is Map<String, dynamic>) return d;
  } catch (e) {
    stderr.writeln('Template parse error: $e');
  }
  return {};
}

// ---------------------------------------------------------------------------
// Tokenization
// ---------------------------------------------------------------------------
final _packRegex = RegExp(
  r'(\b|^)(\d+)[ ]?(ct|count|pk|pack)\b',
  caseSensitive: false,
);
final _multiUnitRegex = RegExp(
  r'(\d+)\s?[xX]\s?(\d+(?:\.\d+)?)\s?(fl ?oz|oz|ml|g|lb)\b',
  caseSensitive: false,
);
final _sizeRegex = RegExp(
  r'(\d+(?:\.\d+)?)\s?(fl ?oz|oz|ml|g|lb)\b',
  caseSensitive: false,
);

class _Tok {
  final int? pack;
  final double? size;
  final String? unit;
  final String base;
  _Tok(this.pack, this.size, this.unit, this.base);
}

_Tok _tokenize(String name) {
  int? pack;
  double? size;
  String? unit;
  final multi = _multiUnitRegex.firstMatch(name);
  if (multi != null) {
    pack = int.tryParse(multi.group(1)!);
    size = double.tryParse(multi.group(2)!);
    unit = _normUnit(multi.group(3)!);
  } else {
    final p = _packRegex.firstMatch(name);
    if (p != null) pack = int.tryParse(p.group(2)!);
    final s = _sizeRegex.firstMatch(name);
    if (s != null) {
      size = double.tryParse(s.group(1)!);
      unit = _normUnit(s.group(2)!);
    }
  }
  final base = name
      .replaceAll(_packRegex, ' ')
      .replaceAll(_multiUnitRegex, ' ')
      .replaceAll(_sizeRegex, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return _Tok(pack, size, unit, base);
}

// ---------------------------------------------------------------------------
// Description generation
// ---------------------------------------------------------------------------
String? _generateDescription(
  Map rec, {
  required String category,
  required String section,
  required String type,
  required Map<String, dynamic> templates,
  required bool concise,
  required Map<String, int> profileStats,
}) {
  final name = _as(rec['name']);
  if (name.isEmpty) return null;
  final brand = _as(rec['brand']);
  final tok = _tokenize(name);
  String who = brand.isNotEmpty ? brand : name.split(' ').first;
  String adjustedBase = tok.base;
  // If the first word of base matches brand (or its first token), avoid duplication
  final baseTokens = adjustedBase.split(' ');
  if (baseTokens.isNotEmpty) {
    final brandFirst = who.split(' ').first;
    if (brandFirst.toLowerCase() == baseTokens.first.toLowerCase() &&
        baseTokens.length > 1) {
      baseTokens.removeAt(0);
      adjustedBase = baseTokens.join(' ').trim();
    }
  }
  // If brand is multi-token and base begins with the last brand token (e.g. "Great Value Value Root Beer") remove that duplicate leading token.
  final brandTokens = who.split(' ');
  if (brandTokens.length > 1 && baseTokens.isNotEmpty) {
    final lastBrand = brandTokens.last.toLowerCase();
    if (baseTokens.isNotEmpty && baseTokens.first.toLowerCase() == lastBrand) {
      baseTokens.removeAt(0);
      adjustedBase = baseTokens.join(' ').trim();
    }
  }
  final base = _cap(adjustedBase);

  final unitSentence = _unitSentence(tok);

  // Domain profiles
  final domain = buildDomainProfileDescription(
    brand: who,
    name: name,
    type: type,
    section: section,
    category: category,
    baseName: base,
    packSentence: unitSentence,
    concise: concise,
  );
  if (domain != null) {
    profileStats.update(domain.profile.id, (v) => v + 1, ifAbsent: () => 1);
    return domain.description;
  }

  // Specialized beer logic (deterministic, fact-based, no external text)
  final lowerSection = section.toLowerCase();
  final lowerType = type.toLowerCase();
  final lowerName = name.toLowerCase();
  final isBeer =
      lowerSection.contains('alcohol') &&
      (lowerType.contains('beer') || lowerName.contains(' beer'));
  if (isBeer) {
    final beer = _beerDescription(
      brand: who,
      name: name,
      tok: tok,
      section: section,
      category: category,
      concise: concise,
    );
    if (beer != null) return beer;
  }
  final usage = _usageSentence(
    category: category,
    section: section,
    type: type,
    templates: templates,
  );
  final rawDesc = [
    '$who $base${unitSentence.isNotEmpty ? ' $unitSentence' : ''}.',
    if (usage.isNotEmpty) usage,
  ].join(' ').trim();
  return _cleanDescription(rawDesc);
}

String _unitSentence(_Tok t) {
  if (t.pack != null && t.size != null && t.unit != null) {
    final total = t.pack! * t.size!;
    return 'comes in a pack of ${t.pack} with each ${_numStr(t.size!)} ${t.unit}, totaling ${_numStr(total)} ${t.unit}';
  }
  if (t.pack != null) return 'comes in a pack of ${t.pack}';
  if (t.size != null && t.unit != null)
    return 'provides ${_numStr(t.size!)} ${t.unit}';
  return '';
}

String _usageSentence({
  required String category,
  required String section,
  required String type,
  required Map<String, dynamic> templates,
}) {
  final tk = 'type:${type.toLowerCase()}';
  final sk = 'section:${section.toLowerCase()}';
  final ck = 'category:${category.toLowerCase()}';
  if (templates[tk] is String) return templates[tk];
  if (templates[sk] is String) return templates[sk];
  if (templates[ck] is String) return templates[ck];
  return 'Designed for everyday ${section.toLowerCase()} needs within the ${category.toLowerCase()} category.';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _as(dynamic v) => v == null
    ? ''
    : v is String
    ? v
    : v.toString();
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _normUnit(String raw) {
  raw = raw.toLowerCase();
  if (raw.contains('fl')) return 'fl oz';
  switch (raw) {
    case 'oz':
    case 'ml':
    case 'g':
    case 'lb':
      return raw;
  }
  return raw;
}

String _numStr(num v) {
  final s = v.toString();
  if (!s.contains('.')) return s;
  final t = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return t;
}

// ---------------------------------------------------------------------------
// Post-generation cleanup
// ---------------------------------------------------------------------------
String _cleanDescription(String d) {
  // Remove duplicate commas / spaces
  d = d.replaceAll(RegExp(r',\s*,+'), ', ');
  d = d.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Collapse adjacent duplicate tokens (case-insensitive) for tokens longer than 2 chars
  final parts = d.split(' ');
  final cleaned = <String>[];
  for (final p in parts) {
    if (cleaned.isNotEmpty &&
        cleaned.last.length > 2 &&
        p.length > 2 &&
        cleaned.last.toLowerCase() == p.toLowerCase()) {
      continue;
    }
    cleaned.add(p);
  }
  d = cleaned.join(' ');
  // Fix patterns like ' ,'
  d = d.replaceAll(' ,', ',');
  return d;
}

// ---------------------------------------------------------------------------
// Beer style lexicon & generator (deterministic, safe)
// ---------------------------------------------------------------------------
// Minimal curated data; extend as needed. Each style provides body, flavor
// adjectives selected to remain generic and factual.
const Map<String, Map<String, dynamic>> _beerStyles = {
  'lager': {
    'adjectives': ['crisp', 'light-bodied'],
    'flavor': 'clean finish with mild grain sweetness',
  },
  'pilsner': {
    'adjectives': ['crisp', 'golden'],
    'flavor': 'subtle hop bitterness and a clean finish',
  },
  'ipa': {
    'adjectives': ['hop-forward', 'aromatic'],
    'flavor': 'citrus and pine hop notes',
  },
  'stout': {
    'adjectives': ['dark', 'roasty'],
    'flavor': 'notes of coffee and chocolate',
  },
  'porter': {
    'adjectives': ['smooth', 'malty'],
    'flavor': 'subtle roast and cocoa accents',
  },
  'ale': {
    'adjectives': ['balanced', 'easy-drinking'],
    'flavor': 'light malt sweetness and gentle hop finish',
  },
  'wheat': {
    'adjectives': ['smooth', 'hazy'],
    'flavor': 'soft malt body and light fruit hints',
  },
};

final _abvRegex = RegExp(r'(\d{1,2}(?:\.\d)?)\s*%');

String? _beerDescription({
  required String brand,
  required String name,
  required _Tok tok,
  required String section,
  required String category,
  required bool concise,
}) {
  final ln = name.toLowerCase();
  String style = _beerStyles.keys.firstWhere(
    (s) => ln.contains(s),
    orElse: () => 'lager',
  );
  // Avoid generic "beer" duplication in the base name
  var cleaned = name
      .replaceAll(RegExp(RegExp.escape(brand), caseSensitive: false), '')
      .replaceAll(RegExp(r'\bbeer\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) cleaned = style;
  final abvMatch = _abvRegex.firstMatch(name);
  final abv = abvMatch != null ? double.tryParse(abvMatch.group(1)!) : null;
  final profile = _beerStyles[style]!;
  final adjectives = (profile['adjectives'] as List).join(' ');
  final flavor = profile['flavor'];
  final abvPhrase = abv == null
      ? ''
      : abv < 4.2
      ? 'sessionable '
      : abv >= 7.5
      ? 'bold '
      : '';
  final styleLabel = style[0].toUpperCase() + style.substring(1);
  final packSentence = _unitSentence(tok);
  final main =
      '$brand $styleLabel is a ${abvPhrase}${adjectives} $style with $flavor.';
  if (concise) {
    final bits = <String>[main];
    if (abv != null)
      bits.add('ABV ${abv.toStringAsFixed(abv % 1 == 0 ? 0 : 1)}%.');
    if (packSentence.isNotEmpty)
      bits.add('${packSentence[0].toUpperCase()}${packSentence.substring(1)}.');
    return bits.join(' ');
  }
  final sentences = <String>[main];
  if (abv != null)
    sentences.add('ABV ${abv.toStringAsFixed(abv % 1 == 0 ? 0 : 1)}%.');
  if (packSentence.isNotEmpty)
    sentences.add(
      '${packSentence[0].toUpperCase()}${packSentence.substring(1)}.',
    );
  sentences.add(
    'Suitable for everyday enjoyment within the ${category.toLowerCase()} category.',
  );
  return sentences.join(' ');
}
