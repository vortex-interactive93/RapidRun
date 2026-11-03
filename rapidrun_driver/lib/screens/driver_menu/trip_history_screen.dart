// File: rapidrun_driver/lib/screens/driver_menu/trip_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Recently';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    if (diff.inHours < 24 && dt.day == now.day) {
      return 'Today, $hour:$minute $period';
    }
    return '${dt.month}/${dt.day}/${dt.year}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip History & Audits',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'completed')
            .orderBy('deliveredAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Fallback for missing index or ordering: query completed orders without server-side ordering
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, fallbackSnap) {
                if (fallbackSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: gold));
                }
                final docs = fallbackSnap.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmptyState();
                return _buildTripList(docs, gold);
              },
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState();

          return _buildTripList(docs, gold);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'No Completed Runs Yet',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Completed dispatch orders will appear here.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Color gold,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = docs[index].data();
        final orderId = docs[index].id;
        final storeName = (data['storeName'] ?? data['store'] ?? 'Bath & Body Works').toString();
        final payout = (data['guaranteedPayout'] as num?)?.toDouble() ??
            (data['payout'] as num?)?.toDouble() ??
            16.58;
        final tip = (data['customerTip'] as num?)?.toDouble() ??
            (data['tipAmount'] as num?)?.toDouble() ??
            5.00;
        final itemsList = data['items'] as List<dynamic>? ?? [];
        final itemCount = itemsList.isNotEmpty
            ? itemsList.length
            : ((data['itemCount'] as num?)?.toInt() ?? 1);
        final deliveredAt = data['deliveredAt'] as Timestamp?;
        final dateStr = _formatTimestamp(deliveredAt);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF181B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #${orderId.length > 12 ? orderId.substring(0, 12) : orderId} · $itemCount ${itemCount == 1 ? "item" : "items"} · $dateStr',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${payout.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Inc. \$${tip.toStringAsFixed(2)} tip',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
