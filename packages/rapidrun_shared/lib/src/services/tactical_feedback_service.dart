// File: packages/rapidrun_shared/lib/src/services/tactical_feedback_service.dart

import 'package:flutter/services.dart';

class TacticalFeedbackService {
  TacticalFeedbackService._();
  static final TacticalFeedbackService instance = TacticalFeedbackService._();

  /// Fired on incoming dispatch offer sheet presentation
  Future<void> triggerDispatchAlert() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 140));
    HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  /// Fired when an item is successfully picked off physical store shelves
  void triggerItemPicked() {
    HapticFeedback.mediumImpact();
  }

  /// Fired when POS receipt scan passes itemized validation
  void triggerReceiptVerified() {
    HapticFeedback.lightImpact();
  }

  /// Fired on the earnings celebration modal presentation
  Future<void> triggerEarningsCelebration() async {
    for (int i = 0; i < 3; i++) {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
    }
    HapticFeedback.heavyImpact();
  }
}
