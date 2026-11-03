#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

// Repairs walmart prepared meals & sides part files by adding missing ids and
// normalizing price fields to numeric values.
// Assigns sequential ids across part1 then part2 without gaps.
// Usage: dart tool/repair_prepared_meals_ids.dart
void main() {
  const baseName = 'walmart-prepared-meals-and-sides';
  final part1 = File('assets/stores/walmart/${baseName}-part1.json');
  final part2 = File('assets/stores/walmart/${baseName}-part2.json');
  if (!part1.existsSync() || !part2.existsSync()) {
    stderr.writeln('Expected part files not found.');
    exit(1);
  }
  List<dynamic> list1;
  List<dynamic> list2;
  try {
    list1 = json.decode(part1.readAsStringSync()) as List<dynamic>;
    list2 = json.decode(part2.readAsStringSync()) as List<dynamic>;
  } catch (e) {
    stderr.writeln('Failed to parse part files: $e');
    exit(1);
  }
  final total = list1.length + list2.length;
  if (total == 0) {
    stderr.writeln('No entries found.');
    return;
  }
  int pad = total >= 1000 ? 4 : 3; // zero padding
  final fmt = (int n) => n.toString().padLeft(pad, '0');

  int counter = 1;
  void repairList(List<dynamic> list) {
    for (int i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! Map<String, dynamic>) continue;
      final m = Map<String, dynamic>.from(raw);
      m['storeId'] = 'walmart';
      m['category'] = 'Deli';
      m['subCategory'] = 'Prepared meals & sides';
      m['id'] = 'walmart_prepared_meals_and_sides_${fmt(counter)}';
      counter++;
      // Normalize price
      final priceVal = m['price'];
      if (priceVal is String) {
        final r = RegExp(r'\$([0-9]+(?:\.[0-9]{1,2})?)');
        final match = r.firstMatch(priceVal);
        if (match != null) {
          m['price'] = double.parse(match.group(1)!);
        } else {
          m.remove('price');
        }
      } else if (priceVal != null && priceVal is! num) {
        m.remove('price');
      }
      list[i] = m;
    }
  }

  repairList(list1);
  repairList(list2);

  // Write back with pretty formatting.
  const encoder = JsonEncoder.withIndent('  ');
  part1.writeAsStringSync(encoder.convert(list1) + '\n');
  part2.writeAsStringSync(encoder.convert(list2) + '\n');

  print('Repaired ${list1.length} + ${list2.length} entries (total $total).');
  print(
    'Example id range: ${list1.isNotEmpty ? (list1.first as Map)['id'] : 'n/a'} .. ${list2.isNotEmpty ? (list2.last as Map)['id'] : (list1.last as Map)['id']}',
  );
}
