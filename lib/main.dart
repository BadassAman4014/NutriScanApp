import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

import 'core/theme.dart';
import 'models/product_summary.dart';
import 'services/storage_service.dart';
import 'utils/helpers.dart';
import 'widgets/ui_components.dart';
import 'widgets/scanner_widget.dart';
import 'screens/product_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  NAV ENUM
// ═══════════════════════════════════════════════════════════════════════════════
enum NavTab { history, scan, favorites }

// ═══════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const FoodFactsRoot());
}

class FoodFactsRoot extends StatelessWidget {
  const FoodFactsRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutri Scan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: backgroundPrimary,
        colorScheme: const ColorScheme.light(
          surface: backgroundSecondary,
          primary: colorInfo,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundPrimary,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: backgroundSecondary,
          selectedItemColor: colorInfo,
          unselectedItemColor: textSecondary,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        ),
        cardTheme: CardThemeData(
          color: backgroundSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLg),
            side: const BorderSide(color: borderSecondary, width: 0.5),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: backgroundTertiary,
          labelStyle: const TextStyle(fontSize: 12, color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const FoodFactsApp(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ROOT APP STATE
// ═══════════════════════════════════════════════════════════════════════════════
class FoodFactsApp extends StatefulWidget {
  const FoodFactsApp({super.key});
  @override
  State<FoodFactsApp> createState() => _FoodFactsAppState();
}

class _FoodFactsAppState extends State<FoodFactsApp> {
  // ── Opening Splash ────────────────────────────────────────────────────────
  bool _isSplashActive = true;

  @override
  void initState() {
    super.initState();
    _loadPersistedData();
    // Splash duration
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _isSplashActive = false);
    });
  }

  void _loadPersistedData() {
    final savedHistory = StorageService.loadHistory();
    final savedFavorites = StorageService.loadFavorites();
    if (savedHistory.isNotEmpty || savedFavorites.isNotEmpty) {
      setState(() {
        _history.addAll(savedHistory);
        _favorites.addAll(savedFavorites);
      });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  NavTab _tab = NavTab.scan;

  // ── Data ───────────────────────────────────────────────────────────────────
  final List<ProductSummary> _history   = [];
  final List<ProductSummary> _favorites = [];

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String? _searchError;
  bool _isLoading = false;
  String? _loadingMessage;

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setLoading(bool v, [String msg = 'Fetching product data…']) =>
      setState(() { _isLoading = v; _loadingMessage = msg; });

  ProductSummary _summarise(Map<String, dynamic> p) => ProductSummary(
    barcode:      safeStr(p['code']),
    name:         safeStr(p['product_name'],
        safeStr(p['product_name_en'], 'Unknown Product')),
    brand:        safeStr(p['brands']),
    imageUrl:     safeStr(p['image_url']),
    nutriScore:   safeStr(p['nutrition_grades']).toUpperCase(),
    qualityScore: computeQualityScore(p),
    scannedAt:    DateTime.now(),
    raw:          p,
  );

  void _addToHistory(ProductSummary s) {
    _history.removeWhere((h) => h.barcode == s.barcode);
    _history.insert(0, s);
    if (_history.length > 50) _history.removeLast();
    StorageService.saveHistory(_history);
  }

  bool _isFavorite(String barcode) => _favorites.any((f) => f.barcode == barcode);

  void _toggleFavorite(ProductSummary s) {
    setState(() {
      if (_isFavorite(s.barcode)) {
        _favorites.removeWhere((f) => f.barcode == s.barcode);
      } else {
        _favorites.insert(0, s);
      }
    });
    StorageService.saveFavorites(_favorites);
  }

  void _openProduct(Map<String, dynamic> p) {
    final s = _summarise(p);
    _addToHistory(s);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.25,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ProductDetailScreen(
          productRaw: p,
          isFavorite: _isFavorite(s.barcode),
          onToggleFavorite: _toggleFavorite,
          addToHistory: _addToHistory,
          searchProducts: _searchProducts,
          scrollController: scrollController,
        ),
      ),
    );
  }

  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetchByBarcode(String barcode) async {
    _setLoading(true, 'Looking up barcode…');
    try {
      final cleanBarcode = barcode.trim();
      
      // Helper to fetch from a specific base URL
      Future<Map<String, dynamic>?> fetchFrom(String base) async {
        try {
          final res = await http.get(
            Uri.parse('$base/api/v2/product/$cleanBarcode.json'),
            headers: {'User-Agent': 'NutriScan - Android - Version 1.0'},
          ).timeout(const Duration(seconds: 10));
          
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            if (data['status'] == 'success' || data['status'] == 1) {
              return data['product'] as Map<String, dynamic>;
            }
          }
        } catch (_) {}
        return null;
      }

      // 1. Try Food database
      Map<String, dynamic>? product = await fetchFrom('https://world.openfoodfacts.org');
      
      // 2. Try Beauty database if not found
      if (product == null) {
        _setLoading(true, 'Checking beauty database…');
        product = await fetchFrom('https://world.openbeautyfacts.org');
      }

      // 3. Try Pet Food database if still not found
      if (product == null) {
        _setLoading(true, 'Checking pet food database…');
        product = await fetchFrom('https://world.openpetfoodfacts.org');
      }

      if (product != null) {
        _openProduct(product);
      } else {
        _showSnack('Product not found in any database (Barcode: $cleanBarcode).');
      }
    } catch (e) {
      _showSnack('Search failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> _searchProducts(String query, {int count = 5}) async {
    try {
      String url;
      if (query.contains('=')) {
        url = 'https://world.openfoodfacts.org/cgi/search.pl?$query&json=1&page_size=$count';
      } else {
        url = 'https://world.openfoodfacts.org/cgi/search.pl'
            '?search_terms=${Uri.encodeComponent(query)}&json=1&page_size=$count';
      }
      
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'NutriScan - Android - Version 1.0'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['products'] as List<dynamic>? ?? [];
        return raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _searchError = null; });
    _setLoading(true, 'Searching…');
    final results = await _searchProducts(query, count: 1);
    _setLoading(false);
    if (results.isNotEmpty) {
      _openProduct(results.first);
    } else {
      setState(() { _searchError = 'No products found for "$query".'; });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: textPrimary, fontSize: 13)),
        backgroundColor: backgroundSecondary,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMd),
          side: const BorderSide(color: borderSecondary, width: 0.5),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD ROOT
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isSplashActive) return _buildSplashScreen();

    Widget body;
    switch (_tab) {
      case NavTab.history:   body = _buildHistoryTab();   break;
      case NavTab.scan:      body = _buildScanTab();       break;
      case NavTab.favorites: body = _buildFavoritesTab(); break;
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundPrimary,
          body: body,
          bottomNavigationBar: _buildBottomNav(),
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildSplashScreen() {
    final logoSize = MediaQuery.of(context).size.width * 0.8;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: logoSize,
              height: logoSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/NutriScanLogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'Smart choices, healthy life',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorInfo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: backgroundPrimary,
        border: Border(top: BorderSide(color: borderSecondary, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab.index,
        backgroundColor: backgroundPrimary,
        onTap: (i) => setState(() { _tab = NavTab.values[i]; }),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.crop_free_rounded),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/NutriScanLogo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Smart choices, healthy life',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textSecondary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => safeStr(option['product_name'], 'Unknown'),
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.length < 3) return const Iterable.empty();
                return await _searchProducts(textEditingValue.text, count: 10);
              },
              onSelected: (Map<String, dynamic> selection) {
                _openProduct(selection);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name…',
                    hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
                    filled: true,
                    fillColor: backgroundSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.search, color: textSecondary, size: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(borderRadiusMd),
                      borderSide: const BorderSide(color: borderSecondary, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(borderRadiusMd),
                      borderSide: const BorderSide(color: borderInfo, width: 0.5),
                    ),
                    errorText: _searchError,
                    errorStyle: const TextStyle(color: textDanger, fontSize: 11),
                  ),
                  onSubmitted: (value) {
                    onFieldSubmitted();
                    _doSearch(value);
                  },
                  textInputAction: TextInputAction.search,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    color: backgroundPrimary,
                    borderRadius: BorderRadius.circular(borderRadiusMd),
                    child: Container(
                      width: MediaQuery.of(context).size.width - 40,
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          final name = safeStr(option['product_name'], 'Unknown Product');
                          final brand = safeStr(option['brands']);
                          final img = safeStr(option['image_url']);
                          return ListTile(
                            leading: img.isNotEmpty 
                              ? CachedNetworkImage(
                                  imageUrl: img, width: 30, height: 30, fit: BoxFit.cover,
                                  placeholder: (_, __) => const Icon(Icons.image, size: 20),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
                                )
                              : const Icon(Icons.no_food, size: 20),
                            title: Text(name, style: const TextStyle(color: textPrimary, fontSize: 13)),
                            subtitle: brand.isNotEmpty ? Text(brand, style: const TextStyle(color: textSecondary, fontSize: 11)) : null,
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ScannerWidget(
              height: 200, // Reduced from 220 to avoid overflow on small screens
              onDetected: (barcode) => _fetchByBarcode(barcode),
            ),
          ),

          // 2. Bottom Section (Recent Scans) - Scrollable
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text('Recent Scans', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _tab = NavTab.history),
                          child: const Text('See all', style: TextStyle(fontSize: 12, color: colorInfo)),
                        ),
                    ],
                  ),
                ),
                if (_history.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, color: textSecondary, size: 32),
                          SizedBox(height: 8),
                          Text('No scans yet', style: TextStyle(color: textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: min(_history.length, 10),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _productListTile(_history[i]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/NutriScanLogo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Scan History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
          ),
          if (_history.isEmpty)
            const Expanded(child: EmptyState(
              icon: Icons.history_rounded,
              label: 'No scans yet',
              sub: 'Products you scan or search will appear here.',
            ))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _productListTile(_history[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/NutriScanLogo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('My Favorites',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
          ),
          if (_favorites.isEmpty)
            const Expanded(child: EmptyState(
              icon: Icons.favorite_border_rounded,
              label: 'No favorites yet',
              sub: 'Tap the heart on any product to save it here.',
            ))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _favorites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _productListTile(_favorites[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _productListTile(ProductSummary s) {
    return GestureDetector(
      onTap: () => _openProduct(s.raw),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundSecondary,
          borderRadius: BorderRadius.circular(borderRadiusMd),
          border: Border.all(color: borderSecondary, width: 0.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: s.imageUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: s.imageUrl,
              width: 50, height: 50, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 50, height: 50,
                color: backgroundTertiary,
                child: const Icon(Icons.image_outlined, size: 22, color: textSecondary),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 50, height: 50,
                color: backgroundTertiary,
                child: const Icon(Icons.broken_image_outlined, size: 20, color: textSecondary),
              ),
            )
                : Container(
              width: 50, height: 50,
              color: backgroundTertiary,
              child: const Icon(Icons.no_food, size: 22, color: textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
              if (s.brand.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(s.brand, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: textSecondary)),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (s.nutriScore.isNotEmpty && s.nutriScore != 'UNKNOWN')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: nutriColor(s.nutriScore),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('NS ${s.nutriScore}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: qualityColor(s.qualityScore).withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: qualityColor(s.qualityScore), width: 0.5),
                    ),
                    child: Text('Score ${s.qualityScore}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                            color: qualityColor(s.qualityScore))),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _isFavorite(s.barcode) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite(s.barcode) ? colorDanger : textSecondary,
              size: 20,
            ),
            onPressed: () => _toggleFavorite(s),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ]),
      ),
    );
  }

  Widget _buildLoadingOverlay() => Positioned.fill(
    child: Container(
      color: Colors.white.withAlpha(180), // More transparent to see the context
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
          decoration: BoxDecoration(
            color: backgroundSecondary,
            borderRadius: BorderRadius.circular(borderRadiusLg),
            border: Border.all(color: borderSecondary, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: colorInfo.withAlpha(15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: colorInfo, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(_loadingMessage ?? 'Fetching product data…',
                style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
