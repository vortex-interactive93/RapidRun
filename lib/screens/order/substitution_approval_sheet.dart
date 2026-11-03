// File: lib/screens/order/substitution_approval_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubstitutionApprovalSheet extends StatelessWidget {
  final String orderId;
  final String originalItemName;
  final String suggestedItemName;
  final double suggestedPrice;

  const SubstitutionApprovalSheet({
    super.key,
    required this.orderId,
    required this.originalItemName,
    this.suggestedItemName = 'Black Flare Nightlight Fragrance Plug',
    this.suggestedPrice = 6.95,
  });

  void _respondToSubstitution(BuildContext context, bool approved) async {
    HapticFeedback.heavyImpact();
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'substitutionRequest.status': approved ? 'approved' : 'rejected',
      'substitutionResponse': {
        'approved': approved,
        'item': approved ? suggestedItemName : null,
        'resolvedAt': FieldValue.serverTimestamp(),
      },
      'substitutionRequired': FieldValue.delete(),
    });
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF14171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFE5A93C), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ITEM SUBSTITUTION SUGGESTED',
                  style: TextStyle(color: Color(0xFFE5A93C), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$originalItemName is currently out of stock at Bath & Body Works.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestedItemName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '\$${suggestedPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _respondToSubstitution(context, false),
                  child: const Text('REFUND ITEM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _respondToSubstitution(context, true),
                  child: const Text('APPROVE SWAP', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
