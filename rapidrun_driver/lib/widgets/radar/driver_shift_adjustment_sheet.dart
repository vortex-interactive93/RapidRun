// File: rapidrun_driver/lib/widgets/radar/driver_shift_adjustment_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DriverShiftAdjustmentSheet extends StatelessWidget {
  final Duration remainingDuration;
  final ValueChanged<Duration> onAdjustRemaining;
  final VoidCallback onGoOffline;

  const DriverShiftAdjustmentSheet({
    super.key,
    required this.remainingDuration,
    required this.onAdjustRemaining,
    required this.onGoOffline,
  });

  String _formatDuration(Duration d) {
    if (d.isNegative || d.inMinutes <= 0) return '0h 00m';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF14171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Status
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ACTIVE SHIFT CONTROLS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(remainingDuration),
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Adjust how long you want to receive dispatch orders or pause your shift.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Quick Time Adjustment Chips
          const Text(
            'EXTEND ACTIVE TIME',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildExtensionChip('+30m', const Duration(minutes: 30)),
              const SizedBox(width: 8),
              _buildExtensionChip('+1 hr', const Duration(hours: 1)),
              const SizedBox(width: 8),
              _buildExtensionChip('+2 hrs', const Duration(hours: 2)),
              const SizedBox(width: 8),
              _buildExtensionChip('Set 4h', const Duration(hours: 4), isAbsolute: true),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: const BorderSide(color: Color(0xFFEF5350)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context);
                    onGoOffline();
                  },
                  icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: const Text('GO OFFLINE', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('KEEP WORKING', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionChip(String label, Duration duration, {bool isAbsolute = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          final newDuration = isAbsolute ? duration : remainingDuration + duration;
          onAdjustRemaining(newDuration);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E222A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
