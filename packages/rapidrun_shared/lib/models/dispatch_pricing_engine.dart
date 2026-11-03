// File: packages/rapidrun_shared/lib/models/dispatch_pricing_engine.dart

class DispatchPricingEngine {
  // Base configuration constants
  static const double minimumBasePay = 4.50;
  static const double perMileRate = 0.85;
  static const double perItemPickRate = 0.45;
  static const double highTicketThreshold = 50.00;
  static const double highTicketCommissionRate = 0.04; // 4% extra on luxury/fragrance runs

  /// Computes the fair, dynamic driver payout for a broadcasted batch
  static DriverPayoutBreakdown calculateDriverPayout({
    required double estimatedDistanceMiles,
    required int totalItemCount,
    required double basketSubtotal,
    required double activeSurgeBonus,
    required double customerTip,
  }) {
    // 1. Distance & Mileage Effort
    final double mileageComponent = estimatedDistanceMiles * perMileRate;

    // 2. In-Store Item Picking Effort
    final double pickingComponent = totalItemCount * perItemPickRate;

    // 3. High-Value Basket Premium (Compensates care for $50+ luxury/fragrance batches)
    final double basketValueBonus = (basketSubtotal >= highTicketThreshold)
        ? (basketSubtotal * highTicketCommissionRate)
        : 0.0;

    // 4. Raw Base Pay before Surge & Tip
    final double rawBasePay = minimumBasePay + mileageComponent + pickingComponent + basketValueBonus;
    final double normalizedBasePay = double.parse(rawBasePay.toStringAsFixed(2));

    // 5. Total Driver Earnings
    final double totalPayout = normalizedBasePay + activeSurgeBonus + customerTip;

    return DriverPayoutBreakdown(
      basePay: normalizedBasePay,
      mileagePay: double.parse(mileageComponent.toStringAsFixed(2)),
      pickEffortPay: double.parse(pickingComponent.toStringAsFixed(2)),
      highValueBonus: double.parse(basketValueBonus.toStringAsFixed(2)),
      surgeBonus: activeSurgeBonus,
      tip: customerTip,
      totalPayout: double.parse(totalPayout.toStringAsFixed(2)),
    );
  }

  /// Calculates dynamic Concierge Service Fee charged to the customer
  static double calculateCustomerServiceFee({
    required double basketSubtotal,
    required double estimatedDistanceMiles,
  }) {
    const double baseFee = 3.99;
    final double distanceSurcharge = (estimatedDistanceMiles > 3.0)
        ? (estimatedDistanceMiles - 3.0) * 0.75
        : 0.0;
    final double basketScaleFee = basketSubtotal * 0.05; // 5% platform service fee

    return double.parse((baseFee + distanceSurcharge + basketScaleFee).toStringAsFixed(2));
  }
}

class DriverPayoutBreakdown {
  final double basePay;
  final double mileagePay;
  final double pickEffortPay;
  final double highValueBonus;
  final double surgeBonus;
  final double tip;
  final double totalPayout;

  const DriverPayoutBreakdown({
    required this.basePay,
    required this.mileagePay,
    required this.pickEffortPay,
    required this.highValueBonus,
    required this.surgeBonus,
    required this.tip,
    required this.totalPayout,
  });

  Map<String, dynamic> toMap() => {
    'basePay': basePay,
    'mileagePay': mileagePay,
    'pickEffortPay': pickEffortPay,
    'highValueBonus': highValueBonus,
    'surgeBonus': surgeBonus,
    'tip': tip,
    'totalPayout': totalPayout,
  };
}
