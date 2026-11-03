// File: rapidrun_driver/lib/screens/shopping/substitution_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void openSubstitutionModal({
  required BuildContext context,
  required String orderId,
  required String missingItemName,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF14171D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ITEM OUT OF STOCK: $missingItemName',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Notify customer to approve a replacement or refund the item from the JIT authorization.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                'substitutionRequired': {
                  'originalItem': missingItemName,
                  'requestedAt': FieldValue.serverTimestamp(),
                },
                'substitutionRequest': {
                  'status': 'pending',
                  'originalItem': missingItemName,
                  'suggestedItem': 'Black Flare Nightlight Fragrance Plug',
                  'suggestedPrice': 6.95,
                  'requestedAt': FieldValue.serverTimestamp(),
                },
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Substitution photo request dispatched to customer.')),
              );
            },
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('SNAP PHOTO OF SIMILAR SHELF ITEM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}
