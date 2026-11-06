// File: lib/screens/catalog/widgets/subcategory_hub_carousel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubcategoryHubItem {
  final String title;
  final IconData icon;

  const SubcategoryHubItem({required this.title, required this.icon});
}

class SubcategoryHubCarousel extends StatelessWidget {
  final String activeDepartment;
  final String? activeSubcategory;
  final ValueChanged<String?> onSubcategoryChanged;

  const SubcategoryHubCarousel({
    super.key,
    required this.activeDepartment,
    required this.activeSubcategory,
    required this.onSubcategoryChanged,
  });

  List<SubcategoryHubItem> _getSubcategoriesForDepartment(String dept) {
    final lower = dept.toLowerCase();

    if (lower.contains('body care')) {
      return const [
        SubcategoryHubItem(title: 'All Body Care', icon: Icons.grid_view_rounded),
        SubcategoryHubItem(title: 'Moisturizers', icon: Icons.water_drop_outlined),
        SubcategoryHubItem(title: 'Bath & Shower', icon: Icons.shower_outlined),
        SubcategoryHubItem(title: 'Lip Care', icon: Icons.face_retouching_natural_rounded),
        SubcategoryHubItem(title: 'Mini & Travel', icon: Icons.flight_takeoff_rounded),
      ];
    } else if (lower.contains('fragrance') && !lower.contains('home')) {
      return const [
        SubcategoryHubItem(title: 'All Fragrance', icon: Icons.auto_awesome_rounded),
        SubcategoryHubItem(title: 'Perfume & Cologne', icon: Icons.wine_bar_rounded),
        SubcategoryHubItem(title: 'Body Sprays & Mists', icon: Icons.air_rounded),
      ];
    } else if (lower.contains('candle')) {
      return const [
        SubcategoryHubItem(title: 'All Candles', icon: Icons.local_fire_department_outlined),
        SubcategoryHubItem(title: '3-Wick', icon: Icons.looks_3_rounded),
        SubcategoryHubItem(title: 'Single Wick', icon: Icons.looks_one_rounded),
        SubcategoryHubItem(title: 'Holders', icon: Icons.account_balance_outlined),
      ];
    } else if (lower.contains('soap') || lower.contains('sanitizer')) {
      return const [
        SubcategoryHubItem(title: 'All Soaps', icon: Icons.soap_outlined),
        SubcategoryHubItem(title: 'Foaming Soaps', icon: Icons.bubble_chart_outlined),
        SubcategoryHubItem(title: 'PocketBacs', icon: Icons.clean_hands_outlined),
        SubcategoryHubItem(title: 'Holders', icon: Icons.star_border_rounded),
      ];
    } else if (lower.contains('wallflower') || lower.contains('diffuser') || lower.contains('home fragrance')) {
      return const [
        SubcategoryHubItem(title: 'All Wallflowers', icon: Icons.power_rounded),
        SubcategoryHubItem(title: 'Refills', icon: Icons.colorize_rounded),
        SubcategoryHubItem(title: 'Plugs', icon: Icons.nightlight_round),
        SubcategoryHubItem(title: 'Car Fragrance', icon: Icons.directions_car_rounded),
        SubcategoryHubItem(title: 'Room Sprays', icon: Icons.cloud_outlined),
      ];
    } else if (lower.contains('men')) {
      return const [
        SubcategoryHubItem(title: "All Men's", icon: Icons.man_rounded),
        SubcategoryHubItem(title: 'Body Wash', icon: Icons.shower_outlined),
        SubcategoryHubItem(title: 'Body Spray', icon: Icons.air_rounded),
        SubcategoryHubItem(title: 'Cologne', icon: Icons.wine_bar_rounded),
        SubcategoryHubItem(title: 'Moisturizers', icon: Icons.water_drop_outlined),
      ];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final hubs = _getSubcategoriesForDepartment(activeDepartment);
    if (hubs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final hub = hubs[index];
          final isSelected = (activeSubcategory == null && index == 0) ||
              (activeSubcategory?.toLowerCase() == hub.title.toLowerCase());

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (index == 0) {
                onSubcategoryChanged(null);
              } else {
                onSubcategoryChanged(hub.title);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular Hub Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFE5A93C)
                        : const Color(0xFF161924),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE5A93C)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    hub.icon,
                    size: 22,
                    color: isSelected ? const Color(0xFF090A0E) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hub.title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFE5A93C) : Colors.white60,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
