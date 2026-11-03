/// Exports aggregated experiment & normalization metrics from a telemetry JSON file.
///
/// Usage:
///   dart run tool/export_experiment_metrics.dart --file=telemetry_export.json > metrics.json
///
/// Output JSON structure:
/// {
///   "summary": { ... overall metrics ... },
///   "variants": { "A": {..}, "B": {..}, "X": {..}, ... },
///   "normalization": {
///       "distinctZeroRaw": 12,
///       "distinctZeroNormalized": 9,
///       "reduction": 0.25
///   },
///   "timestamp": 1690000000000
/// }
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final fileArg = _argValue(args, '--file') ?? 'telemetry_export.json';
  final file = File(fileArg);
  if (!file.existsSync()) {
    stderr.writeln('Telemetry JSON not found: $fileArg');
    exit(1);
  }
  dynamic decoded;
  try {
    decoded = json.decode(await file.readAsString());
  } catch (e) {
    stderr.writeln('Invalid JSON: $e');
    exit(1);
  }
  if (decoded is! List) {
    stderr.writeln('Expected JSON array of events');
    exit(1);
  }
  final events = <Map<String, dynamic>>[];
  for (final e in decoded) {
    if (e is Map) {
      events.add(e.cast<String, dynamic>());
    }
  }
  Map<String, dynamic> overall = _aggregate(events);
  final variants = <String, Map<String, dynamic>>{};
  // Variants may span different experiments; group by 'var' field.
  final byVar = <String, List<Map<String, dynamic>>>{};
  for (final e in events) {
    final v = e['var'];
    if (v is String && v.isNotEmpty) {
      byVar.putIfAbsent(v, () => []).add(e);
    }
  }
  byVar.forEach((k, v) => variants[k] = _aggregate(v));

  // Normalization impact: measure distinct zero-result queries raw vs normalized (nq).
  final rawZero = <String>{};
  final normZero = <String>{};
  for (final e in events) {
    if (e['type'] == 'search' && (e['results'] is int) && e['results'] == 0) {
      final q = (e['q'] ?? '').toString().trim().toLowerCase();
      if (q.isNotEmpty) rawZero.add(q);
      final nq = (e['nq'] ?? '').toString().trim().toLowerCase();
      if (nq.isNotEmpty) normZero.add(nq);
    }
  }
  final distinctZeroRaw = rawZero.length;
  final distinctZeroNorm = normZero.isEmpty ? distinctZeroRaw : normZero.length;
  final reduction = distinctZeroRaw == 0
      ? 0.0
      : (distinctZeroRaw - distinctZeroNorm) / distinctZeroRaw;

  final out = {
    'summary': overall,
    'variants': variants,
    'normalization': {
      'distinctZeroRaw': distinctZeroRaw,
      'distinctZeroNormalized': distinctZeroNorm,
      'reduction': double.parse(reduction.toStringAsFixed(4)),
    },
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}

Map<String, dynamic> _aggregate(List<Map<String, dynamic>> events) {
  int searches = 0;
  int clicks = 0;
  int zeroResults = 0;
  int totalResults = 0;
  int latencySum = 0;
  int clickRankSum = 0;
  int clicksTop1 = 0;
  int clicksTop3 = 0;
  final queryClick = <String, bool>{};
  int autoFuzzy = 0;
  for (final e in events) {
    final type = e['type'];
    if (type == 'search') {
      searches++;
      final results = (e['results'] as int?) ?? 0;
      totalResults += results;
      if (results == 0) zeroResults++;
      latencySum += (e['ms'] as int?) ?? 0;
      final key = '${e['q']}::${e['store']}';
      queryClick.putIfAbsent(key, () => false);
      if (e['af'] == 1) autoFuzzy++;
    } else if (type == 'click') {
      clicks++;
      final key = '${e['q']}::${e['store']}';
      queryClick[key] = true;
      final rank = (e['rank'] as int?) ?? 0;
      if (rank > 0) {
        clickRankSum += rank;
        if (rank == 1) clicksTop1++;
        if (rank <= 3) clicksTop3++;
      }
    }
  }
  final searchesWithClicks = queryClick.values.where((v) => v).length;
  double safeDiv(num a, num b) => b == 0 ? 0 : a / b;
  return {
    'searches': searches,
    'clicks': clicks,
    'zeroResults': zeroResults,
    'zeroResultRate': safeDiv(zeroResults, searches),
    'avgResults': safeDiv(totalResults, searches),
    'avgLatencyMs': safeDiv(latencySum, searches),
    'clicksPerSearch': safeDiv(clicks, searches),
    'searchesWithClicksRate': safeDiv(searchesWithClicks, searches),
    'avgClickRank': safeDiv(clickRankSum, clicks),
    'pctClicksTop1': safeDiv(clicksTop1, clicks),
    'pctClicksTop3': safeDiv(clicksTop3, clicks),
    'autoFuzzySearches': autoFuzzy,
  };
}

String? _argValue(List<String> args, String key) {
  for (final a in args) {
    if (a.startsWith('$key=')) return a.substring(key.length + 1);
  }
  return null;
}
