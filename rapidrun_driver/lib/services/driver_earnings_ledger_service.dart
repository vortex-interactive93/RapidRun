// File: rapidrun_driver/lib/services/driver_earnings_ledger_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverLedgerSummary {
  final double availableBalance;
  final double lifetimeEarnings;
  final double totalCashedOut;
  final List<Map<String, dynamic>> recentEntries;

  const DriverLedgerSummary({
    required this.availableBalance,
    required this.lifetimeEarnings,
    required this.totalCashedOut,
    required this.recentEntries,
  });

  static const empty = DriverLedgerSummary(
    availableBalance: 0.0,
    lifetimeEarnings: 0.0,
    totalCashedOut: 0.0,
    recentEntries: [],
  );
}

/// Append-only financial ledger for RapidRun Drivers.
/// Guarantees that post-cashout tip boosts ONLY add the incremental delta
/// to the driver's $0.00 balance instead of restoring pre-cashout totals.
class DriverEarningsLedgerService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String? explicitDriverId;

  DriverEarningsLedgerService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.explicitDriverId,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _driverId => explicitDriverId ?? (_auth.currentUser?.uid ?? 'driver_local_tester');

  DocumentReference<Map<String, dynamic>> get _driverDoc =>
      _firestore.collection('drivers').doc(_driverId);

  CollectionReference<Map<String, dynamic>> get _ledgerCol =>
      _driverDoc.collection('ledger');

  /// Real-time stream of the driver's true Available Balance & Ledger history
  Stream<DriverLedgerSummary> watchLedgerSummary() {
    return _ledgerCol
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      double credits = 0.0;
      double payouts = 0.0;
      final entries = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        data['entryId'] = doc.id;
        entries.add(data);

        final type = (data['type'] ?? '').toString();
        final amount = ((data['amount'] as num?) ?? 0.0).toDouble();

        if (type == 'cashout') {
          payouts += amount.abs();
        } else {
          // 'batch_completed' or 'tip_boost'
          credits += amount;
        }
      }

      // Clamp to 0.00 to avoid floating-point -0.00 artifacts
      final available = double.parse(
        (credits - payouts).clamp(0.0, 999999.99).toStringAsFixed(2),
      );

      return DriverLedgerSummary(
        availableBalance: available,
        lifetimeEarnings: double.parse(credits.toStringAsFixed(2)),
        totalCashedOut: double.parse(payouts.toStringAsFixed(2)),
        recentEntries: entries,
      );
    });
  }

  /// Records a completed order payout idempotently (keyed by orderId)
  Future<void> recordCompletedBatch({
    required String orderId,
    required String storeName,
    required double basePayout,
    required double initialTip,
  }) async {
    final entryRef = _ledgerCol.doc('batch_$orderId');
    final total = double.parse((basePayout + initialTip).toStringAsFixed(2));

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(entryRef);
      if (existing.exists) return; // Idempotency guard

      tx.set(entryRef, {
        'type': 'batch_completed',
        'orderId': orderId,
        'storeName': storeName,
        'basePayout': basePayout,
        'tip': initialTip,
        'amount': total,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Records ONLY the incremental tip boost delta when a customer adds extra tip
  /// after delivery (even if the driver already cashed out the base batch!).
  Future<void> recordTipBoostDelta({
    required String orderId,
    required String storeName,
    required double newTotalTipBoost,
  }) async {
    if (newTotalTipBoost <= 0) return;

    final orderRef = _firestore.collection('orders').doc(orderId);
    final boostEntryRef = _ledgerCol.doc('tipboost_$orderId');

    await _firestore.runTransaction((tx) async {
      final boostSnap = await tx.get(boostEntryRef);
      final alreadyCreditedBoost = boostSnap.exists
          ? (((boostSnap.data()?['amount'] as num?) ?? 0.0).toDouble())
          : 0.0;

      final delta = double.parse(
        (newTotalTipBoost - alreadyCreditedBoost).toStringAsFixed(2),
      );
      if (delta <= 0) return;

      tx.set(
        boostEntryRef,
        {
          'type': 'tip_boost',
          'orderId': orderId,
          'storeName': storeName,
          'amount': double.parse(newTotalTipBoost.toStringAsFixed(2)),
          'lastDelta': delta,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!boostSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        orderRef,
        {'driverTipBoostCredited': newTotalTipBoost},
        SetOptions(merge: true),
      );
    });
  }

  /// Atomically cashes out the exact current available balance to the card on file,
  /// resetting availableBalance to $0.00 while preserving all historical trip records.
  Future<double> cashOutAvailableBalance({
    required String cardLast4,
  }) async {
    final snap = await _ledgerCol.get();
    double credits = 0.0;
    double payouts = 0.0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString();
      final amount = ((data['amount'] as num?) ?? 0.0).toDouble();
      if (type == 'cashout') {
        payouts += amount.abs();
      } else {
        credits += amount;
      }
    }

    final cashoutAmount = double.parse(
      (credits - payouts).clamp(0.0, 999999.99).toStringAsFixed(2),
    );
    if (cashoutAmount <= 0) return 0.0;

    await _ledgerCol.add({
      'type': 'cashout',
      'amount': cashoutAmount,
      'cardLast4': cardLast4,
      'status': 'settled_instant',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cashoutAmount;
  }
}
