// File: packages/rapidrun_shared/lib/state/driver_earnings_state.dart

import 'package:flutter/foundation.dart';

@immutable
class DriverShiftLedger {
  final double availableCashout;
  final double todayTotal;
  final double thisWeekTotal;
  final double basePay;
  final double customerTips;
  final double boostedTips;
  final double surgeBonuses;
  final int completedTrips;
  final double ytdMiles;

  const DriverShiftLedger({
    required this.availableCashout,
    required this.todayTotal,
    required this.thisWeekTotal,
    required this.basePay,
    required this.customerTips,
    required this.boostedTips,
    required this.surgeBonuses,
    required this.completedTrips,
    required this.ytdMiles,
  });

  /// Real production zero-state for new driver accounts or fresh sessions
  factory DriverShiftLedger.initial() {
    return const DriverShiftLedger(
      availableCashout: 0.0,
      todayTotal: 0.0,
      thisWeekTotal: 0.0,
      basePay: 0.0,
      customerTips: 0.0,
      boostedTips: 0.0,
      surgeBonuses: 0.0,
      completedTrips: 0,
      ytdMiles: 0.0,
    );
  }

  DriverShiftLedger copyWith({
    double? availableCashout,
    double? todayTotal,
    double? thisWeekTotal,
    double? basePay,
    double? customerTips,
    double? boostedTips,
    double? surgeBonuses,
    int? completedTrips,
    double? ytdMiles,
  }) {
    return DriverShiftLedger(
      availableCashout: availableCashout ?? this.availableCashout,
      todayTotal: todayTotal ?? this.todayTotal,
      thisWeekTotal: thisWeekTotal ?? this.thisWeekTotal,
      basePay: basePay ?? this.basePay,
      customerTips: customerTips ?? this.customerTips,
      boostedTips: boostedTips ?? this.boostedTips,
      surgeBonuses: surgeBonuses ?? this.surgeBonuses,
      completedTrips: completedTrips ?? this.completedTrips,
      ytdMiles: ytdMiles ?? this.ytdMiles,
    );
  }
}

class DriverEarningsState extends ChangeNotifier {
  static final DriverEarningsState instance = DriverEarningsState._internal();
  DriverEarningsState._internal();
  factory DriverEarningsState() => instance;

  DriverShiftLedger _ledger = DriverShiftLedger.initial();
  final Map<int, double> _dailyEarnings = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};

  DriverShiftLedger get ledger => _ledger;
  double get todayEarnings => _ledger.todayTotal;
  double get availableCashout => _ledger.availableCashout;
  double get thisWeekTotal => _ledger.thisWeekTotal;
  double get basePay => _ledger.basePay;
  double get customerTips => _ledger.customerTips;
  double get boostedTips => _ledger.boostedTips;
  double get surgeBonuses => _ledger.surgeBonuses;
  double get ytdMiles => _ledger.ytdMiles;
  int get completedTrips => _ledger.completedTrips;

  double getDailyEarnings(int weekday) => _dailyEarnings[weekday] ?? 0.0;

  double get maxDailyEarnings {
    final maxVal = _dailyEarnings.values.fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    return maxVal > 0 ? maxVal : 1.0;
  }

  /// Syncs real driver ledger from Firestore driver doc and completed runs
  void syncFromFirestoreData({
    required double balance,
    required double todayEarnings,
    required double weeklyEarnings,
    required double basePay,
    required double tips,
    double boosted = 0.0,
    required double surge,
    required int completedRuns,
    required double ytdMiles,
  }) {
    _ledger = DriverShiftLedger(
      availableCashout: balance,
      todayTotal: todayEarnings,
      thisWeekTotal: weeklyEarnings,
      basePay: basePay,
      customerTips: tips,
      boostedTips: boosted,
      surgeBonuses: surge,
      completedTrips: completedRuns,
      ytdMiles: ytdMiles,
    );
    _dailyEarnings[DateTime.now().weekday] = todayEarnings;
    notifyListeners();
  }

  /// Syncs earnings and trip count from live Firestore snapshots
  void syncEarnings(double earnings, int trips, {double boosted = 0.0}) {
    _ledger = _ledger.copyWith(
      availableCashout: earnings,
      todayTotal: earnings,
      thisWeekTotal: earnings,
      boostedTips: boosted,
      completedTrips: trips,
    );
    _dailyEarnings[DateTime.now().weekday] = earnings;
    notifyListeners();
  }

  void recordTipBoost(double boostAmount) {
    final currentDay = DateTime.now().weekday;
    _dailyEarnings[currentDay] = (_dailyEarnings[currentDay] ?? 0.0) + boostAmount;

    _ledger = _ledger.copyWith(
      availableCashout: _ledger.availableCashout + boostAmount,
      todayTotal: _ledger.todayTotal + boostAmount,
      thisWeekTotal: _ledger.thisWeekTotal + boostAmount,
      customerTips: _ledger.customerTips + boostAmount,
      boostedTips: _ledger.boostedTips + boostAmount,
    );
    notifyListeners();
  }

  /// Executes instant cashout, transferring [availableCashout] to debit card and zeroing available balance
  double executeInstantCashout() {
    final double transferred = _ledger.availableCashout;
    _ledger = _ledger.copyWith(availableCashout: 0.0);
    notifyListeners();
    return transferred;
  }

  void recordCompletedBatch({
    required double payoutAmount,
    required double tip,
    double mileageMiles = 3.8,
    double surgeBonus = 0.0,
  }) {
    final baseComponent = (payoutAmount - tip - surgeBonus).clamp(0.0, payoutAmount);
    final currentDay = DateTime.now().weekday;
    _dailyEarnings[currentDay] = (_dailyEarnings[currentDay] ?? 0.0) + payoutAmount;

    _ledger = DriverShiftLedger(
      availableCashout: _ledger.availableCashout + payoutAmount,
      todayTotal: _ledger.todayTotal + payoutAmount,
      thisWeekTotal: _ledger.thisWeekTotal + payoutAmount,
      basePay: _ledger.basePay + baseComponent,
      customerTips: _ledger.customerTips + tip,
      boostedTips: _ledger.boostedTips,
      surgeBonuses: _ledger.surgeBonuses + surgeBonus,
      completedTrips: _ledger.completedTrips + 1,
      ytdMiles: _ledger.ytdMiles + mileageMiles,
    );
    notifyListeners();
  }
}

final driverEarningsState = DriverEarningsState();
