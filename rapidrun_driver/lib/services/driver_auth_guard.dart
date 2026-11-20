// File: rapidrun_driver/lib/services/driver_auth_guard.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DriverAuthGuard {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DriverAuthGuard({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Resolves the canonical driver ID and optionally signs in anonymously
  /// if Firebase Auth has no active session yet during local/device testing.
  Future<String> resolveEffectiveDriverId({
    required String screenDriverId,
    bool allowAnonymousFallback = true,
  }) async {
    User? user = _auth.currentUser;

    if (user == null && allowAnonymousFallback) {
      try {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
        debugPrint('🔐 Signed in anonymously for driver testing: ${user?.uid}');
      } catch (e) {
        debugPrint('⚠️ Anonymous driver sign-in skipped: $e');
      }
    }

    final authUid = user?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      if (screenDriverId.isNotEmpty && screenDriverId != authUid) {
        debugPrint(
          'ℹ️ Driver ID alignment: screenDriverId="$screenDriverId" vs authUid="$authUid". '
          'Using "$screenDriverId" so Firestore listeners stay aligned.',
        );
      }
      return screenDriverId.isNotEmpty ? screenDriverId : authUid;
    }

    return screenDriverId.isNotEmpty ? screenDriverId : 'driver_local_tester';
  }

  /// Ensures the driver profile document exists before incrementing earnings or trips
  Future<void> ensureDriverDocExists(String driverId) async {
    final docRef = _firestore.collection('drivers').doc(driverId);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'driverId': driverId,
        'balance': 0.0,
        'availableCashout': 0.0,
        'todayEarnings': 0.0,
        'thisWeekEarnings': 0.0,
        'basePay': 0.0,
        'customerTips': 0.0,
        'boostedTips': 0.0,
        'surgeBonuses': 0.0,
        'totalDeliveriesCompleted': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'driverId': driverId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
