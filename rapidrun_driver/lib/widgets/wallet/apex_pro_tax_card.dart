// File: rapidrun_driver/lib/widgets/wallet/apex_pro_tax_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApexProTaxCard extends StatelessWidget {
  final bool isApexProMember;
  final double totalMilesLogged;
  final double totalGasReceiptsAmount;
  final VoidCallback onUpgradePressed;
  final VoidCallback onSnapGasReceipt;

  const ApexProTaxCard({
    super.key,
    required this.isApexProMember,
    required this.totalMilesLogged,
    required this.totalGasReceiptsAmount,
    required this.onUpgradePressed,
    required this.onSnapGasReceipt,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    const green = Color(0xFF00E676);
    final estimatedTaxSavings = totalMilesLogged * 0.67;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApexProMember ? gold.withValues(alpha: 0.4) : Colors.white10,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isApexProMember
                      ? gold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApexProMember ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
                  color: isApexProMember ? gold : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'APEX PRO TAX VAULT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!isApexProMember)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'UPGRADE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Automated IRS Schedule C Business Mileage & Fuel Audit',
                    style: TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Deduction Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ESTIMATED WRITE-OFF VALUE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${estimatedTaxSavings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: green,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TRACKED DISTANCE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalMilesLogged.toStringAsFixed(1)} mi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          if (isApexProMember) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: BorderSide(color: gold.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onSnapGasReceipt();
                    },
                    icon: const Icon(Icons.local_gas_station_rounded, size: 18),
                    label: const Text(
                      'Log Gas Receipt',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E222B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text(
                      'Export Tax CSV',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  onUpgradePressed();
                },
                child: const Text(
                  'UNLOCK APEX PRO · \$4.99/mo (Save \$2,000+ at Tax Time)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
