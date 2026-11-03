import 'package:flutter/material.dart';

const gold = Color(0xFFE6B450);

class ServiceGrid extends StatelessWidget {
  final void Function(String route) onNavigate;
  const ServiceGrid({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.05,
      children: [
        _serviceCard(
          context,
          title: 'Shopping & Delivery',
          subtitle: 'ALDI, Target & more',
          icon: Icons.shopping_cart,
          onTap: () => onNavigate('/shopping'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF242424), Color(0xFF1A1A1A)],
            ),
            border: Border.all(color: gold.withValues(alpha: 0.28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        _serviceCard(
          context,
          title: 'Takeout',
          subtitle: 'Restaurants & Stores',
          icon: Icons.restaurant,
          onTap: () => onNavigate('/takeout'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF242424), Color(0xFF1A1A1A)],
            ),
            border: Border.all(color: gold.withValues(alpha: 0.28), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serviceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    BoxDecoration? decoration,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: decoration,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: gold.withValues(alpha: 0.25),
                child: Icon(icon, color: gold),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: gold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
