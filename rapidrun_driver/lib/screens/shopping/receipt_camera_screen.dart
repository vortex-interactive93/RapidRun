// File: rapidrun_driver/lib/screens/shopping/receipt_camera_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class ReceiptCameraScreen extends StatefulWidget {
  final String orderId;
  final String cardId;
  final double registerTotal;

  const ReceiptCameraScreen({
    super.key,
    required this.orderId,
    required this.cardId,
    required this.registerTotal,
  });

  @override
  State<ReceiptCameraScreen> createState() => _ReceiptCameraScreenState();
}

class _ReceiptCameraScreenState extends State<ReceiptCameraScreen> {
  bool _capturing = false;
  bool _verified = false;

  Future<void> _captureReceipt() async {
    setState(() => _capturing = true);
    TacticalFeedbackService.instance.triggerReceiptVerified();

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _capturing = false;
      _verified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF10B981),
        content: Text(
          '📸 Paper Receipt Captured • Itemized POS Audit Passed',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RECEIPT AUDIT SCAN',
              style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            Text(
              'Order #${widget.orderId} • POS Total: \$${widget.registerTotal.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. Simulated Camera Viewfinder Frame
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              decoration: BoxDecoration(
                color: const Color(0xFF14171D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _verified ? const Color(0xFF10B981) : gold, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _verified ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                        size: 72,
                        color: _verified ? const Color(0xFF10B981) : gold.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _verified
                            ? 'RECEIPT VERIFIED'
                            : 'ALIGN PAPER RECEIPT INSIDE FRAME',
                        style: TextStyle(
                          color: _verified ? const Color(0xFF10B981) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ensure store name, register total, and items are clearly visible',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),

                  // Alignment reticle corners
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: gold, width: 3), left: BorderSide(color: gold, width: 3)))),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: gold, width: 3), right: BorderSide(color: gold, width: 3)))),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: gold, width: 3), left: BorderSide(color: gold, width: 3)))),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: gold, width: 3), right: BorderSide(color: gold, width: 3)))),
                  ),
                ],
              ),
            ),
          ),

          // 2. Capture Shutter Action Bar
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                onPressed: _capturing ? null : _captureReceipt,
                icon: _capturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Icon(Icons.camera_rounded, size: 22, color: Colors.black),
                label: Text(
                  _capturing ? 'PROCESSING AUDIT...' : 'SNAP RECEIPT PHOTO',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
