import 'package:flutter/material.dart';

class QuickAvailabilityActions extends StatelessWidget {
  final void Function(Duration) onExtend;
  final VoidCallback onRemoveCap;
  const QuickAvailabilityActions({
    super.key,
    required this.onExtend,
    required this.onRemoveCap,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_ActionChipSpec>[
      _ActionChipSpec(label: '+30m', dur: const Duration(minutes: 30)),
      _ActionChipSpec(label: '+60m', dur: const Duration(minutes: 60)),
      _ActionChipSpec(label: '+2h', dur: const Duration(hours: 2)),
    ];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: 1,
      child: Wrap(
        spacing: 8,
        children: [
          ...chips.map(
            (c) => _QuickChip(label: c.label, onTap: () => onExtend(c.dur)),
          ),
          _QuickChip(label: 'No Cap', onTap: onRemoveCap),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _ActionChipSpec {
  final String label;
  final Duration dur;
  _ActionChipSpec({required this.label, required this.dur});
}
