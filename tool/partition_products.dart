#!/usr/bin/env dart

/// Tool: partition_products.dart
/// Splits large product JSON asset files into part files based on size / item thresholds.
/// Safe: does not overwrite existing part files unless --force specified.
/// Usage (from repo root):
///   dart tool/partition_products.dart [--dry-run] [--force] [--max-items 150] [--max-bytes 150000]
///
import 'dart:convert';
import 'dart:io';

class PartitionPlan {
  final File source;
  final List<List<Map<String, dynamic>>> parts;
  PartitionPlan(this.source, this.parts);
}

void main(List<String> args) async {
  final argSet = args.toSet();
  final dryRun = argSet.contains('--dry-run');
  final force = argSet.contains('--force');

  int maxItems = _readIntArg(args, '--max-items') ?? 150;
  int maxBytes = _readIntArg(args, '--max-bytes') ?? 150000;

  final configFile = File('assets/config/product_asset_rules.json');
  if (configFile.existsSync()) {
    try {
      final cfg =
          json.decode(await configFile.readAsString()) as Map<String, dynamic>;
      maxItems = (cfg['partitionThresholdItems'] as num?)?.toInt() ?? maxItems;
      maxBytes = (cfg['partitionThresholdBytes'] as num?)?.toInt() ?? maxBytes;
    } catch (_) {}
  }

  final candidates = _collectCandidates(maxItems, maxBytes);
  if (candidates.isEmpty) {
    print('No files exceed thresholds (items>$maxItems or bytes>$maxBytes).');
    return;
  }
  print('Evaluating ${candidates.length} oversize file(s)...');

  for (final file in candidates) {
    try {
      final raw = await file.readAsString();
      final decoded = json.decode(raw);
      if (decoded is! List) continue;
      final items = decoded.cast<Map<String, dynamic>>();
      final parts = _partition(items, maxItems);
      if (parts.length <= 1) continue; // nothing to do
      final baseName = file.uri.pathSegments.last.replaceAll('.json', '');
      final dir = file.parent;
      // Build part file list
      final existingParts = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('$baseName-part'))
          .toList();
      if (existingParts.isNotEmpty && !force) {
        print(
          'SKIP: $baseName has existing part files (use --force to overwrite).',
        );
        continue;
      }

      // Planned partition details (previously captured in a variable). No need to instantiate PartitionPlan object.
      if (dryRun) {
        print(
          'DRY-RUN plan for $baseName: split into ${parts.length} parts -> counts: ${parts.map((p) => p.length).join(', ')}',
        );
      } else {
        // Write parts
        for (var i = 0; i < parts.length; i++) {
          final partFile = File('${dir.path}/$baseName-part${i + 1}.json');
          final formatted = const JsonEncoder.withIndent(
            '  ',
          ).convert(parts[i]);
          await partFile.writeAsString(formatted + '\n');
          print('Wrote ${partFile.path} (${parts[i].length} items)');
        }
        // Backup original then remove
        final backup = File(file.path + '.bak');
        await file.copy(backup.path);
        await file.delete();
        print('Original moved to ${backup.path} (retain for diff).');
      }
    } catch (e) {
      stderr.writeln('ERROR processing ${file.path}: $e');
    }
  }
}

List<File> _collectCandidates(int maxItems, int maxBytes) {
  final storeDir = Directory('assets/stores');
  if (!storeDir.existsSync()) return [];
  return storeDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where((f) {
        try {
          final len = f.lengthSync();
          final content = f.readAsStringSync();
          late final int items;
          try {
            final decoded = json.decode(content);
            items = decoded is List ? decoded.length : 0;
          } catch (_) {
            items = 0;
          }
          return items > maxItems || len > maxBytes;
        } catch (_) {
          return false;
        }
      })
      .toList();
}

List<List<Map<String, dynamic>>> _partition(
  List<Map<String, dynamic>> items,
  int maxItems,
) {
  final parts = <List<Map<String, dynamic>>>[];
  for (var i = 0; i < items.length; i += maxItems) {
    parts.add(
      items.sublist(
        i,
        i + maxItems > items.length ? items.length : i + maxItems,
      ),
    );
  }
  return parts;
}

int? _readIntArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return int.tryParse(args[idx + 1]);
}
