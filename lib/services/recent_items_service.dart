import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistence layer for recently viewed product IDs using
/// shared_preferences. Maintains an in-memory LRU list capped at [maxItems].
class RecentItemsService {
  static const String _prefsKey = 'recent_items_v1';
  final int maxItems;
  List<String> _ids = [];
  SharedPreferences? _prefs;

  RecentItemsService({this.maxItems = 20});

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ids = List<String>.from(_prefs?.getStringList(_prefsKey) ?? const []);
  }

  List<String> get ids => List.unmodifiable(_ids);

  Future<void> add(String productId) async {
    // Move to front (most recent first)
    _ids.remove(productId);
    _ids.insert(0, productId);
    if (_ids.length > maxItems) {
      _ids = _ids.sublist(0, maxItems);
    }
    await _prefs?.setStringList(_prefsKey, _ids);
  }

  Future<void> clear() async {
    _ids.clear();
    await _prefs?.remove(_prefsKey);
  }
}
