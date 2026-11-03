// Script: generate_store_product_ids.dart
// Ensures every product JSON entry for a given store has a stable unique id.
//
// Usage examples:
//   dart run tool/generate_store_product_ids.dart                # default store=walmart (modify files)
//   dart run tool/generate_store_product_ids.dart --store=aldi --dry-run
//   dart run tool/generate_store_product_ids.dart --store=walmart --force --no-backups
//
// Flags:
//   --store=<name>       Target store directory under assets/stores/ (default: walmart)
//   --dry-run            Analyze only; do not modify files.
//   --force              Regenerate IDs even if an id already exists (NOT recommended unless restructuring).
//   --no-backups         Do not create .bak backups before overwriting.
//   --prefix=<prefix>    Override id prefix (default: <store>_auto_ ).
//
// Behavior:
//   * Scans assets/stores/<store>/*.json (excluding *_categories, .bak, and non-list JSON).
//   * For each list element map having a non-empty name, ensures 'id' field.
//   * Deterministic id is built from prefix + slug(name)[0..40] + '_' + 36radix(hash(name)).
//   * Ensures global uniqueness across all processed files; if collision, appends incrementing suffix.
//   * Leaves entries with empty name unchanged.
//   * Outputs a summary and duplicate name warnings (normalized name duplicates) to help catalog hygiene.
//
// Exit codes:
//   0 success, 1 fatal error.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String store = 'walmart';
  bool dryRun = false;
  bool force = false;
  bool noBackups = false;
  String? prefixOverride;

  for (final a in args) {
    if (a.startsWith('--store='))
      store = a.split('=').last.trim();
    else if (a == '--dry-run')
      dryRun = true;
    else if (a == '--force')
      force = true;
    else if (a == '--no-backups')
      noBackups = true;
    else if (a.startsWith('--prefix='))
      prefixOverride = a.split('=').last.trim();
  }

  final dir = Directory('assets/stores/$store');
  if (!dir.existsSync()) {
    stderr.writeln('Store directory not found: ${dir.path}');
    exit(1);
  }

  final files = dir.listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.json')) return false;
    if (name.contains('_categories')) return false;
    if (name.endsWith('.json.bak')) return false;
    return true;
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stdout.writeln('No JSON product files found for store=$store');
    return;
  }

  final String idPrefix = prefixOverride ?? '${store.toLowerCase()}_auto_';
  final Set<String> usedIds = {};
  int productsTotal = 0;
  int addedIds = 0;
  int regenerated = 0;
  int nameless = 0;

  final Map<String, List<String>> nameOccurrences =
      {}; // normalized name -> list of file@idx references

  String slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final collapsed = cleaned.replaceAll(RegExp(r'-{2,}'), '-');
    final noLead = collapsed.replaceAll(RegExp(r'^-+'), '');
    final normalized = noLead.replaceAll(RegExp(r'-{2,}'), '-');
    return normalized.length > 40 ? normalized.substring(0, 40) : normalized;
  }

  String makeId(String name, {int attempt = 0}) {
    final base = slug(name);
    final hash = name.hashCode & 0x7fffffff;
    final core = idPrefix + base + '_' + hash.toRadixString(36);
    if (attempt == 0) return core;
    return core + '_$attempt';
  }

  for (final file in files) {
    final fileName = file.uri.pathSegments.last;
    List<dynamic> data;
    try {
      data = json.decode(file.readAsStringSync()) as List<dynamic>;
    } catch (e) {
      stderr.writeln('Skipping invalid JSON ${file.path}: $e');
      continue;
    }

    bool changed = false;
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is! Map) continue;
      productsTotal++;
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        nameless++;
        continue;
      }
      final norm = name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      nameOccurrences.putIfAbsent(norm, () => []).add('$fileName@$i');

      var id = (item['id'] ?? '').toString().trim();
      if (id.isEmpty || force) {
        int attempt = 0;
        String candidate;
        do {
          candidate = makeId(name, attempt: attempt);
          attempt++;
        } while (usedIds.contains(candidate));
        if (id.isEmpty)
          addedIds++;
        else
          regenerated++;
        id = candidate;
        item['id'] = id;
        changed = true;
      }
      if (usedIds.contains(id)) {
        // Collision with existing id from a different item; regenerate.
        int attempt = 1;
        String candidate;
        do {
          candidate = makeId(name, attempt: attempt);
          attempt++;
        } while (usedIds.contains(candidate));
        item['id'] = candidate;
        id = candidate;
        changed = true;
      }
      usedIds.add(id);
    }

    if (changed && !dryRun) {
      if (!noBackups) {
        try {
          file.copySync(file.path + '.bak');
        } catch (_) {}
      }
      final encoder = const JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(data));
      stdout.writeln('Updated $fileName');
    } else if (changed) {
      stdout.writeln('(dry-run) Would update $fileName');
    }
  }

  // Report duplicate normalized names (informational only)
  final duplicates =
      nameOccurrences.entries.where((e) => e.value.length > 1).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

  stdout.writeln('\nSummary for store=$store');
  stdout.writeln('  Files processed : ${files.length}');
  stdout.writeln('  Products scanned: $productsTotal');
  stdout.writeln('  IDs added       : $addedIds');
  stdout.writeln('  IDs regenerated : $regenerated');
  stdout.writeln('  Nameless items  : $nameless');
  stdout.writeln('  Unique IDs total: ${usedIds.length}');
  stdout.writeln('  Duplicate names : ${duplicates.length}');

  if (duplicates.isNotEmpty) {
    stdout.writeln('\nTop duplicate name samples:');
    for (final entry in duplicates.take(25)) {
      stdout.writeln(
        '  "${entry.key}" -> ${entry.value.length} occurrences (${entry.value.join(', ')})',
      );
    }
  }

  if (dryRun) {
    stdout.writeln('\nDry-run complete; no files modified.');
  } else {
    stdout.writeln('\nDone.');
  }
}
