// File: lib/widgets/checkout/test_order_fab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/order_dispatch_service.dart';
import '../../screens/order/order_tracking_screen.dart';

class TestOrderFAB extends StatefulWidget {
  const TestOrderFAB({super.key});

  @override
  State<TestOrderFAB> createState() => _TestOrderFABState();
}

class _TestOrderFABState extends State<TestOrderFAB> {
  bool _loading = false;

  Future<void> _fireOrder() async {
    HapticFeedback.heavyImpact();
    setState(() => _loading = true);

    try {
      final orderId = await OrderDispatchService.instance.submitTestOrder();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE6B450),
          content: Text(
            '🔥 Live Order Dispatched: $orderId',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Dispatch Failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);

    return FloatingActionButton.extended(
      backgroundColor: gold,
      foregroundColor: Colors.black,
      elevation: 6,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Icon(Icons.rocket_launch_rounded, size: 20),
      label: Text(
        _loading ? 'DISPATCHING...' : 'TEST DISPATCH',
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      onPressed: _loading ? null : _fireOrder,
    );
  }
}
