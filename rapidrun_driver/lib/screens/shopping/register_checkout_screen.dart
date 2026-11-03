// File: rapidrun_driver/lib/screens/shopping/register_checkout_screen.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../delivery/active_delivery_screen.dart';
import 'receipt_camera_screen.dart';

const Color _gold = Color(0xFFE6B450);

class RegisterCheckoutScreen extends StatefulWidget {
  final String orderId;
  final String storeName;
  final String customerAddress;
  final double estimatedTotal;
  final int totalItems;

  const RegisterCheckoutScreen({
    super.key,
    required this.orderId,
    this.storeName = 'ALDI - White Settlement (76108)',
    this.customerAddress = '9009 White Settlement Rd, White Settlement, TX 76108',
    required this.estimatedTotal,
    required this.totalItems,
  });

  @override
  State<RegisterCheckoutScreen> createState() => _RegisterCheckoutScreenState();
}

class _RegisterCheckoutScreenState extends State<RegisterCheckoutScreen>
    with SingleTickerProviderStateMixin {
  // Provisioned Fleet Card Parameters
  static const String _fleetCardId = 'ic_1USMxwI5EZaqROKaWWAm5Zvo';
  static const String _cardLast4 = '0021';
  static const String _cardExp = '11/29';
  static const String _cardHolder = 'THOMAS DAVIS';

  int _currentStep = 0;
  bool _receiptCaptured = false;
  int _bagCount = 1;
  bool _isFinalizing = false;

  bool _isCardUnlocked = true;
  double _authorizedSpendCeiling = 0.0;
  bool _detectedSwipe = false;
  double _detectedSwipeAmount = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _authorizedSpendCeiling = widget.estimatedTotal * 1.15; // 15% Texas sales tax & register buffer

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _listenForPosAuthorization();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Listens for Stripe webhook authorization writes pushed to Firestore
  void _listenForPosAuthorization() {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();
      if (data != null && data['latestAuthorization'] != null) {
        final auth = data['latestAuthorization'];
        if (auth['approved'] == true && !_detectedSwipe) {
          setState(() {
            _detectedSwipe = true;
            _detectedSwipeAmount = (auth['amount'] as num).toDouble() / 100.0;
            _receiptCaptured = true;
          });
          HapticFeedback.heavyImpact();
          _showSwipeDetectedSheet();
        }
      }
    });
  }

  void _showSwipeDetectedSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF14171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARD SWIPE DETECTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Terminal POS: \$${_detectedSwipeAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Stripe authorization approved. Proceed to document scan to verify register items and lock the fleet card.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _launchReceiptCamera();
              },
              child: const Text(
                'CONTINUE TO RECEIPT AUDIT',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchReceiptCamera() async {
    final bool? completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ReceiptCameraScreen(
          orderId: widget.orderId,
          cardId: _fleetCardId,
          registerTotal: _detectedSwipe ? _detectedSwipeAmount : _authorizedSpendCeiling,
        ),
      ),
    );

    if (completed == true && mounted) {
      setState(() => _receiptCaptured = true);
    }
  }

  void _simulateReceiptCapture() {
    _launchReceiptCamera();
  }

  Future<void> _finalizeCheckout() async {
    if (!_receiptCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Please capture a photo of the register receipt first'),
        ),
      );
      return;
    }

    setState(() => _isFinalizing = true);
    HapticFeedback.heavyImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      batch.update(orderRef, {
        'status': 'outForDelivery',
        'bagCount': _bagCount,
        'checkoutCompletedAt': FieldValue.serverTimestamp(),
      });

      if (user != null) {
        final driverRef = FirebaseFirestore.instance.collection('drivers').doc(user.uid);
        batch.set(driverRef, {
          'currentOrderStatus': 'outForDelivery',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;

      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      final data = orderDoc.data() ?? {};

      final customerName = (data['customerName'] ?? 'RapidRun Customer').toString();
      final customerAddress = (data['customerAddress'] ?? widget.customerAddress).toString();
      final customerLat = (data['customerLat'] as num?)?.toDouble() ?? 32.759602;
      final customerLng = (data['customerLng'] as num?)?.toDouble() ?? -97.471416;
      final payout = (data['guaranteedPayout'] as num?)?.toDouble() ?? 12.50;
      final tip = (data['customerTip'] as num?)?.toDouble() ?? 5.00;

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(
            orderId: widget.orderId,
            customerName: customerName,
            customerAddress: customerAddress,
            customerLat: customerLat,
            customerLng: customerLng,
            payout: payout,
            tipAmount: tip,
            bagCount: _bagCount,
            deliveryNotes: 'Leave on front porch. Gate code: #4921. Please do not knock, baby sleeping!',
            customerPhone: '+18175550198',
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finalizing checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D0F12);
    const cardSurface = Color(0xFF1C1C1C);

    final isFoldUnfolded = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FLEET REGISTER PAY',
              style: TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
            Text(
              '${widget.storeName} • Order #${widget.orderId}',
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
              final bool hasUnread = docs.any((doc) => doc.data()['isDriver'] == false);

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Customer Messaging',
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: _gold, size: 22),
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
      body: SafeArea(
        child: isFoldUnfolded
            ? Row(
                children: [
                  Expanded(flex: 5, child: SingleChildScrollView(child: _buildVirtualCardPane())),
                  Expanded(flex: 5, child: _buildInstructionPane(cardSurface)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildVirtualCardPane(),
                  const SizedBox(height: 20),
                  _buildInstructionPane(cardSurface),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: (_receiptCaptured && !_isFinalizing) ? _finalizeCheckout : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              disabledBackgroundColor: Colors.white12,
              foregroundColor: Colors.black,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: _isFinalizing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    'START DELIVERY TO CUSTOMER',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                  ),
          ),
        ),
      ),
    );
  }

  /// AAA Noir VIP Fleet Card Display
  Widget _buildVirtualCardPane() {
    return Container(
      margin: const EdgeInsets.all(4),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B2215), // Brushed Titanium Bronze
            Color(0xFF151412),
            Color(0xFF090A0C),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE5A93C).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFFE5A93C), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'RAPIDRUN FLEET',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4 + (_pulseAnimation.value * 0.4)),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'JIT UNLOCKED',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        '••••  ••••  ••••  ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 18,
                          letterSpacing: 3.0,
                        ),
                      ),
                      Text(
                        _cardLast4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FLEET OPERATOR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          _cardHolder,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          _cardExp,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'MasterCard',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionPane(Color cardSurface) {
    return Container(
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _gold),
        ),
        child: Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  if (_currentStep < 2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: details.onStepContinue,
                      child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Standard Register / Self-Checkout',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Shop as an independent consumer', style: TextStyle(fontSize: 11)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'INDEPENDENT FULFILLMENT',
                            style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          'MAX \$${_authorizedSpendCeiling.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Proceed to any available cashier lane or self-checkout terminal.\n'
                      '2. Ring up items normally as an everyday customer.\n'
                      '3. Pay using your contactless RapidRun Fleet Card (•••• 0021).\n'
                      '4. Always keep the paper register receipt.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('Capture Printed Receipt',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Verify register total & items match', style: TextStyle(fontSize: 11)),
              isActive: _currentStep >= 1,
              state: _receiptCaptured ? StepState.complete : StepState.indexed,
              content: InkWell(
                onTap: _simulateReceiptCapture,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _receiptCaptured ? Colors.greenAccent : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _receiptCaptured ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                        color: _receiptCaptured ? Colors.greenAccent : _gold,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _receiptCaptured ? 'Receipt Uploaded & Verified' : 'Tap to Snap Receipt Photo',
                        style: TextStyle(
                          color: _receiptCaptured ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Stage Bags for Vehicle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Specify total bags used for drop-off', style: TextStyle(fontSize: 11)),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bags Packed:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: _gold),
                          onPressed: _bagCount > 1 ? () => setState(() => _bagCount--) : null,
                        ),
                        Text('$_bagCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: _gold),
                          onPressed: () => setState(() => _bagCount++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
