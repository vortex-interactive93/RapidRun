import 'dart:convert';
import 'dart:io';

/*
Targeted Walmart normalizer.
Only rewrites files that failed audit (0% canonical or missing key clusters) without touching already 100% canonical files.
Canonical schema keys produced: id,name,brand,price,imageUrl,description,benefits,unit,storeId,category,subCategory
Derivation rules:
  - name: prefer 'w_iuh7' then 'title' then 'name'
  - imageUrl: prefer 'imageUrl' then 'image'
  - price: parse last number from any field containing 'price'
  - brand: first capitalized token(s) before a lowercase token or digit (simple heuristic); falls back to first token.
  - unit: extract last pattern like '<number> (oz|fl oz|g|ml|lb|ct|count)' (case-insensitive)
  - id: walmart_<basename>_<zeroPad>
  - category/subCategory derived via walmart_categories.json mapping (same as universal normalizer) or fallback to 'Uncategorized' / file base pretty case.
Skips duplicates by (name + imageUrl).
Run:
  dart run tool/normalize_walmart_targeted.dart
Dry run:
  dart run tool/normalize_walmart_targeted.dart --dry-run
*/

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final mapping = await _loadCategoryMapping();
  // Hard-coded list from recent audit (0% canonical files)
  final targets = <String>[
    'hotdogs.json',
    'cookies.json',
    'snack-nuts.json', // has normalized__ style ids missing brand
    'snack-bars.json',
    'fruit-snacks.json',
    'beef-jerky.json',
    'snack-cakes.json',
    'apple-sauce-fruit-cups.json',
    'domestic-beer.json',
    'imported-beer.json',
    'hard-seltzer.json',
    'flavored-specialty-beer.json',
    'red-wine.json',
    'white-wine.json',
    'sparkling-wine.json',
    'rose-wine.json',
    'sweet-fruit-wine.json',
    'box-carton-wine.json',
    'allergy-medicine.json',
    'cold-flu-medicine.json',
    'childrens-medicine.json',
    'pain-management.json',
    'sleep-support.json',
    'heating-pads.json',
    'first-aid.json',
    'home-health-tests.json',
    'beauty-supplements.json',
    'incontinence.json',
    'menopause.json',
    'period-care.json',
    'pregnancy-tests.json',
    'prenatal-vitamins-supplements.json',
    'sexual-wellness.json',
    'urinary-support.json',
    'womans-multivitamins.json', 'womens-probiotics.json',
  ];
  final storeDir = Directory('assets/stores/walmart');
  if (!storeDir.existsSync()) {
    stderr.writeln('Store dir missing');
    return;
  }
  int files = 0, items = 0, written = 0, skipped = 0;
  for (final base in targets) {
    final file = File('${storeDir.path}/$base');
    if (!file.existsSync()) {
      stderr.writeln('[MISS] $base');
      continue;
    }
    List raw;
    try {
      raw = jsonDecode(await file.readAsString()) as List;
    } catch (e) {
      stderr.writeln('[PARSE] $base: $e');
      continue;
    }
    if (raw.isEmpty) {
      stderr.writeln('[EMPTY] $base');
      continue;
    }
    final alreadyCanonical = raw.every((e) => e is Map && _isCanonical(e));
    if (alreadyCanonical) {
      skipped++;
      continue;
    }
    files++;
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    int idx = 0;
    final catInfo = mapping[base];
    for (final rec in raw) {
      if (rec is! Map) continue;
      final name = _extractName(rec);
      final image = _extractImage(rec);
      if (name == null || image == null) continue;
      final sig = '$name::$image';
      if (!seen.add(sig)) continue;
      final price = _extractPrice(rec);
      final brand = _extractBrand(name);
      final unit = _extractUnit(name);
      idx++;
      final id =
          'walmart_${base.replaceAll('.json', '')}_${idx.toString().padLeft(4, '0')}';
      final normalized = {
        'id': id,
        'name': name,
        'brand': brand,
        'price': price,
        'imageUrl': image,
        'description': rec['description'],
        'benefits': rec['benefits'],
        'unit': unit,
        'storeId': 'walmart',
        'category': catInfo?.category ?? 'Uncategorized',
        'subCategory': catInfo?.subCategory ?? _titleFromBase(base),
      };
      out.add(normalized);
      items++;
    }
    if (!dryRun) {
      final enc = const JsonEncoder.withIndent('  ');
      await file.writeAsString(enc.convert(out));
      written++;
      stdout.writeln('[OK] $base normalized -> ${out.length}');
    } else {
      stdout.writeln('[DRY] $base would normalize -> ${out.length}');
    }
  }
  stdout.writeln(
    'Done. processed=$files written=$written skippedAlreadyCanonical=$skipped itemsOut=$items dryRun=$dryRun',
  );
}

bool _isCanonical(Map e) {
  const keys = [
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
  for (final k in keys) {
    if (!e.containsKey(k)) return false;
  }
  if (e['price'] != null && e['price'] is! num) return false;
  return true;
}

String? _extractName(Map m) {
  return (m['name'] ?? m['w_iuh7'] ?? m['title'])?.toString().trim().isEmpty ==
          true
      ? null
      : (m['name'] ?? m['w_iuh7'] ?? m['title'])?.toString().trim();
}

String? _extractImage(Map m) {
  final v = (m['imageUrl'] ?? m['image']);
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _extractPrice(Map m) {
  for (final entry in m.entries) {
    final k = entry.key.toLowerCase();
    if (k.contains('price')) {
      final v = entry.value.toString();
      final matches = RegExp(r'(\d+\.?\d*)').allMatches(v);
      double? last;
      for (final mm in matches) {
        last = double.tryParse(mm.group(1)!);
      }
      if (last != null) return last;
    }
  }
  return null;
}

String? _extractBrand(String name) {
  final tokens = name.split(RegExp(r'\s+'));
  final collected = <String>[];
  for (final t in tokens) {
    final clean = t.replaceAll(RegExp(r"[^A-Za-z0-9']"), '');
    if (clean.isEmpty) continue;
    final isCap = RegExp(r'^[A-Z]').hasMatch(clean);
    final isNum = RegExp(r'^\d').hasMatch(clean);
    if (collected.isEmpty) {
      if (isCap && !isNum) {
        collected.add(clean);
        continue;
      } else
        break;
    } else {
      if (isCap && collected.length < 2) {
        collected.add(clean);
      }
      break;
    }
  }
  if (collected.isEmpty) return tokens.first;
  return collected.join(' ');
}

String? _extractUnit(String name) {
  final re = RegExp(
    r'(\d+(?:\.\d+)?)\s?(fl ?oz|oz|g|ml|lb|ct|count)',
    caseSensitive: false,
  );
  final all = re.allMatches(name);
  if (all.isEmpty) return null;
  final m = all.last;
  return m.group(0)?.trim();
}

class _CategoryInfo {
  final String category;
  final String subCategory;
  _CategoryInfo(this.category, this.subCategory);
}

Future<Map<String, _CategoryInfo>> _loadCategoryMapping() async {
  final f = File('assets/stores/walmart/walmart_categories.json');
  if (!f.existsSync()) return {};
  try {
    final data = jsonDecode(await f.readAsString());
    if (data is! List) return {};
    final map = <String, _CategoryInfo>{};
    for (final cat in data) {
      if (cat is! Map) continue;
      final catName = cat['categoryName']?.toString();
      final sections = cat['sections'];
      if (catName == null || sections is! List) continue;
      for (final sec in sections) {
        if (sec is! Map) continue;
        final pts = sec['productTypes'];
        if (pts is! List) continue;
        for (final pt in pts) {
          if (pt is! Map) continue;
          final filePath = pt['filePath']?.toString();
          final sub = pt['name']?.toString();
          if (filePath == null || sub == null) continue;
          final fileName = filePath.split('/').last;
          map[fileName] = _CategoryInfo(catName, sub);
        }
      }
    }
    return map;
  } catch (_) {
    return {};
  }
}

String _titleFromBase(String base) {
  final b = base.replaceAll('.json', '');
  return b
      .split(RegExp(r'[-_]'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
