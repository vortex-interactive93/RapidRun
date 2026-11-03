import 'dart:async';
import 'package:flutter/foundation.dart';
import 'preferences_service.dart';

/// In-memory reactive display/accessibility preferences.
/// Listened to by MaterialApp builder to apply dynamic theming & scaling.
class DisplayPreferences extends ValueNotifier<DisplayPrefsState> {
  static final DisplayPreferences instance = DisplayPreferences._();
  DisplayPreferences._() : super(const DisplayPrefsState());

  Future<void> load() async {
    final reduceMotion = await PreferencesService.getReduceMotion();
    final highContrast = await PreferencesService.getHighContrast();
    final textScale = await PreferencesService.getTextScale();
    final biometric = await PreferencesService.getBiometricLock();
    value = value.copyWith(
      reduceMotion: reduceMotion,
      highContrast: highContrast,
      textScale: textScale,
      biometricLock: biometric,
    );
  }

  void setReduceMotion(bool v) {
    value = value.copyWith(reduceMotion: v);
    unawaited(PreferencesService.setReduceMotion(v));
  }

  void setHighContrast(bool v) {
    value = value.copyWith(highContrast: v);
    unawaited(PreferencesService.setHighContrast(v));
  }

  void setTextScale(double v) {
    value = value.copyWith(textScale: v);
    unawaited(PreferencesService.setTextScale(v));
  }

  void setBiometricLock(bool v) {
    value = value.copyWith(biometricLock: v);
    unawaited(PreferencesService.setBiometricLock(v));
  }
}

class DisplayPrefsState {
  final bool reduceMotion;
  final bool highContrast;
  final bool biometricLock;
  final double textScale;
  const DisplayPrefsState({
    this.reduceMotion = false,
    this.highContrast = false,
    this.biometricLock = false,
    this.textScale = 1.0,
  });
  DisplayPrefsState copyWith({
    bool? reduceMotion,
    bool? highContrast,
    bool? biometricLock,
    double? textScale,
  }) => DisplayPrefsState(
    reduceMotion: reduceMotion ?? this.reduceMotion,
    highContrast: highContrast ?? this.highContrast,
    biometricLock: biometricLock ?? this.biometricLock,
    textScale: textScale ?? this.textScale,
  );
}
