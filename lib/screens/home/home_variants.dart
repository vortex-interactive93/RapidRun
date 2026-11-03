import 'package:flutter/material.dart';
import '../../theme/design_system.dart';
import '../../models/product.dart';

/// Data contract for a home header variant.
class HomeHeaderVariant extends StatelessWidget {
  final HomeVisualStyle style;
  final VoidCallback? onPrimaryAction;
  final List<Product> recommendations;
  final Widget serviceGrid;
  final Widget recent;

  const HomeHeaderVariant({
    super.key,
    required this.style,
    this.onPrimaryAction,
    required this.recommendations,
    required this.serviceGrid,
    required this.recent,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case HomeVisualStyle.classicGold:
        return _classicGold(context);
      case HomeVisualStyle.glassyShowcase:
        return _glassyShowcase(context);
      case HomeVisualStyle.splitHighlight:
        return _splitHighlight(context);
    }
  }

  Widget _classicGold(BuildContext context) {
    return Column(
      children: [
        _goldHero(
          context,
          title: 'RapidRun',
          subtitle: 'Local shopping & delivery',
          icon: Icons.local_shipping,
        ),
        const SizedBox(height: 24),
        serviceGrid,
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _goldHero(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF242424), Color(0xFF181818)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
        boxShadow: AppShadows.level2,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 56),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMed, letterSpacing: .3),
          ),
        ],
      ),
    );
  }

  Widget _glassyShowcase(BuildContext context) {
    return Column(
      children: [
        // Glass panel over subtle radial glow
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const RadialGradient(
              radius: 1.2,
              center: Alignment(-0.4, -0.6),
              colors: [Color(0x33E6B450), Colors.transparent],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .5),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.local_shipping, color: AppColors.gold, size: 52),
                    SizedBox(height: 14),
                    Text(
                      'RapidRun',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Shopping • Delivery • Takeout',
                      style: TextStyle(
                        color: AppColors.textMed,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        serviceGrid,
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _splitHighlight(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                flex: 55,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF181818),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: .3),
                    ),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.local_shipping,
                        color: AppColors.gold,
                        size: 40,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'RapidRun',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Fast local delivery',
                        style: TextStyle(color: AppColors.textMed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 45,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.gold.withValues(alpha: .18),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: .15),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.restaurant, color: AppColors.gold, size: 34),
                      SizedBox(height: 10),
                      Text(
                        'Takeout',
                        style: TextStyle(
                          color: AppColors.textHigh,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to explore',
                        style: TextStyle(
                          color: AppColors.textLow,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        serviceGrid,
        const SizedBox(height: 32),
      ],
    );
  }
}
