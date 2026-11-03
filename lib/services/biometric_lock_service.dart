import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'display_preferences.dart';

/// BiometricLockService manages biometric capability checks and authentication gating.
/// It cooperates with DisplayPreferences (biometricLock preference) to decide whether
/// to present a lock overlay. The service exposes a ValueListenable<bool> [locked]
/// to rebuild a UI overlay.
class BiometricLockService with ChangeNotifier {
  BiometricLockService._();
  static final BiometricLockService instance = BiometricLockService._();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _availableChecked = false;
  bool _isDeviceSupported = false;
  bool _biometricEnrolled = false;
  bool _locked = false;
  DateTime? _lastSuccess;

  bool get locked => _locked;
  bool get isDeviceSupported => _isDeviceSupported;
  bool get biometricEnrolled => _biometricEnrolled;

  Future<void> init() async {
    if (_availableChecked) return;
    try {
      _isDeviceSupported = await _auth.isDeviceSupported();
      _biometricEnrolled = await _auth.canCheckBiometrics;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BiometricLockService] capability check error: $e');
      }
      _isDeviceSupported = false;
      _biometricEnrolled = false;
    }
    _availableChecked = true;
    _recomputeLock(initial: true);
  }

  /// Should be called on app resume / foreground.
  Future<void> onResume() async {
    _recomputeLock();
    if (_locked) {
      await _attemptUnlock();
    }
  }

  /// Called when user toggles preference. If enabling, immediately validate.
  Future<void> onPreferenceChanged(bool enabled) async {
    if (enabled) {
      await init();
      if (!_isDeviceSupported || !_biometricEnrolled) {
        // Auto disable preference if unsupported.
        DisplayPreferences.instance.setBiometricLock(false);
        return;
      }
      _locked = true; // require first unlock now
      notifyListeners();
      await _attemptUnlock();
    } else {
      _locked = false;
      notifyListeners();
    }
  }

  Future<void> _attemptUnlock() async {
    if (!_locked) return;
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Unlock to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      if (didAuth) {
        _locked = false;
        _lastSuccess = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BiometricLockService] auth error: $e');
      }
    }
  }

  void _recomputeLock({bool initial = false}) {
    final prefs = DisplayPreferences.instance.value;
    if (!prefs.biometricLock) {
      _locked = false;
      notifyListeners();
      return;
    }
    // If device not supported disable automatically.
    if (_availableChecked && (!_isDeviceSupported || !_biometricEnrolled)) {
      if (prefs.biometricLock) {
        DisplayPreferences.instance.setBiometricLock(false);
      }
      _locked = false;
      notifyListeners();
      return;
    }
    // Lock logic: If initial, or last success is older than threshold (e.g. 5 minutes) we lock.
    final threshold = const Duration(minutes: 5);
    if (initial ||
        _lastSuccess == null ||
        DateTime.now().difference(_lastSuccess!) > threshold) {
      _locked = true;
      notifyListeners();
    }
  }
}
