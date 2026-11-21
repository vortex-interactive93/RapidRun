// File: rapidrun_driver/lib/services/nav_voice_guidance.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tracks spoken/alerted turn milestones so the driver isn't nagged repeatedly
/// on the same turn while still getting timely heads-ups before maneuvers.
class NavVoiceGuidance {
  NavVoiceGuidance._();
  static final NavVoiceGuidance instance = NavVoiceGuidance._();

  bool muted = false;
  int _lastAnnouncedStepIndex = -1;
  bool _announcedCloseTurn = false;

  void resetTrip() {
    _lastAnnouncedStepIndex = -1;
    _announcedCloseTurn = false;
  }

  void toggleMute() {
    muted = !muted;
    HapticFeedback.selectionClick();
  }

  void onStepUpdated({
    required int stepIndex,
    required String instruction,
    required double distanceToStepMeters,
  }) {
    if (muted) return;

    if (stepIndex != _lastAnnouncedStepIndex) {
      _lastAnnouncedStepIndex = stepIndex;
      _announcedCloseTurn = false;
      _triggerCue(instruction);
      return;
    }

    // Close-approach cue inside ~90 meters (approx 295 ft)
    if (!_announcedCloseTurn && distanceToStepMeters > 0 && distanceToStepMeters <= 90.0) {
      _announcedCloseTurn = true;
      _triggerCue('Soon, $instruction');
    }
  }

  void _triggerCue(String phrase) {
    debugPrint('🔊 Nav Cue: $phrase');
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click).catchError((_) {});
  }
}
