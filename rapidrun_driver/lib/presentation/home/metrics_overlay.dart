import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'metrics_strip.dart';

class MetricsOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const MetricsOverlay({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _FrostPanel(
      title: 'Performance Metrics',
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          MetricsStrip(
            acceptance: 0.83,
            earningsPace: 1.09,
            active: const Duration(minutes: 142),
          ),
          const SizedBox(height: 18),
          Text(
            'Pace compares your earnings rate to a typical baseline. Acceptance helps unlock incentives.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Use available width; if narrow, allow stats to wrap gracefully.
              final maxPerRow = constraints.maxWidth > 520 ? 4 : 2;
              final stats = const [
                _MiniStat(label: 'Today Trips', value: '7'),
                _MiniStat(label: 'This Week', value: '34'),
                _MiniStat(label: 'Est. Hourly', value: '28'),
                _MiniStat(label: 'Acceptance 7d', value: '78%'),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats
                    .map(
                      (w) => SizedBox(
                        width:
                            (constraints.maxWidth - (maxPerRow - 1) * 10) /
                            maxPerRow,
                        child: w,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class InfoOverlay extends StatelessWidget {
  final bool online;
  final Duration? remaining;
  final VoidCallback onClose;
  const InfoOverlay({
    super.key,
    required this.online,
    required this.remaining,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final status = online ? 'Online' : 'Offline';
    final cap = remaining == null
        ? 'No cap'
        : '${remaining!.inMinutes} min left';
    return _FrostPanel(
      title: 'Status & Info',
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          _InfoRow(label: 'Status', value: status),
          _InfoRow(label: 'Availability', value: cap),
          _InfoRow(label: 'App Build', value: 'alpha'),
          _InfoRow(label: 'Device', value: '${Theme.of(context).platform}'),
          const SizedBox(height: 14),
          Text(
            'More profile & program details will appear here soon.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: DesignTokens.labelUpper.copyWith(
                fontSize: 10,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: DesignTokens.labelUpper.copyWith(
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;
  const _FrostPanel({
    required this.title,
    required this.child,
    required this.onClose,
  });
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 20;
    // Dynamic horizontal insets: ensure min 12, avoid camera / notch area.
    final leftInset = 110.0; // space for command rail + breathing room
    final rightInset = 12.0;
    return Positioned(
      top: topPad,
      right: rightInset,
      left: leftInset,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 22),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceElevated.withOpacity(.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(.05)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
