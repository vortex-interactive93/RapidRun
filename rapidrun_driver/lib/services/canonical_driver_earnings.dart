// File: rapidrun_driver/lib/services/canonical_driver_earnings.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Immutable, single-source-of-truth financial snapshot for a RapidRun driver.
/// Guarantees that `availableCashout` always equals `max(0, grossEarnings - totalCashedOut)`
/// so post-cashout tip boosts add only the true incremental delta.
class CanonicalDriverEarnings {
  final double todayEarnings;
  final double thisWeekEarnings;
  final double basePay;
  final double customerTips;
  final double boostedTips;
  final double totalCashedOut;
  final double availableCashout;
  final int completedTrips;

  const CanonicalDriverEarnings({
    required this.todayEarnings,
    required this.thisWeekEarnings,
    required this.basePay,
    required this.customerTips,
    required this.boostedTips,
    required this.totalCashedOut,
    required this.availableCashout,
    required this.completedTrips,
  });

  static const empty = CanonicalDriverEarnings(
    todayEarnings: 0.0,
    thisWeekEarnings: 0.0,
    basePay: 0.0,
    customerTips: 0.0,
    boostedTips: 0.0,
    totalCashedOut: 0.0,
    availableCashout: 0.0,
    completedTrips: 0,
  );

  static double _round2(double value) =>
      double.parse(value.toStringAsFixed(2));

  /// Computes consistent figures from Firestore driver + ledger documents.
  factory CanonicalDriverEarnings.fromFirestore({
    required Map<String, dynamic> driverData,
    required List<Map<String, dynamic>> ledgerEntries,
  }) {
    final trips = (driverData['totalDeliveriesCompleted'] as num?)?.toInt() ?? 0;

    double ledgerCredits = 0.0;
    double ledgerCashouts = 0.0;
    double ledgerBoosts = 0.0;

    for (final entry in ledgerEntries) {
      final type = (entry['type'] ?? '').toString();
      final amount = ((entry['amount'] as num?) ?? 0.0).toDouble();
      if (type == 'cashout') {
        ledgerCashouts += amount.abs();
      } else if (type == 'tip_boost') {
        final delta = ((entry['lastDelta'] as num?) ?? amount).toDouble();
        ledgerBoosts += delta;
        ledgerCredits += delta;
      } else {
        // 'batch_completed'
        ledgerCredits += amount;
      }
    }

    final docToday = ((driverData['todayEarnings'] as num?) ?? 0.0).toDouble();
    final docBoosts = ((driverData['boostedTips'] as num?) ?? 0.0).toDouble();
    final docCashedOut =
        ((driverData['totalCashedOut'] as num?) ?? 0.0).toDouble();

    // Prefer non-zero ledger totals when present; otherwise use driver doc totals
    final grossToday = _round2(ledgerCredits > 0 ? ledgerCredits : docToday);
    final boosts = _round2(math.max(ledgerBoosts, docBoosts));
    final cashedOut = _round2(math.max(ledgerCashouts, docCashedOut));
    final withdrawable =
        _round2(math.max(0.0, grossToday - cashedOut));

    final rawWeek = ((driverData['thisWeekEarnings'] as num?) ?? grossToday)
        .toDouble();
    // Prevent stale `thisWeekEarnings` from lagging behind `todayEarnings`
    final weekTotal = _round2(math.max(rawWeek, grossToday));

    final docTips = ((driverData['customerTips'] as num?) ?? 0.0).toDouble();
    final docBase = ((driverData['basePay'] as num?) ?? 0.0).toDouble();
    final inferredBase = docBase > 0
        ? docBase
        : math.max(0.0, grossToday - docTips - boosts);

    return CanonicalDriverEarnings(
      todayEarnings: grossToday,
      thisWeekEarnings: weekTotal,
      basePay: _round2(inferredBase),
      customerTips: _round2(docTips),
      boostedTips: boosts,
      totalCashedOut: cashedOut,
      availableCashout: withdrawable,
      completedTrips: trips,
    );
  }
}

/// Streams and mutates driver earnings atomically so `todayEarnings`,
/// `thisWeekEarnings`, `boostedTips`, and `availableCashout` never diverge.
class CanonicalEarningsService {
  final FirebaseFirestore _firestore;

  CanonicalEarningsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _driverDoc(String driverId) =>
      _firestore.collection('drivers').doc(driverId);

  CollectionReference<Map<String, dynamic>> _ledgerCol(String driverId) =>
      _driverDoc(driverId).collection('ledger_entries');

  Stream<CanonicalDriverEarnings> watchEarnings(String driverId) {
    final driverStream = _driverDoc(driverId).snapshots().map(
          (snap) => snap.data() ?? <String, dynamic>{},
        );

    final ledgerStream = _ledgerCol(driverId).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );

    late StreamController<CanonicalDriverEarnings> controller;
    Map<String, dynamic> latestDriver = {};
    List<Map<String, dynamic>> latestLedger = [];
    bool gotDriver = false;
    bool gotLedger = false;

    void emitIfReady() {
      if (!controller.isClosed && (gotDriver || gotLedger)) {
        controller.add(
          CanonicalDriverEarnings.fromFirestore(
            driverData: latestDriver,
            ledgerEntries: latestLedger,
          ),
        );
      }
    }

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    controller = StreamController<CanonicalDriverEarnings>(
      onListen: () {
        sub1 = driverStream.listen(
          (data) {
            latestDriver = data;
            gotDriver = true;
            emitIfReady();
          },
          onError: (e) => debugPrint('Driver earnings stream notice: $e'),
        );
        sub2 = ledgerStream.listen(
          (entries) {
            latestLedger = entries;
            gotLedger = true;
            emitIfReady();
          },
          onError: (e) => debugPrint('Ledger entries stream notice: $e'),
        );
      },
      onCancel: () async {
        await sub1?.cancel();
        await sub2?.cancel();
        await controller.close();
      },
    );

    return controller.stream;
  }

  /// Records a completed batch once (idempotent by `batch_$orderId`).
  Future<void> recordCompletedBatch({
    required String driverId,
    required String orderId,
    required double totalPayout,
    required double tipAmount,
  }) async {
    final roundedTotal = CanonicalDriverEarnings._round2(totalPayout);
    final roundedTip = CanonicalDriverEarnings._round2(tipAmount);
    final roundedBase =
        CanonicalDriverEarnings._round2(math.max(0.0, roundedTotal - roundedTip));

    final ledgerRef = _ledgerCol(driverId).doc('batch_$orderId');
    final driverRef = _driverDoc(driverId);

    await _firestore.runTransaction((tx) async {
      final existingLedger = await tx.get(ledgerRef);
      if (existingLedger.exists) return;

      final driverSnap = await tx.get(driverRef);
      final currentData = driverSnap.data() ?? {};
      final curToday =
          ((currentData['todayEarnings'] as num?) ?? 0.0).toDouble();
      final curWeek =
          ((currentData['thisWeekEarnings'] as num?) ?? 0.0).toDouble();
      final curCashedOut =
          ((currentData['totalCashedOut'] as num?) ?? 0.0).toDouble();

      final nextToday = CanonicalDriverEarnings._round2(curToday + roundedTotal);
      final nextWeek =
          CanonicalDriverEarnings._round2(math.max(curWeek, nextToday));
      final nextAvailable =
          CanonicalDriverEarnings._round2(math.max(0.0, nextToday - curCashedOut));

      tx.set(ledgerRef, {
        'type': 'batch_completed',
        'orderId': orderId,
        'amount': roundedTotal,
        'basePay': roundedBase,
        'tip': roundedTip,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        driverRef,
        {
          'todayEarnings': nextToday,
          'thisWeekEarnings': nextWeek,
          'basePay': FieldValue.increment(roundedBase),
          'customerTips': FieldValue.increment(roundedTip),
          'balance': nextAvailable,
          'availableCashout': nextAvailable,
          'totalDeliveriesCompleted': FieldValue.increment(1),
          'currentOrderId': FieldValue.delete(),
          'currentOrderStatus': FieldValue.delete(),
          'activeOrderId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Applies only the incremental tip boost delta so post-cashout boosts
  /// increment `boostedTips`, `todayEarnings`, `thisWeekEarnings`, and
  /// `availableCashout` cleanly without restoring pre-cashout totals.
  Future<void> applyIncrementalTipBoost({
    required String driverId,
    required String orderId,
    required double incrementalBoost,
  }) async {
    if (incrementalBoost <= 0) return;
    final delta = CanonicalDriverEarnings._round2(incrementalBoost);

    final ledgerRef = _ledgerCol(driverId).doc('tipboost_${orderId}_${DateTime.now().millisecondsSinceEpoch}');
    final driverRef = _driverDoc(driverId);

    await _firestore.runTransaction((tx) async {
      final driverSnap = await tx.get(driverRef);
      final currentData = driverSnap.data() ?? {};
      final curToday =
          ((currentData['todayEarnings'] as num?) ?? 0.0).toDouble();
      final curWeek =
          ((currentData['thisWeekEarnings'] as num?) ?? 0.0).toDouble();
      final curCashedOut =
          ((currentData['totalCashedOut'] as num?) ?? 0.0).toDouble();

      final nextToday = CanonicalDriverEarnings._round2(curToday + delta);
      final nextWeek =
          CanonicalDriverEarnings._round2(math.max(curWeek, nextToday));
      final nextAvailable =
          CanonicalDriverEarnings._round2(math.max(0.0, nextToday - curCashedOut));

      tx.set(ledgerRef, {
        'type': 'tip_boost',
        'orderId': orderId,
        'amount': delta,
        'lastDelta': delta,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        driverRef,
        {
          'todayEarnings': nextToday,
          'thisWeekEarnings': nextWeek,
          'boostedTips': FieldValue.increment(delta),
          'customerTips': FieldValue.increment(delta),
          'balance': nextAvailable,
          'availableCashout': nextAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Cashes out the exact withdrawable balance (`availableCashout`) and sets
  /// `availableCashout` + `balance` to `0.0` while preserving `todayEarnings`.
  Future<double> executeCashout({
    required String driverId,
    String cardLast4 = '4242',
  }) async {
    final driverRef = _driverDoc(driverId);
    final ledgerRef = _ledgerCol(driverId).doc();
    double cashedOutAmount = 0.0;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(driverRef);
      final data = snap.data() ?? {};
      final today = ((data['todayEarnings'] as num?) ?? 0.0).toDouble();
      final prevCashedOut =
          ((data['totalCashedOut'] as num?) ?? 0.0).toDouble();
      final available =
          CanonicalDriverEarnings._round2(math.max(0.0, today - prevCashedOut));

      if (available <= 0) return;
      cashedOutAmount = available;

      final nextTotalCashedOut =
          CanonicalDriverEarnings._round2(prevCashedOut + available);

      tx.set(ledgerRef, {
        'type': 'cashout',
        'amount': available,
        'cardLast4': cardLast4,
        'status': 'settled_instant',
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        driverRef,
        {
          'totalCashedOut': nextTotalCashedOut,
          'balance': 0.0,
          'availableCashout': 0.0,
          'lastCashoutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return cashedOutAmount;
  }
}
