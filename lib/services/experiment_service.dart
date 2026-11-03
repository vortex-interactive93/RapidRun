import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-side experiment / feature flag manager.
/// Manages an A/B test for popularity-based ranking (Variant A = off, B = on)
/// with optional forced override for debugging.
class ExperimentService {
  ExperimentService._();
  static final instance = ExperimentService._();

  static const _variantKey = 'exp_popularity_variant'; // 'A' | 'B'
  static const _forcedKey = 'exp_popularity_forced'; // 'on' | 'off'
  // Auto-fuzzy fallback experiment (Variant X = off, Y = on)
  static const _fuzzyVariantKey = 'exp_autofuzzy_variant'; // 'X' | 'Y'
  static const _fuzzyForcedKey = 'exp_autofuzzy_forced'; // 'on' | 'off'
  static const _userSeedKey =
      'exp_user_seed'; // persistent random int for stable bucketing

  // Future: we could store per-experiment custom split ratios; for now both 50/50
  double _popularityTestShare = 0.5; // share of users that get variant B
  double _fuzzyTestShare = 0.5; // share of users that get variant Y

  bool _loaded = false;
  String _variant = 'A';
  String? _forced; // null | 'on' | 'off'
  String _fuzzyVariant = 'X';
  String? _fuzzyForced; // null | 'on' | 'off'
  int? _userSeed;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Stable user seed used for deterministic bucketing.
      _userSeed = prefs.getInt(_userSeedKey);
      if (_userSeed == null) {
        // Use high resolution time plus small random jitter to reduce collision chance.
        final rand = Random();
        _userSeed =
            (DateTime.now().microsecondsSinceEpoch ^ rand.nextInt(1 << 31)) &
            0x7FFFFFFF;
        await prefs.setInt(_userSeedKey, _userSeed!);
      }

      _variant = prefs.getString(_variantKey) ?? '';
      if (_variant != 'A' && _variant != 'B') {
        _variant = _assignAB(_userSeed!, 'popularity', _popularityTestShare)
            ? 'B'
            : 'A';
        await prefs.setString(_variantKey, _variant);
      }
      _forced = prefs.getString(_forcedKey);
      if (_forced != 'on' && _forced != 'off') _forced = null;
      _fuzzyVariant = prefs.getString(_fuzzyVariantKey) ?? '';
      if (_fuzzyVariant != 'X' && _fuzzyVariant != 'Y') {
        _fuzzyVariant = _assignAB(_userSeed!, 'autofuzzy', _fuzzyTestShare)
            ? 'Y'
            : 'X';
        await prefs.setString(_fuzzyVariantKey, _fuzzyVariant);
      }
      _fuzzyForced = prefs.getString(_fuzzyForcedKey);
      if (_fuzzyForced != 'on' && _fuzzyForced != 'off') _fuzzyForced = null;
    } catch (_) {}
  }

  String get variant => _variant;
  String? get forced => _forced;
  String get fuzzyVariant => _fuzzyVariant;
  String? get fuzzyForced => _fuzzyForced;
  int? get userSeed => _userSeed;

  /// Returns true if popularity boost should be applied to ranking.
  bool popularityBoostEnabled() {
    if (_forced == 'on') return true;
    if (_forced == 'off') return false;
    return _variant == 'B';
  }

  Future<void> setForced(String? state) async {
    if (state != null && state != 'on' && state != 'off') return;
    _forced = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == null) {
        await prefs.remove(_forcedKey);
      } else {
        await prefs.setString(_forcedKey, state);
      }
    } catch (_) {}
  }

  /// Auto-fuzzy fallback enabled if fuzzy variant Y or forced on.
  bool autoFuzzyEnabled() {
    if (_fuzzyForced == 'on') return true;
    if (_fuzzyForced == 'off') return false;
    return _fuzzyVariant == 'Y';
  }

  Future<void> setFuzzyForced(String? state) async {
    if (state != null && state != 'on' && state != 'off') return;
    _fuzzyForced = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state == null) {
        await prefs.remove(_fuzzyForcedKey);
      } else {
        await prefs.setString(_fuzzyForcedKey, state);
      }
    } catch (_) {}
  }

  /// Adjust test share (0-1) for popularity experiment (applies only to future reassignment if reset is invoked).
  void configurePopularitySplit(double testShare) {
    if (testShare <= 0 || testShare >= 1) return;
    _popularityTestShare = testShare;
  }

  /// Adjust test share (0-1) for auto-fuzzy experiment.
  void configureAutoFuzzySplit(double testShare) {
    if (testShare <= 0 || testShare >= 1) return;
    _fuzzyTestShare = testShare;
  }

  /// Deterministically decide if user is in test bucket given a seed + experiment key.
  bool _assignAB(int seed, String key, double testShare) {
    // Simple consistent hash: combine seed & key code units.
    int h = seed;
    for (final c in key.codeUnits) {
      h = 0x1fffffff & (h + c);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= (h >> 6);
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= (h >> 11);
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    final normalized = (h & 0x7FFFFFFF) / 0x7FFFFFFF; // 0..1
    return normalized < testShare;
  }

  /// Reset assignments (NOT overrides). Keeps the same user seed for stability unless [regenerateSeed] true.
  Future<void> reassign({bool regenerateSeed = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (regenerateSeed) {
      final rand = Random();
      _userSeed =
          (DateTime.now().microsecondsSinceEpoch ^ rand.nextInt(1 << 31)) &
          0x7FFFFFFF;
      await prefs.setInt(_userSeedKey, _userSeed!);
    }
    _variant = _assignAB(_userSeed!, 'popularity', _popularityTestShare)
        ? 'B'
        : 'A';
    _fuzzyVariant = _assignAB(_userSeed!, 'autofuzzy', _fuzzyTestShare)
        ? 'Y'
        : 'X';
    await prefs.setString(_variantKey, _variant);
    await prefs.setString(_fuzzyVariantKey, _fuzzyVariant);
  }

  /// Clear forced overrides for both experiments.
  Future<void> clearOverrides() async {
    _forced = null;
    _fuzzyForced = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_forcedKey);
      await prefs.remove(_fuzzyForcedKey);
    } catch (_) {}
  }

  /// Snapshot useful for debug UIs.
  Map<String, dynamic> debugState() => {
    'popularity': {
      'variant': _variant,
      'forced': _forced,
      'enabled': popularityBoostEnabled(),
      'testShare': _popularityTestShare,
    },
    'autoFuzzy': {
      'variant': _fuzzyVariant,
      'forced': _fuzzyForced,
      'enabled': autoFuzzyEnabled(),
      'testShare': _fuzzyTestShare,
    },
    'userSeed': _userSeed,
  };
}
