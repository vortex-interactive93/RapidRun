// File: rapidrun_driver/lib/screens/shopping/in_store_picking_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import 'register_checkout_screen.dart';
import 'barcode_scanner_modal.dart';
import '../../widgets/alerts/driver_top_alert.dart';

class InStorePickingScreen extends StatefulWidget {
  final String orderId;
  final String storeName;
  final List<PickItem> items;

  const InStorePickingScreen({
    super.key,
    required this.orderId,
    required this.storeName,
    required this.items,
  });

  @override
  State<InStorePickingScreen> createState() => _InStorePickingScreenState();
}

class _InStorePickingScreenState extends State<InStorePickingScreen> {
  late List<PickItem> _items;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _subscribeToCustomerSubstitutionResponse();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _subscribeToCustomerSubstitutionResponse() {
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      final subResponse = data?['substitutionResponse'] as Map<String, dynamic>?;

      if (subResponse != null && subResponse['approved'] == true) {
        final resolvedItem = (subResponse['item'] ?? 'Approved Replacement').toString();

        setState(() {
          for (var i = 0; i < _items.length; i++) {
            final item = _items[i];
            if (item.isUnavailable || !item.isPicked) {
              _items[i] = item.copyWith(
                name: '$resolvedItem (Swapped)',
                pickedCount: item.quantity,
                isPicked: true,
                isUnavailable: false,
              );
            }
          }
        });

        HapticFeedback.heavyImpact();
        _showCleanToast('Customer approved swap for "$resolvedItem"!', const Color(0xFF10B981));
      }
    });
  }

  void _showCleanToast(String message, Color bgColor) {
    DriverTopAlert.show(
      context,
      message: message,
      accentColor: bgColor,
    );
  }

  void _openBarcodeScanner(int index) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerModal(
          targetItemName: _items[index].name,
          onBarcodeVerified: () {
            _togglePick(index);
          },
        ),
      ),
    );
  }

  int get _pickedCount => _items.where((i) => i.isPicked).length;
  int get _handledCount => _items.where((i) => i.isPicked || i.isUnavailable).length;

  void _togglePick(int index) {
    HapticFeedback.mediumImpact();
    final current = _items[index];
    final newCount = current.pickedCount < current.quantity ? current.pickedCount + 1 : 0;
    final isDone = newCount == current.quantity;

    setState(() {
      _items[index] = current.copyWith(
        pickedCount: newCount,
        isPicked: isDone,
        isUnavailable: false,
      );
    });
  }

  void _markUnavailable(int index) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Out of Stock',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select an action for "${_items[index].name}":',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.remove_shopping_cart_outlined, color: Colors.amber),
              title: const Text('Mark Out of Stock & Refund', style: TextStyle(color: Colors.white, fontSize: 13.5)),
              subtitle: const Text('Adjusts order total automatically', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _items[index] = _items[index].copyWith(isPicked: false, isUnavailable: true);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_items[index].name} marked out of stock.'),
                    backgroundColor: Colors.amber[800],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFE6B450)),
              title: const Text('Suggest Substitute', style: TextStyle(color: Colors.white, fontSize: 13.5)),
              subtitle: const Text('Send photo/replacement option to customer', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                final missingName = _items[index].name;
                await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
                  'substitutionRequired': {
                    'originalItem': missingName,
                    'requestedAt': FieldValue.serverTimestamp(),
                  },
                  'substitutionRequest': {
                    'status': 'pending',
                    'originalItem': missingName,
                    'suggestedItem': 'Black Flare Nightlight Fragrance Plug',
                    'suggestedPrice': 6.95,
                    'requestedAt': FieldValue.serverTimestamp(),
                  },
                });
                if (mounted) {
                  _showCleanToast('Substitution request for "$missingName" sent to customer!', const Color(0xFFE6B450));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleCompleteStockoutCancellation() {
    HapticFeedback.heavyImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.store_mall_directory_outlined, color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNFULFILLABLE ORDER',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Complete Store Stockout',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'All items are unavailable and substitutions were rejected. You will receive guaranteed Base Appearance Pay for your time and travel.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Guaranteed Dispatch Pay',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '\$5.00',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _executeStockoutPayout();
              },
              child: const Text(
                'CONFIRM & CLAIM \$5.00 DISPATCH PAY',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeStockoutPayout() async {
    HapticFeedback.heavyImpact();

    try {
      const double appearanceFee = 5.00;

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'cancelled_stockout',
        'cancellationReason': 'All items out of stock; substitutions declined',
        'driverAppearancePay': appearanceFee,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('drivers').doc(user.uid).set({
          'currentOrderId': FieldValue.delete(),
          'currentOrderStatus': FieldValue.delete(),
          'activeOrderId': FieldValue.delete(),
          'todayEarnings': FieldValue.increment(appearanceFee),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        DriverTopAlert.show(
          context,
          message: 'Order closed. \$5.00 Appearance Pay added to balance.',
          icon: Icons.monetization_on_rounded,
          accentColor: const Color(0xFF10B981),
        );

        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('⚠️ [Stockout Cancellation Error]: $e');
    }
  }

  void _showImageInspectModal(BuildContext context, PickItem item) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6B450).withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: Colors.black38,
                          ),
                        )
                      : const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black38),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.aisle,
                    style: const TextStyle(color: Color(0xFFE6B450), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Qty: ${item.quantity}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickingBody(BuildContext context) {
    const gold = Color(0xFFE6B450);
    return Column(
      children: [
        LinearProgressIndicator(
          value: _items.isNotEmpty ? _handledCount / _items.length : 0.0,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(gold),
          minHeight: 4,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _PickItemCard(
                item: item,
                onToggle: () => _togglePick(index),
                onInspectImage: () => _showImageInspectModal(context, item),
                onUnavailable: () => _markUnavailable(index),
                onScanBarcode: () => _openBarcodeScanner(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAisleWayfindingMap() {
    const gold = Color(0xFFE6B450);
    return Container(
      color: const Color(0xFF101216),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.map_rounded, color: gold, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'IN-STORE AISLE WAYFINDING CANVAS',
            style: TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bath & Body Works • Westover Village\nFragrance Wall & Moisturizers Bay',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    final total = _items.length;
    final bool isAllStockout = _items.isNotEmpty && _items.every((i) => i.isUnavailable);
    final bool canProceedToRegister = _items.every((i) => i.isPicked || i.isUnavailable) &&
        _items.any((i) => i.isPicked);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isFoldUnfolded = constraints.maxWidth > 600;

        return Scaffold(
          backgroundColor: const Color(0xFF141414),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1C1C1C),
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Shopping: $_handledCount of $total items handled ($_pickedCount picked)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            actions: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.orderId)
                    .collection('messages')
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final hasUnread = docs.any((d) => d.data()['isDriver'] == false);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Customer Messaging',
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: gold),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => OrderChatSheet(
                              orderId: widget.orderId,
                              senderId: 'driver_thomas',
                              senderName: 'Thomas (Shopper)',
                              isDriver: true,
                            ),
                          );
                        },
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ChatNotificationListenerWrapper(
            orderId: widget.orderId,
            currentSenderId: 'driver_thomas',
            currentSenderName: 'Thomas (Shopper)',
            isDriver: true,
            recipientLabel: 'Customer',
            child: isFoldUnfolded
                ? Row(
                    children: [
                      SizedBox(width: 380, child: _buildPickingBody(context)),
                      const VerticalDivider(color: Colors.white12, width: 1),
                      Expanded(child: _buildAisleWayfindingMap()),
                    ],
                  )
                : _buildPickingBody(context),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: isAllStockout
                    ? _handleCompleteStockoutCancellation
                    : (canProceedToRegister
                        ? () async {
                            HapticFeedback.heavyImpact();
                            final subtotal = _items
                                .where((i) => i.isPicked)
                                .fold<double>(
                                  0.0,
                                  (sum, item) => sum + (item.price * item.quantity),
                                );

                            final completed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterCheckoutScreen(
                                  orderId: widget.orderId,
                                  storeName: widget.storeName,
                                  customerAddress: '9009 White Settlement Rd, White Settlement, TX 76108',
                                  estimatedTotal: subtotal,
                                  totalItems: _pickedCount,
                                ),
                              ),
                            );

                            if (completed == true && mounted) {
                              Navigator.pop(context);
                            }
                          }
                        : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAllStockout ? const Color(0xFFEF4444) : gold,
                  disabledBackgroundColor: Colors.white12,
                  foregroundColor: isAllStockout ? Colors.white : Colors.black,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: Text(
                  isAllStockout
                      ? 'CLOSE BATCH: STORE STOCKOUT (\$5.00 PAY)'
                      : (canProceedToRegister
                          ? 'PROCEED TO REGISTER CHECKOUT'
                          : 'HANDLE REMAINING ITEMS (${total - _handledCount} LEFT)'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PickItem {
  final String id;
  final String name;
  final String aisle;
  final String? imageUrl;
  final String? size;
  final int quantity;
  final int pickedCount;
  final double price;
  final bool isPicked;
  final bool isUnavailable;

  const PickItem({
    required this.id,
    required this.name,
    required this.aisle,
    this.imageUrl,
    this.size,
    required this.quantity,
    this.pickedCount = 0,
    required this.price,
    this.isPicked = false,
    this.isUnavailable = false,
  });

  PickItem copyWith({String? name, bool? isPicked, bool? isUnavailable, int? pickedCount}) => PickItem(
        id: id,
        name: name ?? this.name,
        aisle: aisle,
        imageUrl: imageUrl,
        size: size,
        quantity: quantity,
        pickedCount: pickedCount ?? this.pickedCount,
        price: price,
        isPicked: isPicked ?? this.isPicked,
        isUnavailable: isUnavailable ?? this.isUnavailable,
      );
}

class _PickItemCard extends StatelessWidget {
  final PickItem item;
  final VoidCallback onToggle;
  final VoidCallback onInspectImage;
  final VoidCallback onUnavailable;
  final VoidCallback onScanBarcode;

  const _PickItemCard({
    required this.item,
    required this.onToggle,
    required this.onInspectImage,
    required this.onUnavailable,
    required this.onScanBarcode,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    Color cardBg = const Color(0xFF1E1E1E);
    Color borderColor = Colors.white.withValues(alpha: 0.08);

    if (item.isPicked) {
      cardBg = const Color(0xFF142419);
      borderColor = const Color(0xFF4ADE80).withValues(alpha: 0.45);
    } else if (item.isUnavailable) {
      cardBg = const Color(0xFF2B1D1D);
      borderColor = Colors.amber.withValues(alpha: 0.45);
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // 1. Packshot Canvas Thumbnail
            GestureDetector(
              onTap: onInspectImage,
              child: Stack(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                size: 28,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // 2. Item Details & Aisle Waypoint
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.aisle.toUpperCase(),
                      style: const TextStyle(
                        color: gold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.name,
                    style: TextStyle(
                      color: item.isPicked ? Colors.white60 : Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      decoration: item.isPicked
                          ? TextDecoration.lineThrough
                          : (item.isUnavailable ? TextDecoration.lineThrough : null),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.isUnavailable
                        ? 'OUT OF STOCK'
                        : 'Qty: ${item.quantity} • \$${item.price.toStringAsFixed(2)}${item.size != null ? ' • ${item.size}' : ''}',
                    style: TextStyle(
                      color: item.isUnavailable ? Colors.amber : Colors.white38,
                      fontSize: 11,
                      fontWeight: item.isUnavailable ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Barcode UPC Camera Scanner button
            IconButton(
              tooltip: 'Scan Barcode',
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFFE6B450),
                size: 20,
              ),
              onPressed: onScanBarcode,
            ),

            // Out of stock trigger button
            IconButton(
              tooltip: 'Item Unavailable',
              icon: Icon(
                Icons.remove_shopping_cart_outlined,
                color: item.isUnavailable ? Colors.amber : Colors.white24,
                size: 20,
              ),
              onPressed: onUnavailable,
            ),

            // Incremental Unit Pick Badge
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.isPicked ? const Color(0xFF4ADE80) : const Color(0xFFE6B450),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.isPicked ? item.quantity : item.pickedCount}/${item.quantity}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
