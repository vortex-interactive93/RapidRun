import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Remote, Firestore-backed app configuration for feature gating and beta toggles.
class AppRemoteConfig {
  final bool inviteOnly;
  final bool paymentsTestOnly;
  final List<String>
  shoppingFeaturedNames; // match against retailer names (lowercase)
  final List<String> takeoutFeaturedIds; // match against restaurant ids
  final String? betaBannerText;
  final Timestamp? updatedAt;

  const AppRemoteConfig({
    required this.inviteOnly,
    required this.paymentsTestOnly,
    required this.shoppingFeaturedNames,
    required this.takeoutFeaturedIds,
    this.betaBannerText,
    this.updatedAt,
  });

  factory AppRemoteConfig.defaults() => const AppRemoteConfig(
    inviteOnly: true,
    paymentsTestOnly: true,
    shoppingFeaturedNames: ['aldi', 'bath & body works'],
    takeoutFeaturedIds: ['taco_bell', 'panda_express'],
    betaBannerText: 'Beta – test payments only. Some features limited.',
    updatedAt: null,
  );

  factory AppRemoteConfig.fromMap(Map<String, dynamic> m) {
    List<String> _toStringList(dynamic v) =>
        (v as List?)
            ?.whereType<dynamic>()
            .map((e) => e.toString())
            .toList(growable: false) ??
        const [];
    final names = _toStringList(m['shoppingFeaturedNames'])
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    // Normalize takeout ids to our internal format e.g.,
    // "Taco Bell" -> "taco_bell", "panda-express" -> "panda_express".
    final ids = _toStringList(m['takeoutFeaturedIds'])
        .map((e) => e.toLowerCase().trim().replaceAll(RegExp(r"[\s\-]+"), "_"))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return AppRemoteConfig(
      inviteOnly: m['inviteOnly'] == true,
      paymentsTestOnly: m['paymentsTestOnly'] != false,
      shoppingFeaturedNames: names.isEmpty ? ['aldi', 'bath & body works'] : names,
      takeoutFeaturedIds: ids.isEmpty ? ['taco_bell'] : ids,
      betaBannerText: (m['betaBannerText'] as String?)?.trim(),
      updatedAt: m['updatedAt'] as Timestamp?,
    );
  }
}

/// Simple singleton service to read/stream the config document at config/app.
class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  static const String _collection = 'config';
  static const String _docId = 'app';

  AppRemoteConfig _cache = AppRemoteConfig.defaults();
  AppRemoteConfig get current => _cache;

  final StreamController<AppRemoteConfig> _controller =
      StreamController.broadcast();
  Stream<AppRemoteConfig> get stream async* {
    yield _cache;
    yield* _controller.stream;
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  /// Begin listening to the Firestore config doc. Safe to call multiple times.
  void ensureListening() {
    _sub ??= FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            if (data == null) {
              _cache = AppRemoteConfig.defaults();
            } else {
              _cache = AppRemoteConfig.fromMap(data);
            }
            _controller.add(_cache);
          },
          onError: (_) {
            // Keep defaults on errors
            _controller.add(_cache);
          },
        );
  }

  /// Fetch the latest config once (without keeping a subscription).
  Future<AppRemoteConfig> fetchOnce() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();
      final data = doc.data();
      _cache = data == null
          ? AppRemoteConfig.defaults()
          : AppRemoteConfig.fromMap(data);
      return _cache;
    } catch (_) {
      return _cache;
    }
  }
}
