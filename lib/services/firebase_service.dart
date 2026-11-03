// File: lib/services/firebase_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import '../config/app_config.dart';
import 'user_bootstrap.dart';
import 'log_service.dart';

class FirebaseService {
  static bool _initialized = false;
  static User? _user;
  static User? get user => _user;
  static Stream<User?> get userStream =>
      FirebaseAuth.instance.authStateChanges();

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        Firebase.app();
      }

      // Configure Firestore offline cache persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // Safe to ignore
      } else {
        rethrow;
      }
    } catch (e) {
      // Fallback
    }

    final auth = FirebaseAuth.instance;
    _user = auth.currentUser;

    auth.authStateChanges().listen((u) {
      _user = u;
      LogService.instance.log(
        'auth state -> ${u?.uid ?? 'SIGN_OUT'}',
        category: 'auth',
      );
      if (_user != null) {
        unawaited(UserBootstrap.ensureUserDoc());
      }
    });

    if (_user == null && AppConfig.autoAnonymousAuth) {
      try {
        _user = (await auth.signInAnonymously()).user;
        if (_user != null) {
          unawaited(UserBootstrap.ensureUserDoc());
        }
      } catch (e) {
        // ignore: avoid_print
        print('[FirebaseService] Anonymous sign-in failed: $e');
      }
    } else if (_user != null) {
      unawaited(UserBootstrap.ensureUserDoc());
    }
    _initialized = true;
  }
}
