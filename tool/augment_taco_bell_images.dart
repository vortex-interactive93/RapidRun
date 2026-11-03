/// Augments Taco Bell product JSON files with imageUrl values from a CSV.
///
/// Expected CSV headers (order agnostic):
///   id,name,imageUrl
/// You can provide either `id` (preferred) or `name` for matching. If both are
/// present, id match is attempted first; if not found, falls back to name.
///
/// Matching strategy:
/// 1. Exact id match (case sensitive first, then case insensitive)
/// 2. Name slug match (normalize: lowercase, remove non-alphanumeric, collapse spaces)
/// 3. (Optional extension) Fuzzy distance threshold (not implemented yet to avoid
///    accidental mis-assignment — add if needed).
///
/// Usage (from repo root):
///   dart run tool/augment_taco_bell_images.dart \
///       --csv=./imports/taco_bell_images.csv \
///       [--dryRun]
///
/// The script will:
///   - Load all Taco Bell product JSON arrays in assets/stores/taco_bell/*.json
///     (excluding category meta & modifier sets files)
///   - For each CSV row, attempt a match and add or update the `imageUrl` field
///   - Preserve existing formatting (pretty-print 2-space indent) for touched files
///   - Report summary + any unmatched or duplicate issues
///
/// Place your CSV at the path you pass to --csv. Example CSV:
/// id,imageUrl
/// taco_bell_breakfast_crunchwrap_bacon_breakfast,https://www.tacobell.com/images/30028_breakfast_crunchwrap_sausage_patty_750x340.jpg
/// taco_bell_cheesy_toasted_breakfast_burrito_bacon_breakfast,https://www.tacobell.com/images/12345_cheesy_toasted_breakfast_burrito_bacon_300x300.jpg
///
import 'dart:convert';
import 'dart:io';

/// Enhancements (2025-08-25):
/// - Extended normalization to better match names containing trademark symbols
///   (® / ™), variant suffixes and marketing words (Combo / Pack).
/// - Alias mapping via --alias=<json>. JSON map: slug -> id | [ids]. Slug is
///   generated from CSV name using `_primarySlugs` (base + cleaned variant).
/// - Export unmatched rows with --unmatchedCsv=<path> for iterative curation.
/// - Additional reporting: alias-applied rows count.

void main(List<String> args) async {
  final argMap = _parseArgs(args);
  final csvPath = argMap['csv'];
  final dryRun = argMap.containsKey('dryRun');
  final aliasPath = argMap['alias'];
  final unmatchedOutPath = argMap['unmatchedCsv'];
  if (csvPath == null) {
    stderr.writeln('ERROR: --csv=<path> is required');
    exit(2);
  }
  final csvFile = File(csvPath);
  if (!csvFile.existsSync()) {
    stderr.writeln('ERROR: CSV not found: $csvPath');
    exit(2);
  }

  final tacoDir = Directory('assets/stores/taco_bell');
  if (!tacoDir.existsSync()) {
    stderr.writeln('ERROR: Taco Bell directory not found at ${tacoDir.path}');
    exit(2);
  }

  final productFiles = tacoDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) => !f.path.endsWith('taco_bell_categories.json'))
      .where((f) => !f.path.endsWith('_modifier_sets.json'))
      .toList();

  // Load all products into memory.
  final productsByFile = <File, List<Map<String, dynamic>>>{};
  final idIndex = <String, MapEntry<File, Map<String, dynamic>>>{};
  final slugIndex = <String, List<MapEntry<File, Map<String, dynamic>>>>{};

  for (final file in productFiles) {
    try {
      final raw = await file.readAsString();
      final data = json.decode(raw);
      if (data is! List) continue; // skip unexpected
      final list = data
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      productsByFile[file] = list;
      for (final p in list) {
        final id = p['id'] as String?;
        final name = p['name'] as String?;
        if (id != null) {
          idIndex[id] = MapEntry(file, p);
        }
        if (name != null) {
          final slug = _slug(name);
          slugIndex.putIfAbsent(slug, () => []).add(MapEntry(file, p));
        }
      }
    } catch (e) {
      stderr.writeln('WARN: Failed to parse ${file.path}: $e');
    }
  }

  final csvLines = await csvFile.readAsLines();
  if (csvLines.isEmpty) {
    stderr.writeln('ERROR: CSV empty');
    exit(2);
  }

  // Parse header
  final headerParts = _splitCsv(csvLines.first);
  final colIndex = <String, int>{};
  for (var i = 0; i < headerParts.length; i++) {
    colIndex[headerParts[i].trim().toLowerCase()] = i;
  }
  bool hasId = colIndex.containsKey('id');
  bool hasName = colIndex.containsKey('name');
  if (!hasId && !hasName) {
    stderr.writeln(
      'ERROR: CSV must include either id or name column. Found headers: ${headerParts.join(', ')}',
    );
    exit(2);
  }
  if (!colIndex.containsKey('imageurl')) {
    stderr.writeln(
      'ERROR: CSV must include imageUrl column. Found headers: ${headerParts.join(', ')}',
    );
    exit(2);
  }

  final added = <String, String>{};
  final updated = <String, String>{};
  final skipped = <String, String>{};
  final unmatched = <String, String>{};
  final collisions = <String, List<String>>{}; // slug -> list ids
  final aliasApplied = <String, List<String>>{}; // csv name/id -> applied ids
  final unmatchedRawLines = <String>[]; // raw CSV lines for unmatched rows

  // Optional alias map loading.
  final aliasMap = <String, List<String>>{}; // slug -> product ids
  if (aliasPath != null) {
    final aliasFile = File(aliasPath);
    if (aliasFile.existsSync()) {
      try {
        final raw = json.decode(await aliasFile.readAsString());
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is String) {
              aliasMap[_slug(k)] = [v];
            } else if (v is List) {
              aliasMap[_slug(k)] = v.whereType<String>().toList();
            }
          });
        }
      } catch (e) {
        stderr.writeln('WARN: Failed to parse alias file $aliasPath: $e');
      }
    } else {
      stderr.writeln('INFO: Alias file not found at $aliasPath (ignored)');
    }
  }

  for (final line in csvLines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final parts = _splitCsv(line);
    String? id = hasId ? parts[colIndex['id']!] : null;
    String? name = hasName ? parts[colIndex['name']!] : null;
    final imageUrl = parts[colIndex['imageurl']!].trim();
    if (imageUrl.isEmpty) {
      skipped[line] = 'missing imageUrl';
      continue;
    }
    MapEntry<File, Map<String, dynamic>>? target;

    if (id != null && id.isNotEmpty) {
      target = idIndex[id];
      target ??= idIndex[id.toLowerCase()];
    }

    bool handled = false;

    // Alias mapping resolution if id not found.
    if (target == null &&
        name != null &&
        name.isNotEmpty &&
        aliasMap.isNotEmpty) {
      final slugs = _primarySlugs(name);
      for (final s in slugs) {
        final ids = aliasMap[s];
        if (ids != null && ids.isNotEmpty) {
          final appliedIds = <String>[];
          for (final aliasId in ids) {
            final entry = idIndex[aliasId];
            if (entry != null) {
              _applyImage(
                entry.value,
                imageUrl,
                added,
                updated,
                skipped,
                aliasId,
                name,
                line,
              );
              appliedIds.add(aliasId);
            } else {
              unmatched[aliasId] = 'alias id not found';
            }
          }
          if (appliedIds.isNotEmpty) {
            // Here name is non-null (branch guard) so safe to use.
            final aliasKey = name.isNotEmpty ? name : (id ?? line);
            aliasApplied[aliasKey] = appliedIds;
            handled = true;
            break;
          }
        }
      }
    }

    if (handled) continue;

    if (target == null && name != null && name.isNotEmpty) {
      final slugs = _primarySlugs(name);
      bool multiApplied = false;
      for (final slug in slugs) {
        final candidates = slugIndex[slug];
        if (candidates == null || candidates.isEmpty) continue;
        if (candidates.length > 1) {
          collisions[slug] = candidates
              .map((e) => e.value['id'] as String? ?? '?')
              .toList();
          for (final c in candidates) {
            _applyImage(
              c.value,
              imageUrl,
              added,
              updated,
              skipped,
              id,
              name,
              line,
            );
          }
          multiApplied = true;
          break;
        } else {
          target = candidates.first;
          break;
        }
      }
      if (multiApplied) continue;
    }

    if (target == null) {
      final key = id ?? name ?? line;
      unmatched[key] = 'no match';
      unmatchedRawLines.add(line);
      continue;
    }

    final product = target.value;
    _applyImage(product, imageUrl, added, updated, skipped, id, name, line);
  }

  if (!dryRun) {
    for (final entry in productsByFile.entries) {
      final newJson = const JsonEncoder.withIndent('  ').convert(entry.value);
      await entry.key.writeAsString(newJson + '\n');
    }
  }

  stdout.writeln('=== Taco Bell Image Augmentation Summary ===');
  stdout.writeln('CSV: $csvPath');
  stdout.writeln('Dry Run: $dryRun');
  stdout.writeln('Products files scanned: ${productFiles.length}');
  stdout.writeln('Added imageUrl: ${added.length}');
  stdout.writeln('Updated imageUrl: ${updated.length}');
  stdout.writeln('Skipped rows: ${skipped.length}');
  stdout.writeln('Unmatched rows: ${unmatched.length}');
  stdout.writeln('Ambiguous slug collisions: ${collisions.length}');
  stdout.writeln('Alias applied (rows): ${aliasApplied.length}');

  if (unmatched.isNotEmpty) {
    stdout.writeln('\n-- Unmatched (up to 20) --');
    unmatched.entries
        .take(20)
        .forEach((e) => stdout.writeln('${e.key}: ${e.value}'));
  }
  if (collisions.isNotEmpty) {
    stdout.writeln('\n-- Collisions (slug -> ids) --');
    collisions.forEach((k, v) => stdout.writeln('$k -> ${v.join(', ')}'));
  }
  // Optionally write unmatched lines for follow-up curation.
  if (unmatchedOutPath != null) {
    try {
      final outFile = File(unmatchedOutPath);
      final header = csvLines.first; // original header
      final sink = outFile.openWrite();
      sink.writeln(header);
      for (final l in unmatchedRawLines) {
        sink.writeln(l);
      }
      await sink.flush();
      await sink.close();
      stdout.writeln(
        'Unmatched CSV written to $unmatchedOutPath (${unmatchedRawLines.length} rows)',
      );
    } catch (e) {
      stderr.writeln('WARN: Failed to write unmatched CSV: $e');
    }
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (final a in args) {
    if (a.startsWith('--')) {
      final eq = a.indexOf('=');
      if (eq == -1) {
        map[a.substring(2)] = 'true';
      } else {
        map[a.substring(2, eq)] = a.substring(eq + 1);
      }
    }
  }
  return map;
}

String _slug(String input) {
  final buf = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    if (RegExp(r'[a-z0-9]+').hasMatch(c)) {
      buf.write(c);
    } else if (c == ' ') {
      buf.write('_');
    }
  }
  return buf.toString().replaceAll(RegExp(r'_+'), '_').trim();
}

/// Produce up to two primary slugs for a name (base + cleaned variant).
List<String> _primarySlugs(String name) {
  final base = _slug(name);
  final cleaned = _normalizeNameForMatching(name);
  final enhanced = _slug(cleaned);
  if (base == enhanced) return [base];
  return [base, enhanced];
}

String _normalizeNameForMatching(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp(r'[®™]'), ''); // remove trademark symbols
  s = s.replaceAll(RegExp(r'[–—-]'), ' '); // dashes to space
  s = s.replaceAll(RegExp(r'\([^)]*\)'), ' '); // drop parentheticals
  s = s.replaceAll(RegExp(r'\b(combo|pack)\b'), ' '); // marketing tails
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

List<String> _splitCsv(String line) {
  // Simple CSV splitter handling quoted fields.
  final result = <String>[];
  final sb = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i++; // skip escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      result.add(sb.toString());
      sb.clear();
    } else {
      sb.write(ch);
    }
  }
  result.add(sb.toString());
  return result;
}

void _applyImage(
  Map<String, dynamic> product,
  String imageUrl,
  Map<String, String> added,
  Map<String, String> updated,
  Map<String, String> skipped,
  String? id,
  String? name,
  String line,
) {
  final existing = product['imageUrl'] as String?;
  final key = product['id'] as String? ?? id ?? name ?? line;
  if (existing == imageUrl) {
    skipped[key] = 'identical already set';
    return;
  }
  if (existing == null) {
    product['imageUrl'] = imageUrl;
    added[key] = imageUrl;
  } else {
    product['imageUrl'] = imageUrl;
    updated[key] = imageUrl;
  }
}
