// File: rapidrun_driver/lib/services/unified_driver_wallet_controller.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Single source of truth for driver balances across Top HUD, Drawer,
/// EarningsDashboardScreen, DriverCashoutSheet, and TripHistoryScreen.
class UnifiedDriverWalletController extends ChangeNotifier {
  UnifiedDriverWalletController._();
  static final UnifiedDriverWalletController instance =
      UnifiedDriverWalletController._();

  final Map<String, double> _orderBasePay = {};
  final Map<String, double> _orderInitialTip = {};
  final Map<String, double> _orderTipBoost = {};
  final Set<String> _processedBoostEvents = {};

  double _totalCashedOut = 0.0;
  int _completedTripCount = 0;

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  double get basePay =>
      _r2(_orderBasePay.values.fold(0.0, (a, b) => a + b));

  double get customerTips =>
      _r2(_orderInitialTip.values.fold(0.0, (a, b) => a + b));

  double get boostedTips =>
      _r2(_orderTipBoost.values.fold(0.0, (a, b) => a + b));

  /// Gross earned across completed orders (never drops on cash-out).
  double get grossEarnings => _r2(basePay + customerTips + boostedTips);

  double get todayEarnings => grossEarnings;
  double get thisWeekEarnings => grossEarnings;
  double get totalCashedOut => _r2(_totalCashedOut);
  int get completedTrips => _completedTripCount;

  /// Net withdrawable balance after cash-outs.
  double get availableCashout =>
      _r2(math.max(0.0, grossEarnings - _totalCashedOut));

  /// Records a completed order once by `orderId` (idempotent).
  void recordOrderCompleted({
    required String orderId,
    required double totalPayout,
    required double tipAmount,
  }) {
    final cleanTotal = _r2(math.max(0.0, totalPayout));
    final cleanTip = _r2(tipAmount.clamp(0.0, cleanTotal));
    final cleanBase = _r2(math.max(0.0, cleanTotal - cleanTip));

    final alreadyRecorded = _orderBasePay.containsKey(orderId);
    _orderBasePay[orderId] = cleanBase;
    _orderInitialTip[orderId] = cleanTip;
    _orderTipBoost.putIfAbsent(orderId, () => 0.0);

    if (!alreadyRecorded) {
      _completedTripCount += 1;
    }
    notifyListeners();
  }

  /// Adds a post-delivery tip boost once per unique `boostEventId` (or token).
  void recordTipBoost({
    required String boostEventId,
    required String orderId,
    required double incrementalBoost,
  }) {
    final cleanBoost = _r2(incrementalBoost);
    if (cleanBoost <= 0) return;
    if (_processedBoostEvents.contains(boostEventId)) return;

    _processedBoostEvents.add(boostEventId);
    _orderBasePay.putIfAbsent(orderId, () => 0.0);
    _orderInitialTip.putIfAbsent(orderId, () => 0.0);
    _orderTipBoost[orderId] =
        _r2((_orderTipBoost[orderId] ?? 0.0) + cleanBoost);

    notifyListeners();
  }

  /// Cashes out the exact `availableCashout` and zeroes withdrawable funds.
  double executeCashout() {
    final amount = availableCashout;
    if (amount <= 0) return 0.0;
    _totalCashedOut = _r2(_totalCashedOut + amount);
    notifyListeners();
    return amount;
  }

  /// Resets all local test balances cleanly when starting a fresh driver test.
  void resetAll() {
    _orderBasePay.clear();
    _orderInitialTip.clear();
    _orderTipBoost.clear();
    _processedBoostEvents.clear();
    _totalCashedOut = 0.0;
    _completedTripCount = 0;
    notifyListeners();
  }
}
