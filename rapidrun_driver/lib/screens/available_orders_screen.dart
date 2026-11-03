import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Order; // hide conflicting Firestore internal Order
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../widgets/order_status_chip.dart';

/// Firestore-backed available orders feed.
/// Assumes orders collection stores orders with fields:
///  - status (string, expecting 'pending')
///  - driverId (nullable when unassigned)
///  - totals & items as per shared Order model.
class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  // Changing this key lets us force the StreamBuilder to recreate its stream.
  Key _listKey = UniqueKey();

  Query<Map<String, dynamic>> _query() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .where('driverId', isNull: true)
        // Show newest first for driver efficiency
        .orderBy('createdAt', descending: true);
  }

  Order _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Ensure id consistency
    data['id'] = doc.id;
    return Order.fromJson(_normalize(data));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    // If createdAt is a Timestamp, convert to ISO for shared model parser.
    final m = Map<String, dynamic>.from(raw);
    void fixTS(String k) {
      final v = m[k];
      if (v is Timestamp) m[k] = v.toDate().toIso8601String();
    }

    fixTS('createdAt');
    for (final k in [
      'assignedAt',
      'shoppingStartedAt',
      'shoppingCompletedAt',
      'deliveryStartedAt',
      'deliveredAt',
      'canceledAt',
    ]) {
      final v = m[k];
      if (v is Timestamp) m[k] = v.toDate().toIso8601String();
    }
    // Items may be stored without the productId field names expected; assume consistent.
    return m;
  }

  Future<String?> _claim(Order order) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('orders').doc(order.id);
    final driverRef = FirebaseFirestore.instance.collection('drivers').doc(uid);
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return 'Order no longer exists';
      final data = snap.data() as Map<String, dynamic>;
      if (data['driverId'] != null) return 'Already claimed';
      if (data['status'] != 'pending') return 'Not pending';
      tx.update(ref, {
        'driverId': uid,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });
      // Set active pointer on driver (pointer model). If driver already has one, abort.
      final driverSnap = await tx.get(driverRef);
      if (driverSnap.exists) {
        final dd = driverSnap.data() as Map<String, dynamic>;
        final existing = dd['activeOrderId'];
        if (existing != null && (existing as String).isNotEmpty) {
          return 'You already have an active order';
        }
      }
      tx.set(driverRef, {'activeOrderId': order.id}, SetOptions(merge: true));
      return null; // success
    });
  }

  Future<void> _refresh() async {
    // Force a rebuild with a new key so the StreamBuilder re-subscribes.
    setState(() => _listKey = UniqueKey());
    // Small delay to allow rebuild (not strictly necessary).
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: _listKey,
        stream: _query().snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error.toString();
            final isIndex =
                err.contains('FAILED_PRECONDITION') ||
                err.contains('failed-precondition');
            if (isIndex) {
              final urlRegex = RegExp(
                r'https://console.firebase.google.com[^\s)]+',
              );
              final match = urlRegex.firstMatch(err);
              final url = match?.group(0);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A Firestore composite index is required for this query.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Create an index with the following fields in order:',
                    ),
                    const SizedBox(height: 8),
                    const Text('1. status  (Ascending)'),
                    const Text('2. driverId (Ascending)'),
                    const Text('3. createdAt (Ascending)'),
                    const SizedBox(height: 12),
                    if (url != null) ...[
                      const Text(
                        'Quick create link (opens Firebase Console):',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        url,
                        style: const TextStyle(color: Colors.lightBlueAccent),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'After creating the index, wait for it to finish building (usually < 1 minute) then pull-to-refresh or reopen this screen.',
                    ),
                    const Spacer(),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Close & Retry Later'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Center(child: Text('Error: $err'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No available orders'));
          }
          final orders = docs.map(_fromDoc).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final o = orders[i];
                final age = _formatAge(o.createdAt);
                return _OrderCard(
                  order: o,
                  ageLabel: age,
                  onClaim: () async {
                    final err = await _claim(o);
                    if (!context.mounted) return;
                    if (err == null) {
                      // Haptic + analytics on successful claim
                      try {
                        HapticFeedback.lightImpact();
                      } catch (_) {}
                      FirebaseAnalytics.instance.logEvent(
                        name: 'driver_order_claim',
                        parameters: {
                          'order_id': o.id,
                          'age_seconds': DateTime.now()
                              .difference(o.createdAt)
                              .inSeconds,
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Claimed ${o.id}')),
                      );
                      Navigator.pop(context, o.id);
                    } else {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _formatAge(DateTime created) {
  final now = DateTime.now();
  final diff = now.difference(created);
  if (diff.inMinutes < 1) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final String ageLabel;
  final VoidCallback onClaim;
  const _OrderCard({
    required this.order,
    required this.ageLabel,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order.id}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OrderStatusChip(status: order.status, elevated: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${order.items.length} items • ${order.total.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    FilledButton(
                      onPressed: onClaim,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Claim'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ageLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
