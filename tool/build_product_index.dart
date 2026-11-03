/// Product Index & Variant Grouping Builder
/// Generates a lightweight catalog index with grouped variants (e.g. 12 vs 24 pack)
/// to speed up first render and reduce list clutter.
///
/// Run (from project root):
///   dart run tool/build_product_index.dart \
///       --mapping assets/stores/walmart/walmart_categories.json \
///       --out assets/stores/walmart/_index_catalog.json
///
/// Optional flags:
///   --gzip                (also writes .gz)
///   --pretty              (pretty JSON output)
///   --keepSinglesInGroups (also output individual variants alongside group head)
///
/// Assumed product item fields (best-effort fallback):
///   id, name|title, price|priceText, image|images[0], brand
import 'dart:convert';
import 'dart:io';

class ArgConfig {
  final String mappingPath;
  final String outPath;
  final bool gzip;
  final bool pretty;
  final bool keepSinglesInGroups;
  ArgConfig({
    required this.mappingPath,
    required this.outPath,
    required this.gzip,
    required this.pretty,
    required this.keepSinglesInGroups,
  });
  static ArgConfig parse(List<String> args) {
    String mapping = 'assets/stores/walmart/walmart_categories.json';
    String out = 'assets/stores/walmart/_index_catalog.json';
    bool gzip = false;
    bool pretty = false;
    bool keep = false;
    for (int i = 0; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--mapping':
          mapping = args[++i];
          break;
        case '--out':
          out = args[++i];
          break;
        case '--gzip':
          gzip = true;
          break;
        case '--pretty':
          pretty = true;
          break;
        case '--keepSinglesInGroups':
          keep = true;
          break;
      }
    }
    return ArgConfig(
      mappingPath: mapping,
      outPath: out,
      gzip: gzip,
      pretty: pretty,
      keepSinglesInGroups: keep,
    );
  }
}

class IndexItem {
  String id;
  String name;
  String? brand;
  double? price;
  String displayPrice;
  String image;
  String category;
  String section;
  String type;
  int? packCount;
  double? sizePerUnit;
  String? sizeUnit;
  String? flavor;
  String baseName;
  String? groupKey;
  double? pricePerUnit;
  bool isGroupHead = false;
  List<Map<String, dynamic>>? variants;
  IndexItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.displayPrice,
    required this.image,
    required this.category,
    required this.section,
    required this.type,
    required this.packCount,
    required this.sizePerUnit,
    required this.sizeUnit,
    required this.flavor,
    required this.baseName,
    required this.groupKey,
    required this.pricePerUnit,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (brand != null) 'brand': brand,
    if (price != null) 'price': price,
    'displayPrice': displayPrice,
    'image': image,
    'category': category,
    'section': section,
    'type': type,
    if (packCount != null) 'packCount': packCount,
    if (sizePerUnit != null) 'sizePerUnit': sizePerUnit,
    if (sizeUnit != null) 'sizeUnit': sizeUnit,
    if (flavor != null) 'flavor': flavor,
    'baseName': baseName,
    if (groupKey != null) 'groupKey': groupKey,
    if (pricePerUnit != null) 'pricePerUnit': pricePerUnit,
    if (isGroupHead) 'isGroupHead': true,
    if (variants != null) 'variants': variants,
  };
}

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
final _flavorRegex = RegExp(
  r'(?:(?:- |\(|\b)(vanilla|cherry|original|classic|lime|lemon|orange|grape|strawberry|cola|diet cola))(\b|\)| -)',
  caseSensitive: false,
);
final _stripTokensRegex = RegExp(
  r'(\d+\s?(ct|count|pk|pack))|((\d+)[xX](\d+(?:\.\d+)?)(fl ?oz|oz|ml|g|lb))|(\d+(?:\.\d+)?\s?(fl ?oz|oz|ml|g|lb))',
  caseSensitive: false,
);

void main(List<String> args) async {
  final cfg = ArgConfig.parse(args);
  final sw = Stopwatch()..start();
  final items = <IndexItem>[];
  final missingFiles = <String>[]; // capture missing product JSON asset files

  final mappingFile = File(cfg.mappingPath);
  if (!mappingFile.existsSync()) {
    stderr.writeln('Mapping file not found: ${cfg.mappingPath}');
    exit(1);
  }
  final mappingJson = jsonDecode(mappingFile.readAsStringSync());
  if (mappingJson is! List) {
    stderr.writeln('Mapping JSON root must be a list.');
    exit(1);
  }

  for (final cat in mappingJson) {
    final categoryName = cat['categoryName'] ?? 'Unknown';
    final sections = cat['sections'] as List? ?? const [];
    for (final sec in sections) {
      final sectionName = sec['sectionName'] ?? 'UnknownSection';
      final productTypes = sec['productTypes'] as List? ?? const [];
      for (final pt in productTypes) {
        final typeName = pt['name'] ?? 'UnknownType';
        final filePath = pt['filePath'];
        if (filePath == null) continue;
        final f = File(filePath);
        if (!f.existsSync()) {
          stderr.writeln('WARN missing product file: $filePath');
          missingFiles.add(filePath);
          continue;
        }
        late final List data;
        try {
          data = jsonDecode(f.readAsStringSync()) as List;
        } catch (e) {
          stderr.writeln('ERROR parsing $filePath: $e');
          continue;
        }
        for (final raw in data) {
          if (raw is! Map) continue;
          final id =
              _asString(raw['id']) ??
              _hashFallback(raw['name'] ?? raw['title']);
          final name = _asString(raw['name'] ?? raw['title']) ?? 'Unnamed';
          final brand = _asString(raw['brand']);
          final price = _extractPrice(raw);
          final displayPrice = price != null
              ? _formatPrice(price)
              : (_asString(raw['priceText']) ?? '');
          final image = _extractImage(raw) ?? '';
          final enriched = _enrichTokens(name);
          final baseName = enriched.baseName;
          final packCount = enriched.packCount;
          final sizePerUnit = enriched.sizePerUnit;
          final sizeUnit = enriched.sizeUnit;
          final flavor = enriched.flavor;
          final pricePerUnit = _computePricePerUnit(
            price,
            packCount,
            sizePerUnit,
            sizeUnit,
          );
          final groupKey = _computeGroupKey(
            brand,
            baseName,
            flavor,
            sizeUnit,
            sizePerUnit,
          );

          items.add(
            IndexItem(
              id: id,
              name: name,
              brand: brand,
              price: price,
              displayPrice: displayPrice,
              image: image,
              category: categoryName,
              section: sectionName,
              type: typeName,
              packCount: packCount,
              sizePerUnit: sizePerUnit,
              sizeUnit: sizeUnit,
              flavor: flavor,
              baseName: baseName,
              groupKey: groupKey,
              pricePerUnit: pricePerUnit,
            ),
          );
        }
      }
    }
  }

  final grouping = _applyGrouping(items, keepSingles: cfg.keepSinglesInGroups);
  _writeOutput(grouping.output, cfg);
  _writeMetaSidecar(
    cfg,
    totalRaw: items.length,
    totalOutput: grouping.output.length,
    groupCount: grouping.groupCount,
    collapsedVariants: grouping.collapsedVariants,
    missingFiles: missingFiles,
    elapsedMs: sw.elapsedMilliseconds,
  );
  sw.stop();
  stdout.writeln(
    'Index complete: ${grouping.output.length} records (from ${items.length} raw) in ${sw.elapsedMilliseconds} ms | groups: ${grouping.groupCount} | collapsed variants: ${grouping.collapsedVariants}',
  );
}

String _hashFallback(dynamic s) =>
    (s?.toString().hashCode ?? DateTime.now().microsecondsSinceEpoch)
        .toString();

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num) return v.toString();
  return v.toString();
}

double? _extractPrice(Map raw) {
  final p = raw['price'];
  if (p == null) return null;
  if (p is num) return p.toDouble();
  if (p is String) {
    final cleaned = p.replaceAll(RegExp(r'[^0-9\\.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
  return null;
}

String _formatPrice(double value) =>
    '\$${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

String? _extractImage(Map raw) {
  final img = raw['image'];
  if (img is String && img.isNotEmpty) return img;
  final images = raw['images'];
  if (images is List && images.isNotEmpty) {
    final first = images.first;
    if (first is String) return first;
  }
  return null;
}

class _EnrichedTokens {
  final String baseName;
  final int? packCount;
  final double? sizePerUnit;
  final String? sizeUnit;
  final String? flavor;
  _EnrichedTokens(
    this.baseName,
    this.packCount,
    this.sizePerUnit,
    this.sizeUnit,
    this.flavor,
  );
}

_EnrichedTokens _enrichTokens(String name) {
  int? packCount;
  double? sizePerUnit;
  String? sizeUnit;
  String? flavor;

  final multi = _multiUnitRegex.firstMatch(name);
  if (multi != null) {
    packCount = int.tryParse(multi.group(1)!);
    sizePerUnit = double.tryParse(multi.group(2)!);
    sizeUnit = _normalizeUnit(multi.group(3)!);
  } else {
    final pack = _packRegex.firstMatch(name);
    if (pack != null) {
      packCount = int.tryParse(pack.group(2)!);
    }
    final size = _sizeRegex.firstMatch(name);
    if (size != null) {
      sizePerUnit = double.tryParse(size.group(1)!);
      sizeUnit = _normalizeUnit(size.group(2)!);
    }
  }

  final flav = _flavorRegex.firstMatch(name);
  if (flav != null) {
    flavor = flav.group(1)!.toLowerCase();
  }

  var base = name
      .replaceAll(
        _stripTokensRegex,
        ' ',
      ) // ensure tokens leave a space boundary
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
  // Remove remaining pack/count words (case-insensitive) without using inline (?i) flag
  base = base
      .replaceAll(RegExp(r'\\b(pack|ct|count)\\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
  return _EnrichedTokens(
    base.toLowerCase(),
    packCount,
    sizePerUnit,
    sizeUnit,
    flavor,
  );
}

String? _normalizeUnit(String raw) {
  raw = raw.toLowerCase();
  if (raw.contains('fl')) return 'fl_oz';
  if (raw == 'oz') return 'oz';
  if (raw == 'ml') return 'ml';
  if (raw == 'g') return 'g';
  if (raw == 'lb') return 'lb';
  return raw;
}

double? _computePricePerUnit(
  double? price,
  int? packCount,
  double? sizePerUnit,
  String? sizeUnit,
) {
  if (price == null) return null;
  if (packCount != null && sizePerUnit != null) {
    final total = packCount * sizePerUnit;
    if (total > 0) return price / total;
  }
  if (sizePerUnit != null && packCount == null) {
    if (sizePerUnit > 0) return price / sizePerUnit;
  }
  return null;
}

String? _computeGroupKey(
  String? brand,
  String baseName,
  String? flavor,
  String? sizeUnit,
  double? sizePerUnit,
) {
  if (baseName.length < 4) return null;
  final b = brand?.toLowerCase().trim() ?? '';
  final f = flavor?.toLowerCase().trim() ?? '';
  final unit = sizeUnit ?? '';
  final size = sizePerUnit != null ? sizePerUnit.round().toString() : '';
  return [b, baseName, f, unit, size].where((e) => e.isNotEmpty).join('|');
}

class _GroupingResult {
  final List<Map<String, dynamic>> output;
  final int groupCount;
  final int collapsedVariants; // total variants hidden beyond group heads
  _GroupingResult(this.output, this.groupCount, this.collapsedVariants);
}

_GroupingResult _applyGrouping(
  List<IndexItem> items, {
  required bool keepSingles,
}) {
  final byKey = <String, List<IndexItem>>{};
  for (final item in items) {
    final key = item.groupKey;
    if (key == null) continue;
    byKey.putIfAbsent(key, () => []).add(item);
  }

  final groupHeads = <IndexItem>[];
  final groupedIds = <String>{};
  int totalVariantsInGroups = 0;
  for (final entry in byKey.entries) {
    final list = entry.value;
    if (list.length < 2) continue;
    list.sort((a, b) {
      final pc = (a.packCount ?? 0).compareTo(b.packCount ?? 0);
      if (pc != 0) return pc;
      return (a.pricePerUnit ?? double.infinity).compareTo(
        b.pricePerUnit ?? double.infinity,
      );
    });
    final head = list.first;
    head.isGroupHead = true;
    head.variants = list
        .map(
          (v) => {
            'id': v.id,
            'name': v.name,
            if (v.packCount != null) 'packCount': v.packCount,
            if (v.price != null) 'price': v.price,
            'displayPrice': v.displayPrice,
            if (v.pricePerUnit != null) 'pricePerUnit': v.pricePerUnit,
            if (v.sizePerUnit != null) 'sizePerUnit': v.sizePerUnit,
            if (v.sizeUnit != null) 'sizeUnit': v.sizeUnit,
          },
        )
        .toList();
    groupHeads.add(head);
    groupedIds.addAll(list.map((e) => e.id));
    totalVariantsInGroups += head.variants!.length;
  }

  final output = <Map<String, dynamic>>[];
  for (final g in groupHeads) {
    output.add(g.toJson());
  }
  for (final item in items) {
    if (groupedIds.contains(item.id)) {
      if (item.isGroupHead) continue;
      if (!keepSingles) continue;
    }
    if (!item.isGroupHead) {
      output.add(item.toJson());
    }
  }

  output.sort((a, b) {
    int cmp(String k) => (a[k] as String).compareTo(b[k] as String);
    final byCat = cmp('category');
    if (byCat != 0) return byCat;
    final bySec = cmp('section');
    if (bySec != 0) return bySec;
    final byType = cmp('type');
    if (byType != 0) return byType;
    return (a['baseName'] as String).compareTo(b['baseName'] as String);
  });
  final groupCount = groupHeads.length;
  final collapsedVariants =
      totalVariantsInGroups - groupCount; // variants beyond heads
  return _GroupingResult(output, groupCount, collapsedVariants);
}

void _writeOutput(List<Map<String, dynamic>> data, ArgConfig cfg) {
  final outFile = File(cfg.outPath);
  outFile.parent.createSync(recursive: true);
  final encoder = cfg.pretty
      ? const JsonEncoder.withIndent('  ')
      : const JsonEncoder();
  final jsonStr = encoder.convert(data);
  outFile.writeAsStringSync(jsonStr);
  stdout.writeln('Wrote index: ${cfg.outPath} (${jsonStr.length} bytes)');
  if (cfg.gzip) {
    try {
      final gz = GZipCodec(
        level: ZLibOption.defaultLevel,
      ).encode(utf8.encode(jsonStr));
      final gzFile = File('${cfg.outPath}.gz');
      gzFile.writeAsBytesSync(gz, flush: true);
      stdout.writeln('Wrote gzip: ${gzFile.path} (${gz.length} bytes)');
    } catch (e) {
      stderr.writeln('Failed gzip: $e');
    }
  }
}

void _writeMetaSidecar(
  ArgConfig cfg, {
  required int totalRaw,
  required int totalOutput,
  required int groupCount,
  required int collapsedVariants,
  required List<String> missingFiles,
  required int elapsedMs,
}) {
  final meta = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'mapping': cfg.mappingPath,
    'out': cfg.outPath,
    'gzip': cfg.gzip,
    'pretty': cfg.pretty,
    'keepSinglesInGroups': cfg.keepSinglesInGroups,
    'stats': {
      'totalRawItems': totalRaw,
      'totalOutputItems': totalOutput,
      'groupCount': groupCount,
      'collapsedVariants': collapsedVariants,
      'reductionPercent': totalRaw == 0
          ? 0
          : (((totalRaw - totalOutput) / totalRaw) * 100).toStringAsFixed(2),
      'elapsedMs': elapsedMs,
    },
    if (missingFiles.isNotEmpty) 'missingProductFiles': missingFiles,
  };
  final metaFile = File('${cfg.outPath}.meta.json');
  metaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(meta));
  stdout.writeln(
    'Wrote meta: ${metaFile.path} (groups: $groupCount, collapsed: $collapsedVariants, missingFiles: ${missingFiles.length})',
  );
}
