// File: lib/screens/catalog/widgets/catalog_filter_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CatalogFilterBar extends StatelessWidget {
  final List<String> chips;
  final String selectedChip;
  final Function(String) onChipSelected;

  const CatalogFilterBar({
    super.key,
    required this.chips,
    required this.selectedChip,
    required this.onChipSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = chip == selectedChip;

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                onChipSelected(chip);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF161922),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE5A93C)
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                chip,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0F1115) : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
