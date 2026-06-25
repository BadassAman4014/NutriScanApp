import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_summary.dart';

/// Lightweight local storage for scan history and favorites.
/// Uses shared_preferences to persist data as JSON strings.
class StorageService {
  static const String _historyKey = 'nutriscan_history';
  static const String _favoritesKey = 'nutriscan_favorites';

  static SharedPreferences? _prefs;

  /// Initialize the storage service. Call once at app startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── History ──────────────────────────────────────────────────────────────

  static List<ProductSummary> loadHistory() {
    final json = _prefs?.getString(_historyKey);
    if (json == null || json.isEmpty) return [];
    return ProductSummary.decodeList(json);
  }

  static Future<void> saveHistory(List<ProductSummary> history) async {
    await _prefs?.setString(_historyKey, ProductSummary.encodeList(history));
  }

  // ── Favorites ────────────────────────────────────────────────────────────

  static List<ProductSummary> loadFavorites() {
    final json = _prefs?.getString(_favoritesKey);
    if (json == null || json.isEmpty) return [];
    return ProductSummary.decodeList(json);
  }

  static Future<void> saveFavorites(List<ProductSummary> favorites) async {
    await _prefs?.setString(_favoritesKey, ProductSummary.encodeList(favorites));
  }
}
