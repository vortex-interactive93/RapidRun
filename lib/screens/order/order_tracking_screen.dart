// File: lib/screens/order/order_tracking_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import 'package:url_launcher/url_launcher.dart';
import 'order_tracking_map_view.dart';
import 'delivery_completion_sheet.dart';
import 'substitution_approval_sheet.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _hasShownDeliverySheet = false;
  bool _hasShownSubstitutionSheet = false;
  static const LatLng _fallbackStore = LatLng(32.7485, -97.4261);
  static const LatLng _fallbackCustomer = LatLng(32.759602, -97.471416);

  void _openChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderChatSheet(
        orderId: widget.orderId,
        senderId: 'cust_sandbox_99',
        senderName: 'Thomas (Customer)',
        isDriver: false,
      ),
    );
  }

  void _showUpdateNotesDialog(BuildContext context, String currentNotes) {
    final controller = TextEditingController(text: currentNotes);
    const gold = Color(0xFFE6B450);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Delivery Instructions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add gate codes, building numbers, or drop-off requests. Updates sync instantly to your shopper.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Gate code is #4921. Leave on front porch.',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF121212),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
            onPressed: () async {
              final newNotes = controller.text.trim();
              if (newNotes.isNotEmpty) {
                await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                  'deliveryNotes': newNotes,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save & Notify Shopper', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF121212);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
        title: Text('Order #${widget.orderId}', style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ChatNotificationListenerWrapper(
        orderId: widget.orderId,
        currentSenderId: 'cust_sandbox_99',
        currentSenderName: 'Thomas (Customer)',
        isDriver: false,
        recipientLabel: 'Personal Shopper',
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
          builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: gold));
          }

          final data = snapshot.data!.data() ?? {};
          final status = data['status']?.toString() ?? 'pendingDispatch';
          final storeName = data['storeName'] ?? 'Bath & Body Works';
          final deliveryNotes = data['deliveryNotes'] ?? 'Leave at front door.';
          final bagCount = data['bagCount'] ?? 1;

          final storeLat = (data['storeLat'] as num?)?.toDouble() ?? _fallbackStore.latitude;
          final storeLng = (data['storeLng'] as num?)?.toDouble() ?? _fallbackStore.longitude;
          final custLat = (data['customerLat'] as num?)?.toDouble() ?? _fallbackCustomer.latitude;
          final custLng = (data['customerLng'] as num?)?.toDouble() ?? _fallbackCustomer.longitude;

          if ((status == 'delivered' || status == 'completed') && !_hasShownDeliverySheet) {
            _hasShownDeliverySheet = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DeliveryCompletionSheet(
                  orderId: widget.orderId,
                  driverName: (data['driverName'] ?? 'Thomas Davis').toString(),
                  dropoffPhotoUrl: data['dropoffPhotoUrl']?.toString(),
                  initialTip: (data['customerTip'] as num?)?.toDouble() ?? 5.0,
                ),
              );
            });
          }

          if (data['substitutionRequired'] != null && !_hasShownSubstitutionSheet) {
            _hasShownSubstitutionSheet = true;
            final subMap = data['substitutionRequired'] as Map<String, dynamic>;
            final missingName = (subMap['originalItem'] ?? 'Item').toString();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SubstitutionApprovalSheet(
                  orderId: widget.orderId,
                  originalItemName: missingName,
                ),
              );
            });
          }

          return Column(
            children: [
              // 1. Dark-Themed Live Vector Route Map Component
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                child: OrderTrackingMapView(
                  orderId: widget.orderId,
                  storeLat: storeLat,
                  storeLng: storeLng,
                  deliveryLat: custLat,
                  deliveryLng: custLng,
                ),
              ),

              // 2. Stage Telemetry & Actions
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHeroStageCard(status, storeName),
                    const SizedBox(height: 20),
                    _buildProgressPipeline(status),
                    const SizedBox(height: 20),
                    if (status != 'pendingDispatch') ...[
                      _buildShopperCard(context, data),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1C),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.doorbell_outlined, color: gold, size: 18),
                                  SizedBox(width: 8),
                                  Text('DELIVERY INSTRUCTIONS', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                              TextButton(
                                onPressed: () => _showUpdateNotesDialog(context, deliveryNotes),
                                child: const Text('Edit / Add Code', style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(deliveryNotes, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          if (status == 'outForDelivery' || status == 'completed') ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('$bagCount BAG STAGED BY SHOPPER', style: const TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  }

  Widget _buildHeroStageCard(String status, String storeName) {
    const gold = Color(0xFFE6B450);
    String title = 'Matching with a Shopper';
    String subtitle = 'Broadcasting your batch to top-rated couriers nearby.';
    IconData icon = Icons.radar_rounded;

    if (status == 'driverAssigned' || status == 'shoppingActive') {
      title = 'Shopper at $storeName';
      subtitle = 'Your personal shopper is hand-picking and inspecting items.';
      icon = Icons.shopping_basket_rounded;
    } else if (status == 'registerCheckout') {
      title = 'Register Checkout';
      subtitle = 'Purchasing items with RapidRun Fleet Card and packing bags.';
      icon = Icons.point_of_sale_rounded;
    } else if (status == 'outForDelivery') {
      title = 'Shopper En Route to You!';
      subtitle = 'Your items are bagged and on the vehicle. Arriving shortly.';
      icon = Icons.delivery_dining_rounded;
    } else if (status == 'completed') {
      title = 'Delivered to Doorstep!';
      subtitle = 'Items verified and safely placed at your destination.';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: gold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPipeline(String currentStatus) {
    final stages = ['pendingDispatch', 'shoppingActive', 'outForDelivery', 'completed'];
    int activeIdx = 0;
    if (currentStatus == 'driverAssigned' || currentStatus == 'shoppingActive') activeIdx = 1;
    if (currentStatus == 'registerCheckout') activeIdx = 2;
    if (currentStatus == 'outForDelivery') activeIdx = 2;
    if (currentStatus == 'completed') activeIdx = 3;

    return Row(
      children: List.generate(stages.length, (idx) {
        final isPassed = idx <= activeIdx;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx < stages.length - 1 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: isPassed ? const Color(0xFFE6B450) : Colors.white12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildShopperCard(BuildContext context, Map<String, dynamic> data) {
    const gold = Color(0xFFE6B450);
    final shopperName = (data['driverName'] ?? 'Thomas').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: gold.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Shopper: $shopperName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  '★ 5.0 • Verified Courier',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF282828),
              foregroundColor: gold,
              padding: const EdgeInsets.all(8),
            ),
            icon: const Icon(Icons.phone_rounded, size: 18),
            onPressed: () => launchUrl(Uri.parse('tel:+18175550198')),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF282828),
              foregroundColor: gold,
              padding: const EdgeInsets.all(8),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            onPressed: () => _openChatSheet(context),
          ),
        ],
      ),
    );
  }
}
