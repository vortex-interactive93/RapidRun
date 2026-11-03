import 'package:flutter/material.dart';
import 'package:rapidrun_driver/theme/design_tokens.dart';
import 'forecast_bars.dart';
import 'metrics_strip.dart';

/// InsightPanel – Phase 0 placeholder.
/// Will evolve into a swipeable carousel of Demand / Earnings Pace / Availability tools.
class InsightPanel extends StatelessWidget {
  final Widget child; // temporary: host legacy sheet content
  const InsightPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated.withOpacity(0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class InsightCarousel extends StatefulWidget {
  final bool online;
  final Duration? remaining;
  const InsightCarousel({super.key, required this.online, this.remaining});
  @override
  State<InsightCarousel> createState() => _InsightCarouselState();
}

class _InsightCarouselState extends State<InsightCarousel> {
  final _controller = PageController();
  int _index = 0;
  late final List<double> _forecast = mockForecastSeries(16);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated.withOpacity(0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                _DemandPanel(series: _forecast),
                _EarningsPanel(online: widget.online),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                List.generate(
                    2,
                    (i) => _Dot(active: i == _index),
                  ).expand((w) => [w, const SizedBox(width: 6)]).toList()
                  ..removeLast(),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? DesignTokens.primary : Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _DemandPanel extends StatelessWidget {
  final List<double> series;
  const _DemandPanel({required this.series});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demand Forecast',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ForecastBars(
                values: series,
                highlightIndex: DateTime.now().hour % series.length,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Higher bars suggest more frequent offer opportunities',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _EarningsPanel extends StatelessWidget {
  final bool online;
  const _EarningsPanel({required this.online});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Pace',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          MetricsStrip(
            acceptance: 0.82,
            earningsPace: 1.12,
            active: const Duration(minutes: 95),
            dense: true,
          ),
          const Spacer(),
          Text(
            online
                ? 'Maintain pace: you are trending +12% over typical.'
                : 'Go online to establish today\'s pace.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// (Availability panel removed – quick availability actions will live nearer the orb.)
