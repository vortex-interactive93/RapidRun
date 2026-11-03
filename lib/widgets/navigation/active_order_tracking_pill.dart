// File: lib/widgets/navigation/active_order_tracking_pill.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveOrderTrackingPill extends StatelessWidget {
  final String orderId;
  final VoidCallback onExpandTracking;

  const ActiveOrderTrackingPill({
    super.key,
    required this.orderId,
    required this.onExpandTracking,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();

        final status = data['status'] as String? ?? 'pendingDispatch';
        if (status == 'delivered' || status == 'completed') return const SizedBox.shrink();

        String statusLabel = 'Matching with Courier...';
        IconData statusIcon = Icons.radar_rounded;
        Color accentColor = const Color(0xFFE5A93C);

        if (status == 'driverAssigned' || status == 'shoppingActive') {
          statusLabel = 'Shopper at ${data['storeName'] ?? 'Store'}';
          statusIcon = Icons.shopping_basket_outlined;
        } else if (status == 'registerCheckout') {
          statusLabel = 'Purchasing items at register';
          statusIcon = Icons.point_of_sale_rounded;
        } else if (status == 'outForDelivery') {
          statusLabel = 'En Route · Arriving shortly';
          statusIcon = Icons.navigation_rounded;
          accentColor = const Color(0xFF10B981);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF14171D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onExpandTracking();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        'TRACK',
                        style: TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFFE5A93C), size: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
