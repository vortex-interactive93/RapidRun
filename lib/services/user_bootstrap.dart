// File: lib/services/user_bootstrap.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Ensures a minimal user document exists for the authenticated user so
/// early syncing services (favorites, cart, orders) do not hit permission
/// errors when they attempt merges. Safe to call multiple times.
class UserBootstrap {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc() async {
    final user = FirebaseService.user;
    if (user == null) return; // guest
    final ref = _db.collection('users').doc(user.uid);
    try {
      final snap = await ref.get().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[UserBootstrap] Timed out waiting for network doc; proceeding with cached/local fallback.');
          throw Exception('Timeout');
        },
      );
      if (!snap.exists) {
        await ref.set({
          'createdAt': FieldValue.serverTimestamp(),
          'favorites': [],
          'cart': {},
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await ref.set({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('[UserBootstrap] permission denied creating user doc');
      } else {
        debugPrint('[UserBootstrap] unexpected error: ${e.code} ${e.message}');
      }
    } catch (e) {
      debugPrint('[UserBootstrap] bootstrap note: $e');
    }
  }
}
