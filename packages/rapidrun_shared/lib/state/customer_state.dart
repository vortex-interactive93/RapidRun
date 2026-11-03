// File: packages/rapidrun_shared/lib/state/customer_state.dart

import 'package:flutter/foundation.dart';

enum MembershipTier { classic, velocity, noirVip }

class CustomerState extends ChangeNotifier {
  MembershipTier _tier = MembershipTier.noirVip;
  String _address = '9009 White Settlement Rd';
  String _gateCode = '#4921';
  int _defaultTipPercent = 20;
  bool _biometricsEnabled = true;
  bool _pushNotifications = true;

  // Getters
  MembershipTier get tier => _tier;
  String get address => _address;
  String get gateCode => _gateCode;
  int get defaultTipPercent => _defaultTipPercent;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get pushNotifications => _pushNotifications;

  String get tierName {
    switch (_tier) {
      case MembershipTier.classic:
        return 'RapidRun Classic';
      case MembershipTier.velocity:
        return 'Velocity Pass';
      case MembershipTier.noirVip:
        return 'Noir VIP';
    }
  }

  String get dispatchTier {
    switch (_tier) {
      case MembershipTier.classic:
        return 'Standard Broadcast';
      case MembershipTier.velocity:
        return 'Priority Match';
      case MembershipTier.noirVip:
        return 'Priority Fleet Tap';
    }
  }

  /// Calculates dynamic concierge fee based on tier
  double calculateDeliveryFee(double subtotal) {
    if (_tier == MembershipTier.noirVip) return 0.00; // $0 Delivery for VIP
    if (_tier == MembershipTier.velocity && subtotal >= 20.0) return 0.00;
    return 3.99;
  }

  /// Calculates dynamic Platform Service Fee (5% vs 2.5% vs 0%)
  double calculateServiceFee(double subtotal) {
    switch (_tier) {
      case MembershipTier.classic:
        return double.parse((subtotal * 0.05).toStringAsFixed(2)); // 5% Standard
      case MembershipTier.velocity:
        return double.parse((subtotal * 0.025).toStringAsFixed(2)); // 2.5% Reduced
      case MembershipTier.noirVip:
        return 0.00; // 0% Waived
    }
  }

  void setTier(MembershipTier newTier) {
    _tier = newTier;
    notifyListeners();
  }

  void updateAddress(String newAddress, String newGateCode) {
    _address = newAddress;
    _gateCode = newGateCode;
    notifyListeners();
  }

  void setTipPercent(int percent) {
    _defaultTipPercent = percent;
    notifyListeners();
  }

  void toggleBiometrics(bool val) {
    _biometricsEnabled = val;
    notifyListeners();
  }

  void toggleNotifications(bool val) {
    _pushNotifications = val;
    notifyListeners();
  }
}

// Global singleton instance for immediate access across screens
final customerState = CustomerState();
