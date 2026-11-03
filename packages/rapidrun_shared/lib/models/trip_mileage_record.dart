// File: packages/rapidrun_shared/lib/models/trip_mileage_record.dart

import 'package:flutter/foundation.dart';

@immutable
class TripMileageRecord {
  final String orderId;
  final double dispatchToStoreMiles; // Leg 1: Acceptance to Store
  final double storeToCustomerMiles;  // Leg 2: Store to Doorstep
  final double returnToZoneMiles;     // Leg 3 (Pro): Return transit
  final DateTime timestamp;
  final double irsDeductionRate;      // e.g., $0.67 / mile

  const TripMileageRecord({
    required this.orderId,
    required this.dispatchToStoreMiles,
    required this.storeToCustomerMiles,
    this.returnToZoneMiles = 0.0,
    required this.timestamp,
    this.irsDeductionRate = 0.67,
  });

  double get totalDeductibleMiles =>
      dispatchToStoreMiles + storeToCustomerMiles + returnToZoneMiles;

  double get estimatedTaxSavings => totalDeductibleMiles * irsDeductionRate;

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'dispatchToStoreMiles': dispatchToStoreMiles,
      'storeToCustomerMiles': storeToCustomerMiles,
      'returnToZoneMiles': returnToZoneMiles,
      'totalDeductibleMiles': totalDeductibleMiles,
      'estimatedTaxSavings': estimatedTaxSavings,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TripMileageRecord.fromMap(Map<String, dynamic> map) {
    return TripMileageRecord(
      orderId: map['orderId'] ?? '',
      dispatchToStoreMiles: (map['dispatchToStoreMiles'] as num?)?.toDouble() ?? 0.0,
      storeToCustomerMiles: (map['storeToCustomerMiles'] as num?)?.toDouble() ?? 0.0,
      returnToZoneMiles: (map['returnToZoneMiles'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      irsDeductionRate: (map['irsDeductionRate'] as num?)?.toDouble() ?? 0.67,
    );
  }
}
