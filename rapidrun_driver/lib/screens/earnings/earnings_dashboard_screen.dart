// File: rapidrun_driver/lib/screens/earnings/earnings_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapidrun_shared/rapidrun_shared.dart';
import '../../widgets/wallet/apex_pro_tax_card.dart';

class EarningsDashboardScreen extends StatefulWidget {
  final double? currentBalance;
  final double? weekTotal;
  final double? basePay;
  final double? customerTips;
  final double? boostedTips;
  final double? surgeBonus;
  final double? ytdMiles;

  const EarningsDashboardScreen({
    super.key,
    this.currentBalance,
    this.weekTotal,
    this.basePay,
    this.customerTips,
    this.boostedTips,
    this.surgeBonus,
    this.ytdMiles,
  });

  @override
  State<EarningsDashboardScreen> createState() => _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends State<EarningsDashboardScreen> {
  bool _cashingOut = false;

  Future<void> _handleInstantCashOut() async {
    HapticFeedback.heavyImpact();
    setState(() => _cashingOut = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    final double transferred = driverEarningsState.executeInstantCashout();

    if (!mounted) return;
    setState(() => _cashingOut = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
            SizedBox(width: 10),
            Text('Deposit Sent', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '\$${transferred.toStringAsFixed(2)} was transferred to your linked card via RapidRun Instant Pay.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE6B450)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const green = Color(0xFF00E676);
    const bg = Color(0xFF121212);
    const cardSurface = Color(0xFF1C1C1C);

    return ListenableBuilder(
      listenable: driverEarningsState,
      builder: (context, _) {
        final currentBalance = widget.currentBalance ?? driverEarningsState.availableCashout;
        final weekTotal = widget.weekTotal ?? driverEarningsState.thisWeekTotal;
        final basePay = widget.basePay ?? driverEarningsState.basePay;
        final customerTips = widget.customerTips ?? driverEarningsState.customerTips;
        final boostedTips = widget.boostedTips ?? driverEarningsState.boostedTips;
        final surgeBonus = widget.surgeBonus ?? driverEarningsState.surgeBonuses;
        final ytdMiles = widget.ytdMiles ?? driverEarningsState.ytdMiles;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: const Color(0xFF181818),
            iconTheme: const IconThemeData(color: gold),
            title: const Text(
              'Earnings & Payouts',
              style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Available Balance & Instant Cash Out Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE TO CASH OUT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_cashingOut || currentBalance <= 0) ? null : _handleInstantCashOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: _cashingOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                              )
                            : Text(
                                currentBalance > 0 ? 'CASH OUT TO DEBIT NOW' : 'NO FUNDS AVAILABLE',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 0.4),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Instant Transfer Fee: \$0.50 • Standard Weekly Free (Tuesdays)',
                        style: TextStyle(color: Colors.white38, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Customer Tip Boosts Showcase Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gold.withValues(alpha: 0.15),
                      cardSurface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, color: gold, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CUSTOMER TIP BOOSTS',
                            style: TextStyle(color: gold, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Extra rewards added post-delivery for exceptional service',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+\$${boostedTips.toStringAsFixed(2)}',
                      style: const TextStyle(color: green, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Apex Pro Business Tax & Mileage Vault Card
              ApexProTaxCard(
                isApexProMember: true,
                totalMilesLogged: ytdMiles,
                totalGasReceiptsAmount: 0.0,
                onUpgradePressed: () {},
                onSnapGasReceipt: () {},
              ),

              const SizedBox(height: 20),

              // 3. Weekly Bar Chart Breakdown
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'This Week',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${weekTotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Constrained Row of Real Daily Bars
                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (idx) {
                          final weekday = idx + 1; // 1 = Mon, 2 = Tue, ..., 7 = Sun
                          final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final dayEarnings = driverEarningsState.getDailyEarnings(weekday);
                          final maxVal = driverEarningsState.maxDailyEarnings;
                          final fraction = dayEarnings > 0 ? (dayEarnings / maxVal).clamp(0.15, 1.0) : 0.0;
                          final isToday = weekday == DateTime.now().weekday;

                          final label = dayEarnings == 0
                              ? '\$0'
                              : (dayEarnings % 1 == 0
                                  ? '\$${dayEarnings.toInt()}'
                                  : '\$${dayEarnings.toStringAsFixed(2)}');

                          return _buildDayColumn(
                            dayLabels[idx],
                            fraction,
                            label,
                            isToday: isToday,
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Itemized Payout Sources
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Payout Sources',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    _buildRow('Base Shopping & Mileage Pay', basePay),
                    const Divider(color: Colors.white10, height: 16),
                    _buildRow('100% Customer Tips', customerTips, color: green),
                    const Divider(color: Colors.white10, height: 16),
                    _buildRow('Customer Tip Boosts', boostedTips, color: gold),
                    const Divider(color: Colors.white10, height: 16),
                    _buildRow('Peak Hour & Surge Bonuses', surgeBonus, color: green),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. Tax Mileage Log Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF142419),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.alt_route_rounded, color: Color(0xFF4ADE80), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tax Mileage Logged (YTD)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ytdMiles.toStringAsFixed(1)} miles tracked (est. \$${(ytdMiles * 0.67).toStringAsFixed(2)} deduction)',
                            style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildDayColumn(String day, double fraction, String amount, {bool isToday = false}) {
    const gold = Color(0xFFE6B450);
    final clampedFraction = fraction.clamp(0.05, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          amount,
          style: TextStyle(
            color: isToday ? gold : Colors.white38,
            fontSize: 9.5,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 65 * clampedFraction,
          decoration: BoxDecoration(
            color: isToday ? gold : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            color: isToday ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static Widget _buildRow(String label, double amount, {Color color = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
