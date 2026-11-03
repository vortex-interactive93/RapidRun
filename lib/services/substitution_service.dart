import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/substitution_request.dart';
import 'orders_service.dart';
import 'substitution_telemetry.dart';

/// Local-only substitution request manager.
class SubstitutionService extends ChangeNotifier {
  SubstitutionService._();
  static final SubstitutionService instance = SubstitutionService._();

  static const _prefsKey = 'rapidrun_substitutions_v1';
  final List<SubstitutionRequest> _requests = [];
  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '';
      _requests
        ..clear()
        ..addAll(SubstitutionRequest.decodeList(raw));
    } catch (_) {}
    _bootstrapped = true;
    notifyListeners();
  }

  List<SubstitutionRequest> byOrder(String orderId) =>
      _requests.where((r) => r.orderId == orderId).toList();

  List<SubstitutionRequest> get all => List.unmodifiable(_requests);

  Future<SubstitutionRequest> create({
    required String orderId,
    required String productId,
    required String originalName,
    required String proposedName,
    String? proposedProductId,
    double? proposedPrice,
  }) async {
    await bootstrap();
    final req = SubstitutionRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      orderId: orderId,
      productId: productId,
      originalName: originalName,
      proposedName: proposedName,
      proposedProductId: proposedProductId,
      proposedPrice: proposedPrice,
      createdAt: DateTime.now(),
    );
    _requests.add(req);
    await _persist();
    notifyListeners();
    SubstitutionTelemetry.instance.logCreate(
      orderId: orderId,
      productId: productId,
    );
    return req;
  }

  Future<void> decide(
    String id,
    SubstitutionRequestStatus status, {
    String? note,
  }) async {
    final idx = _requests.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _requests[idx] = _requests[idx].copyWith(
      status: status,
      decidedAt: DateTime.now(),
      decisionNote: note,
    );
    await _persist();
    notifyListeners();
    final r = _requests[idx];
    final latencyMs = r.decidedAt != null
        ? r.decidedAt!.difference(r.createdAt).inMilliseconds
        : 0;
    SubstitutionTelemetry.instance.logDecision(
      orderId: r.orderId,
      productId: r.productId,
      approved: status == SubstitutionRequestStatus.approved,
      latencyMs: latencyMs,
      priceDelta: () {
        if (status != SubstitutionRequestStatus.approved) return null;
        if (r.proposedPrice == null) return null;
        // Need original line price: fetch order & item.
        final order = OrdersService.instance.getById(r.orderId);
        final line = order?.items.firstWhere(
          (li) => li.productId == r.productId,
          orElse: () => null as dynamic,
        );
        if (line == null) return null;
        final originalLineTotal = (line.unitPrice) * line.quantity;
        final proposedLineTotal = (r.proposedPrice!) * line.quantity;
        return double.parse(
          (proposedLineTotal - originalLineTotal).toStringAsFixed(2),
        );
      }(),
    );
    if (status == SubstitutionRequestStatus.approved) {
      final r = _requests[idx];
      // For now only update name; future: price adjustments, alt product ID.
      await OrdersService.instance.applySubstitution(
        orderId: r.orderId,
        originalProductId: r.productId,
        newName: r.proposedName,
        newUnitPrice: r.proposedPrice,
      );
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        SubstitutionRequest.encodeList(_requests),
      );
    } catch (_) {}
  }
}
