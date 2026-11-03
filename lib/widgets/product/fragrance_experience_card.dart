// File: lib/widgets/product/fragrance_experience_card.dart

import 'package:flutter/material.dart';
import '../../models/product.dart';

class FragranceExperienceCard extends StatelessWidget {
  final FragranceProfile profile;
  final List<String> cleanStandards;

  const FragranceExperienceCard({
    super.key,
    required this.profile,
    this.cleanStandards = const [],
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.20), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Family Tag + Perfumer attribution
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Fragrance Pyramid'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Text(
                  profile.family.toUpperCase(),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scent Pyramid Rows
          if (profile.topNotes.isNotEmpty) ...[
            _PyramidRow(
              tier: 'TOP',
              subtitle: 'First Impression',
              notes: profile.topNotes,
              icon: Icons.lightbulb_outline_rounded,
              color: const Color(0xFFFFE082),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10, height: 1),
            ),
          ],

          if (profile.heartNotes.isNotEmpty) ...[
            _PyramidRow(
              tier: 'HEART',
              subtitle: 'Signature Body',
              notes: profile.heartNotes,
              icon: Icons.favorite_border_rounded,
              color: const Color(0xFFF48FB1),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10, height: 1),
            ),
          ],

          if (profile.baseNotes.isNotEmpty) ...[
            _PyramidRow(
              tier: 'BASE',
              subtitle: 'Lasting Impression',
              notes: profile.baseNotes,
              icon: Icons.spa_outlined,
              color: const Color(0xFFB0BEC5),
            ),
          ],

          // Clean Standards Chips
          if (cleanStandards.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: cleanStandards.map((std) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2818),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF4ADE80)),
                      const SizedBox(width: 4),
                      Text(
                        std,
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PyramidRow extends StatelessWidget {
  final String tier;
  final String subtitle;
  final List<String> notes;
  final IconData icon;
  final Color color;

  const _PyramidRow({
    required this.tier,
    required this.subtitle,
    required this.notes,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    tier,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: notes.map((note) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  note,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
