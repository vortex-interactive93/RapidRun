import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _kNotifications = 'prefs.notificationsEnabled';
  static const _kMergeOnLogin = 'prefs.mergeOnLogin';
  static const _kDefaultTip = 'prefs.defaultTipPercent';
  static const _kQuietStartHour = 'prefs.quietStartHour';
  static const _kQuietStartMinute = 'prefs.quietStartMinute';
  static const _kQuietEndHour = 'prefs.quietEndHour';
  static const _kQuietEndMinute = 'prefs.quietEndMinute';
  static const _kDigestMode = 'prefs.digestMode';
  static const _kNotifOrderStatus = 'prefs.notif.orderStatus';
  static const _kNotifPriceDrops = 'prefs.notif.priceDrops';
  static const _kNotifLowInventory = 'prefs.notif.lowInventory';
  static const _kNotifPromos = 'prefs.notif.promos';
  static const _kNotifSubstitutions = 'prefs.notif.substitutions';
  static const _kLeaveAtDoor = 'prefs.leaveAtDoor';
  static const _kRingBell = 'prefs.ringBell';
  static const _kGateCode = 'prefs.gateCode';
  static const _kDeliveryNotes = 'prefs.deliveryNotes';
  // Accessibility & security
  static const _kReduceMotion = 'prefs.reduceMotion';
  static const _kHighContrast = 'prefs.highContrast';
  static const _kBiometricLock = 'prefs.biometricLock';
  static const _kTextScale = 'prefs.textScale';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  // Notifications
  static Future<bool> getNotificationsEnabled() async {
    final p = await _prefs();
    return p.getBool(_kNotifications) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifications, v);
  }

  // Merge on login
  static Future<bool> getMergeOnLogin() async {
    final p = await _prefs();
    return p.getBool(_kMergeOnLogin) ?? true;
  }

  static Future<void> setMergeOnLogin(bool v) async {
    final p = await _prefs();
    await p.setBool(_kMergeOnLogin, v);
  }

  // Default tip percent (0.0 - 1.0)
  static Future<double> getDefaultTip() async {
    final p = await _prefs();
    return p.getDouble(_kDefaultTip) ?? 0.15;
  }

  static Future<void> setDefaultTip(double v) async {
    final p = await _prefs();
    await p.setDouble(_kDefaultTip, v);
  }

  // Quiet hours and digest mode
  static Future<bool> getDigestMode() async {
    final p = await _prefs();
    return p.getBool(_kDigestMode) ?? false;
  }

  static Future<void> setDigestMode(bool v) async {
    final p = await _prefs();
    await p.setBool(_kDigestMode, v);
  }

  // Notification channels
  static Future<bool> getOrderStatusChannel() async {
    final p = await _prefs();
    return p.getBool(_kNotifOrderStatus) ?? true;
  }

  static Future<void> setOrderStatusChannel(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifOrderStatus, v);
  }

  static Future<bool> getPriceDropsChannel() async {
    final p = await _prefs();
    return p.getBool(_kNotifPriceDrops) ?? true;
  }

  static Future<void> setPriceDropsChannel(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifPriceDrops, v);
  }

  static Future<bool> getLowInventoryChannel() async {
    final p = await _prefs();
    return p.getBool(_kNotifLowInventory) ?? false;
  }

  static Future<void> setLowInventoryChannel(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifLowInventory, v);
  }

  static Future<bool> getPromosChannel() async {
    final p = await _prefs();
    return p.getBool(_kNotifPromos) ?? true;
  }

  static Future<void> setPromosChannel(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifPromos, v);
  }

  static Future<bool> getSubstitutionsChannel() async {
    final p = await _prefs();
    return p.getBool(_kNotifSubstitutions) ?? true;
  }

  static Future<void> setSubstitutionsChannel(bool v) async {
    final p = await _prefs();
    await p.setBool(_kNotifSubstitutions, v);
  }

  static Future<({int hour, int minute})> getQuietStart() async {
    final p = await _prefs();
    return (
      hour: p.getInt(_kQuietStartHour) ?? 22,
      minute: p.getInt(_kQuietStartMinute) ?? 0,
    );
  }

  static Future<void> setQuietStart(int hour, int minute) async {
    final p = await _prefs();
    await p.setInt(_kQuietStartHour, hour);
    await p.setInt(_kQuietStartMinute, minute);
  }

  static Future<({int hour, int minute})> getQuietEnd() async {
    final p = await _prefs();
    return (
      hour: p.getInt(_kQuietEndHour) ?? 7,
      minute: p.getInt(_kQuietEndMinute) ?? 0,
    );
  }

  static Future<void> setQuietEnd(int hour, int minute) async {
    final p = await _prefs();
    await p.setInt(_kQuietEndHour, hour);
    await p.setInt(_kQuietEndMinute, minute);
  }

  // Delivery instructions
  static Future<bool> getLeaveAtDoor() async {
    final p = await _prefs();
    return p.getBool(_kLeaveAtDoor) ?? true;
  }

  static Future<void> setLeaveAtDoor(bool v) async {
    final p = await _prefs();
    await p.setBool(_kLeaveAtDoor, v);
  }

  static Future<bool> getRingBell() async {
    final p = await _prefs();
    return p.getBool(_kRingBell) ?? false;
  }

  static Future<void> setRingBell(bool v) async {
    final p = await _prefs();
    await p.setBool(_kRingBell, v);
  }

  static Future<String> getGateCode() async {
    final p = await _prefs();
    return p.getString(_kGateCode) ?? '';
  }

  static Future<void> setGateCode(String v) async {
    final p = await _prefs();
    await p.setString(_kGateCode, v);
  }

  static Future<String> getDeliveryNotes() async {
    final p = await _prefs();
    return p.getString(_kDeliveryNotes) ?? '';
  }

  static Future<void> setDeliveryNotes(String v) async {
    final p = await _prefs();
    await p.setString(_kDeliveryNotes, v);
  }

  // Accessibility / security / UI
  static Future<bool> getReduceMotion() async {
    final p = await _prefs();
    return p.getBool(_kReduceMotion) ?? false;
  }

  static Future<void> setReduceMotion(bool v) async {
    final p = await _prefs();
    await p.setBool(_kReduceMotion, v);
  }

  static Future<bool> getHighContrast() async {
    final p = await _prefs();
    return p.getBool(_kHighContrast) ?? false;
  }

  static Future<void> setHighContrast(bool v) async {
    final p = await _prefs();
    await p.setBool(_kHighContrast, v);
  }

  static Future<bool> getBiometricLock() async {
    final p = await _prefs();
    return p.getBool(_kBiometricLock) ?? false;
  }

  static Future<void> setBiometricLock(bool v) async {
    final p = await _prefs();
    await p.setBool(_kBiometricLock, v);
  }

  static Future<double> getTextScale() async {
    final p = await _prefs();
    return p.getDouble(_kTextScale) ?? 1.0;
  }

  static Future<void> setTextScale(double v) async {
    final p = await _prefs();
    await p.setDouble(_kTextScale, v);
  }

  // Diagnostics
  static Future<void> resetAll() async {
    final p = await _prefs();
    await p.remove(_kNotifications);
    await p.remove(_kMergeOnLogin);
    await p.remove(_kDefaultTip);
    await p.remove(_kQuietStartHour);
    await p.remove(_kQuietStartMinute);
    await p.remove(_kQuietEndHour);
    await p.remove(_kQuietEndMinute);
    await p.remove(_kDigestMode);
    await p.remove(_kNotifOrderStatus);
    await p.remove(_kNotifPriceDrops);
    await p.remove(_kNotifLowInventory);
    await p.remove(_kNotifPromos);
    await p.remove(_kNotifSubstitutions);
    await p.remove(_kLeaveAtDoor);
    await p.remove(_kRingBell);
    await p.remove(_kGateCode);
    await p.remove(_kDeliveryNotes);
    await p.remove(_kReduceMotion);
    await p.remove(_kHighContrast);
    await p.remove(_kBiometricLock);
    await p.remove(_kTextScale);
  }
}
