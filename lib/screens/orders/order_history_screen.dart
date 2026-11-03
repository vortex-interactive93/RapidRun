// File: lib/screens/orders/order_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/order.dart';
import '../../models/order_status.dart';
import '../../widgets/empty_state.dart';
import '../../theme/tokens.dart';
import '../account/order_receipt_detail_sheet.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  Future<void> _promptLogin() async {
    await Navigator.pushNamed(context, '/login');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data ?? FirebaseService.user;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order History')),
            body: _GuestOrdersPrompt(onSignIn: _promptLogin),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Order History')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots(),
            builder: (context, orderSnap) {
              if (orderSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = orderSnap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long,
                  title: 'No orders yet',
                  message: 'Once you place an order it will appear here with status updates.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final docId = docs[i].id;
                  final statusStr = data['status']?.toString() ?? 'pendingDispatch';
                  final storeName = data['storeName'] ?? 'Partner Store';
                  final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
                  final itemCount = (data['itemCount'] as num?)?.toInt() ?? 1;

                  return Card(
                    color: const Color(0xFF1C1C1C),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6B450).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFE6B450)),
                      ),
                      title: Text(
                        'Order #$docId',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        '$storeName • $itemCount items • \$${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => OrderReceiptDetailSheet(
                            orderData: {
                              'orderId': docId,
                              'storeName': storeName,
                              'subtotal': subtotal,
                              'deliveryFee': (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
                              'tax': (data['estimatedTax'] as num?)?.toDouble() ?? 0.0,
                              'tip': (data['customerTip'] as num?)?.toDouble() ?? 0.0,
                              'totalAuthorization': (data['totalAuthorization'] as num?)?.toDouble() ?? subtotal,
                              'items': data['items'] ?? [],
                            },
                          ),
                        );
                      },
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6B450).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusStr.toUpperCase(),
                          style: const TextStyle(color: Color(0xFFE6B450), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _GuestOrdersPrompt extends StatelessWidget {
  final VoidCallback onSignIn;
  const _GuestOrdersPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 72, color: Colors.white38),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Sign in to view your orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "Browse freely as a guest. When you're ready to place an order or view past orders, sign in to continue.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
