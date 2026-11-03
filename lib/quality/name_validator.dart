import 'dart:convert';

/// Heuristic evaluation of product names to detect over-shortening or low quality.
/// Each returned code is a short machine-friendly string; callers can map to messages.
List<String> evaluateProductName(Map<String, dynamic> product) {
  final codes = <String>[];
  final name = (product['name'] ?? '').toString().trim();
  final original = (product['originalName'] ?? '').toString().trim();
  if (name.isEmpty) {
    codes.add('empty');
    return codes;
  }
  // Length based
  if (name.length < 4) codes.add('too_short_chars');
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= 1) codes.add('single_word');

  // Token classification
  const packaging = {
    'oz',
    'fl',
    'fl.',
    'fl_oz',
    'floz',
    'lb',
    'pound',
    'pounds',
    'ct',
    'count',
    'ea',
    'each',
    'bag',
    'bottle',
    'can',
    'pk',
    'pack',
    'tray',
    'pt',
    'gal',
    'g',
    'ml',
    'l',
  };
  int nonPackaging = 0;
  int packagingTokens = 0;
  for (final w in words) {
    final lc = w.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (lc.isEmpty) continue;
    if (packaging.contains(lc) || RegExp(r'^\d+[a-z]*').hasMatch(lc)) {
      packagingTokens++;
    } else {
      nonPackaging++;
    }
  }
  if (nonPackaging == 0) codes.add('only_packaging');
  if (nonPackaging <= 1 && packagingTokens >= 1) codes.add('mostly_packaging');

  // Over-truncation relative to originalName
  if (original.isNotEmpty && original.length >= name.length * 1.5) {
    codes.add('truncated_vs_original');
  }

  return codes;
}

/// Summarize a list of products producing counts per code and affected IDs.
Map<String, dynamic> summarizeProducts(
  Iterable<Map<String, dynamic>> products,
) {
  final summary = <String, dynamic>{'total': 0, 'issues': <String, int>{}};
  final issues = summary['issues'] as Map<String, int>;
  final examples =
      <String, List<String>>{}; // code -> list of product names (up to 5)
  for (final p in products) {
    summary['total'] = (summary['total'] as int) + 1;
    final codes = evaluateProductName(p);
    for (final c in codes) {
      issues[c] = (issues[c] ?? 0) + 1;
      final list = (examples[c] ??= []);
      if (list.length < 5) list.add(p['name']?.toString() ?? '');
    }
  }
  summary['examples'] = examples;
  return summary;
}

String formatSummaryAsJson(Map<String, dynamic> summary) =>
    const JsonEncoder.withIndent('  ').convert(summary);
