// File: rapidrun_driver/lib/screens/wallet/driver_cashout_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';

class DriverCashoutSheet extends StatefulWidget {
  final double? availableBalance;
  final String? driverId;

  const DriverCashoutSheet({
    super.key,
    this.availableBalance,
    this.driverId,
  });

  @override
  State<DriverCashoutSheet> createState() => _DriverCashoutSheetState();
}

class _DriverCashoutSheetState extends State<DriverCashoutSheet> {
  bool _isProcessing = false;

  Future<void> _executeInstantPayout() async {
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1200));

    final double transferred = driverEarningsState.executeInstantCashout();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF14171D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.black, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deposit Sent',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${transferred.toStringAsFixed(2)} was transferred to your linked card via RapidRun Instant Pay.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93C),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return ListenableBuilder(
      listenable: driverEarningsState,
      builder: (context, _) {
        final double balance = driverEarningsState.availableCashout;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: const BoxDecoration(
            color: Color(0xFF14171D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RAPIDRUN WALLET',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('STRIPE CONNECT', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '\$${balance.toStringAsFixed(2)}',
                style: const TextStyle(color: gold, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('Instant transfer to debit card ending in 4242 (1% fee applies).', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_isProcessing || balance <= 0) ? null : _executeInstantPayout,
                child: _isProcessing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        balance > 0 ? 'CASHOUT TO DEBIT CARD' : 'NO FUNDS AVAILABLE',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
