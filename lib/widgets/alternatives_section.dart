import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../utils/helpers.dart';

/// Intelligent healthier alternatives finder.
/// Uses direct Open Food Facts API calls with nutrition-grade sorting
/// to find genuinely better products in the same category.
class AlternativesSection extends StatefulWidget {
  final String productName;
  final String nutriScore;
  final String categories;
  final List<String> categoryTags;
  final String currentBarcode;
  final int currentQualityScore;
  final Future<List<Map<String, dynamic>>> Function(String query, {int count}) searchProducts;
  final void Function(Map<String, dynamic>) onProductTap;

  const AlternativesSection({
    super.key,
    required this.productName,
    required this.nutriScore,
    required this.categories,
    required this.categoryTags,
    required this.currentBarcode,
    required this.currentQualityScore,
    required this.searchProducts,
    required this.onProductTap,
  });

  @override
  State<AlternativesSection> createState() => _AlternativesSectionState();
}

class _AlternativesSectionState extends State<AlternativesSection> {
  List<_ScoredAlternative> _alts = [];
  bool _loading = false;
  bool _loaded  = false;

  static const _gradeRank = {'a': 0, 'b': 1, 'c': 2, 'd': 3, 'e': 4};

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  // ── Direct API call with nutrition sorting ─────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchFromAPI(String endpoint, {int pageSize = 30}) async {
    try {
      final url = 'https://world.openfoodfacts.org$endpoint';
      final separator = url.contains('?') ? '&' : '?';
      final fullUrl = '$url${separator}json=1&page_size=$pageSize&fields=code,product_name,brands,image_url,nutrition_grades,nova_group,nutriments,categories_tags,ecoscore_grade,additives_tags';
      
      final res = await http.get(
        Uri.parse(fullUrl),
        headers: {'User-Agent': 'NutriScan - Android - Version 1.0'},
      ).timeout(const Duration(seconds: 12));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['products'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('API fetch failed: $e');
    }
    return [];
  }

  // ── Find the best category tags to search ──────────────────────────────────
  List<String> _getUsefulCategoryTags() {
    const tooGeneric = {
      'en:plant-based-foods-and-beverages',
      'en:plant-based-foods',
      'en:beverages',
      'en:groceries',
      'en:snacks',
      'en:food',
      'en:foods',
      'en:drinks',
      'en:sweet-snacks',
      'en:salty-snacks',
      'en:meals',
      'en:dairies',
      'en:cereals-and-potatoes',
      'en:fruits-and-vegetables-based-foods',
      'en:beverages-and-beverages-preparations',
      'en:sweetened-beverages',
      'en:non-alcoholic-beverages',
      'en:carbonated-drinks',
      'en:plant-based-beverages',
    };

    final useful = widget.categoryTags
        .where((tag) => !tooGeneric.contains(tag))
        .toList();
    
    return useful;
  }

  // ── Main loading logic ─────────────────────────────────────────────────────
  Future<void> _loadAlternatives() async {
    setState(() { _loading = true; });

    final Map<String, Map<String, dynamic>> pool = {};
    final usefulTags = _getUsefulCategoryTags();

    // ── Strategy 1: Category browsing API (sorted by popularity) ───────────
    // This is the BEST approach — OpenFoodFacts lets you browse categories directly
    // and it returns popular, well-documented products
    if (usefulTags.isNotEmpty) {
      // Try the most specific tag first
      final bestTag = usefulTags.last;
      final tagSlug = bestTag.replaceFirst('en:', '');
      
      final results = await _fetchFromAPI(
        '/category/$tagSlug.json?sort_by=unique_scans_n',
        pageSize: 50,
      );
      for (final p in results) {
        final code = safeStr(p['code']);
        if (code.isNotEmpty) pool[code] = p;
      }
      
      // If we got very few results, try a broader category
      if (pool.length < 5 && usefulTags.length >= 2) {
        final broaderTag = usefulTags[usefulTags.length - 2];
        final broaderSlug = broaderTag.replaceFirst('en:', '');
        final moreResults = await _fetchFromAPI(
          '/category/$broaderSlug.json?sort_by=unique_scans_n',
          pageSize: 40,
        );
        for (final p in moreResults) {
          final code = safeStr(p['code']);
          if (code.isNotEmpty) pool.putIfAbsent(code, () => p);
        }
      }
    }

    // ── Strategy 2: Search by category text ────────────────────────────────
    if (pool.length < 5 && widget.categories.isNotEmpty) {
      final cats = widget.categories.split(',');
      // Use the most specific (last) category name
      final searchCat = cats.last.trim();
      if (searchCat.isNotEmpty) {
        final results = await _fetchFromAPI(
          '/cgi/search.pl?search_terms=${Uri.encodeComponent(searchCat)}&sort_by=unique_scans_n',
          pageSize: 30,
        );
        for (final p in results) {
          final code = safeStr(p['code']);
          if (code.isNotEmpty) pool.putIfAbsent(code, () => p);
        }
      }
    }

    // ── Strategy 3: Search by product name keywords ────────────────────────
    if (pool.length < 5) {
      // Extract meaningful words (skip short words and common terms)
      const skipWords = {'the', 'and', 'with', 'for', 'from', 'organic', 'natural', 'original', 'classic'};
      final words = widget.productName
          .toLowerCase()
          .split(RegExp(r'[\s,\-/&()+]+'))
          .where((w) => w.length > 2 && !skipWords.contains(w))
          .take(3)
          .toList();
      
      if (words.isNotEmpty) {
        final query = words.join(' ');
        final results = await _fetchFromAPI(
          '/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}&sort_by=unique_scans_n',
          pageSize: 25,
        );
        for (final p in results) {
          final code = safeStr(p['code']);
          if (code.isNotEmpty) pool.putIfAbsent(code, () => p);
        }
      }
    }

    // ── Score and rank all candidates ──────────────────────────────────────
    final currentGrade = widget.nutriScore.toLowerCase();
    final currentRank = _gradeRank[currentGrade] ?? 99;
    final currentQuality = widget.currentQualityScore;

    final List<_ScoredAlternative> scored = [];

    for (final entry in pool.entries) {
      final p = entry.value;
      final code = entry.key;
      final name = safeStr(p['product_name']);

      // Skip current product, unnamed products, and near-duplicates
      if (code == widget.currentBarcode) continue;
      if (name.isEmpty || name.length < 2) continue;
      if (name.toLowerCase() == widget.productName.toLowerCase()) continue;

      final grade = safeStr(p['nutrition_grades']).toLowerCase();
      final rank = _gradeRank[grade] ?? 99;
      final quality = computeQualityScore(p);

      // Determine the relationship and label
      String label;
      int priority; // lower = better, used for sorting

      if (grade.isNotEmpty && currentGrade.isNotEmpty && rank < currentRank) {
        // Strictly better Nutri-Score
        label = 'Better Nutri-Score (${grade.toUpperCase()})';
        priority = 0 + rank; // A=0, B=1, etc.
      } else if (quality > currentQuality + 5) {
        // Meaningfully better quality score
        label = 'Higher quality (+${quality - currentQuality} pts)';
        priority = 10 + (100 - quality);
      } else if (grade.isNotEmpty && (rank <= 1)) {
        // Top-rated product (A or B) regardless of current
        label = 'Top rated (${grade.toUpperCase()})';
        priority = 20 + rank;
      } else if (quality >= 60) {
        // Decent quality product worth showing
        label = 'Good option (Score $quality)';
        priority = 30 + (100 - quality);
      } else if (grade.isNotEmpty && rank <= 2) {
        // Rated A, B, or C
        label = 'Rated ${grade.toUpperCase()}';
        priority = 40 + rank;
      } else if (quality >= 45) {
        // Acceptable quality
        label = 'Alternative (Score $quality)';
        priority = 50 + (100 - quality);
      } else {
        // Skip genuinely poor products
        continue;
      }

      scored.add(_ScoredAlternative(
        product: p,
        label: label,
        priority: priority,
        grade: grade,
        quality: quality,
      ));
    }

    // Sort by priority (best alternatives first)
    scored.sort((a, b) {
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);
      return b.quality.compareTo(a.quality);
    });

    if (mounted) {
      setState(() {
        _alts = scored.take(12).toList();
        _loading = false;
        _loaded = true;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: backgroundSecondary,
          borderRadius: BorderRadius.circular(borderRadiusMd),
          border: Border.all(color: borderSecondary, width: 0.5),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorInfo),
            ),
            SizedBox(height: 10),
            Text('Finding healthier options…',
                style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_loaded && _alts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundTertiary,
          borderRadius: BorderRadius.circular(borderRadiusMd),
          border: Border.all(color: borderSecondary, width: 0.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not find alternatives for this product. Try scanning a different item.',
                style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${_alts.length} alternative${_alts.length == 1 ? '' : 's'} found',
            style: const TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _alts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _buildAltCard(_alts[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAltCard(_ScoredAlternative alt) {
    final p = alt.product;
    final ns = alt.grade.toUpperCase();
    final name = safeStr(p['product_name'], 'Unknown Product');
    final brand = safeStr(p['brands']);
    final img = safeStr(p['image_url']);

    // Determine label color based on priority
    Color labelColor;
    if (alt.priority < 10) {
      labelColor = colorSuccess; // Strictly better
    } else if (alt.priority < 30) {
      labelColor = const Color(0xFF00897B); // Top rated / higher quality
    } else {
      labelColor = colorInfo; // Good option
    }

    return GestureDetector(
      onTap: () => widget.onProductTap(p),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundSecondary,
          borderRadius: BorderRadius.circular(borderRadiusLg),
          border: Border.all(color: borderSecondary, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadiusMd),
                child: img.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: img, width: 64, height: 64, fit: BoxFit.cover,
                        placeholder: (_, __) => _imgPlaceholder(),
                        errorWidget: (_, __, ___) => _imgPlaceholder(),
                      )
                    : _imgPlaceholder(),
              ),
            ),
            const SizedBox(height: 6),
            // Why-better label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: labelColor.withAlpha(15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: labelColor.withAlpha(50), width: 0.5),
              ),
              child: Text(
                alt.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: labelColor),
              ),
            ),
            const Spacer(),
            // Product name
            Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2)),
            if (brand.isNotEmpty)
              Text(brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            // Score badges
            Row(
              children: [
                if (ns.isNotEmpty && _gradeRank.containsKey(ns.toLowerCase()))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: nutriColor(ns), borderRadius: BorderRadius.circular(4)),
                      child: Text(ns, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                Text('Score ${alt.quality}',
                  style: TextStyle(fontSize: 10, color: qualityColor(alt.quality), fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 64, height: 64, color: backgroundTertiary,
    child: const Icon(Icons.fastfood_outlined, size: 22, color: textSecondary),
  );
}

class _ScoredAlternative {
  final Map<String, dynamic> product;
  final String label;
  final int priority;
  final String grade;
  final int quality;

  const _ScoredAlternative({
    required this.product,
    required this.label,
    required this.priority,
    required this.grade,
    required this.quality,
  });
}
