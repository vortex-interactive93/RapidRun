import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Lightweight telemetry for substitution workflow actions.
class SubstitutionTelemetry {
  SubstitutionTelemetry._();
  static final SubstitutionTelemetry instance = SubstitutionTelemetry._();

  static const _prefsKey = 'substitution_telemetry_events_v1';
  static const int _maxEvents = 400;
  final List<Map<String, dynamic>> _events = [];
  bool _loaded = false;

  UnmodifiableListView<Map<String, dynamic>> get events =>
      UnmodifiableListView(_events);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) _events.add(e);
          }
        }
      }
      if (_events.length > _maxEvents) {
        _events.removeRange(0, _events.length - _maxEvents);
      }
    } catch (_) {}
  }

  void logCreate({required String orderId, required String productId}) {
    _add({
      't': 'c',
      'o': orderId,
      'p': productId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void logDecision({
    required String orderId,
    required String productId,
    required bool approved,
    int latencyMs = 0,
    double? priceDelta,
  }) {
    _add({
      't': approved ? 'a' : 'r',
      'o': orderId,
      'p': productId,
      'l': latencyMs,
      if (priceDelta != null) 'd': priceDelta,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Map<String, dynamic> summary() {
    int created = 0, approved = 0, rejected = 0;
    int totalLatency = 0;
    double approvedDeltaSum = 0;
    int approvedDeltaCount = 0;
    for (final e in _events) {
      switch (e['t']) {
        case 'c':
          created++;
          break;
        case 'a':
          approved++;
          if (e['l'] is int) {
            totalLatency += e['l'] as int;
          }
          if (e['d'] is num) {
            approvedDeltaSum += (e['d'] as num).toDouble();
            approvedDeltaCount++;
          }
          break;
        case 'r':
          rejected++;
          if (e['l'] is int) {
            totalLatency += e['l'] as int;
          }
          break;
      }
    }
    final handled = approved + rejected;
    return {
      'created': created,
      'approved': approved,
      'rejected': rejected,
      'approvalRate': created == 0 ? 0 : approved / created,
      'avgDecisionLatencyMs': handled == 0 ? 0 : totalLatency / handled,
      'avgPriceDeltaApproved': approvedDeltaCount == 0
          ? 0
          : approvedDeltaSum / approvedDeltaCount,
      'totalPriceDeltaApproved': approvedDeltaSum,
    };
  }

  void _add(Map<String, dynamic> evt) {
    _events.add(evt);
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(_events));
    } catch (_) {}
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
  }

  String exportJson() => json.encode(_events);
  Future<String?> exportToFile() async {
    try {
      await ensureLoaded();
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name =
          'sub_telemetry_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(exportJson());
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
