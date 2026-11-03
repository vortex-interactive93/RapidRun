// File: rapidrun_driver/lib/screens/shopping/barcode_scanner_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BarcodeScannerModal extends StatefulWidget {
  final String targetItemName;
  final String expectedBarcode;
  final VoidCallback onBarcodeVerified;

  const BarcodeScannerModal({
    super.key,
    required this.targetItemName,
    this.expectedBarcode = '066755401291',
    required this.onBarcodeVerified,
  });

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _simulateScanSuccess() {
    HapticFeedback.heavyImpact();
    widget.onBarcodeVerified();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Dark Camera Viewport Simulation
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5A93C), width: 2),
                ),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, _) {
                        return Positioned(
                          top: _laserController.value * 260,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Top Header Bar
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'SCAN ITEM BARCODE',
                    style: TextStyle(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Item Name & Action Target
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Text(
                    widget.targetItemName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Align UPC barcode inside the laser target frame',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _simulateScanSuccess,
                    child: const Text('SIMULATE BARCODE MATCH', style: TextStyle(fontWeight: FontWeight.w900)),
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
