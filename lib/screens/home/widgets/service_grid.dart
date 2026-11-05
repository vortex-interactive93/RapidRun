// File: lib/screens/home/widgets/service_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shopping_delivery/aldi_store_screen.dart';
import '../../catalog/bbw_store_screen.dart';

const gold = Color(0xFFE5A93C);

class ServiceGrid extends StatelessWidget {
  final void Function(String route) onNavigate;
  const ServiceGrid({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.10,
      children: [
        _serviceCard(
          context,
          title: 'Bath & Body Works',
          subtitle: 'Aromatherapy & Candles',
          icon: Icons.spa_rounded,
          accentColor: const Color(0xFFE5A93C),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BbwStoreScreen()),
            );
          },
        ),
        _serviceCard(
          context,
          title: 'ALDI Market',
          subtitle: 'Pantry, Produce & Value',
          icon: Icons.shopping_basket_rounded,
          accentColor: const Color(0xFFFFD100),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AldiStoreScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _serviceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1E27), Color(0xFF12141A)],
          ),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
