import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../models/product_summary.dart';
import '../models/additive_info.dart';
import '../utils/helpers.dart';
import '../widgets/alternatives_section.dart';
import '../widgets/bottom_sheets.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productRaw;
  final bool isFavorite;
  final Function(ProductSummary) onToggleFavorite;
  final Function(ProductSummary) addToHistory;
  final Future<List<Map<String, dynamic>>> Function(String, {int count}) searchProducts;
  final ScrollController? scrollController;

  const ProductDetailScreen({
    super.key,
    required this.productRaw,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.addToHistory,
    required this.searchProducts,
    this.scrollController,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Map<String, dynamic> _currentProduct;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.productRaw;
    _isFavorite = widget.isFavorite;
  }

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

  @override
  Widget build(BuildContext context) {
    final s = _summarise(_currentProduct);
    final nutriments = _currentProduct['nutriments'] as Map<String, dynamic>? ?? {};

    final name       = s.name;
    final brand      = s.brand;
    final imageUrl   = s.imageUrl;
    final nutriScore = s.nutriScore;
    final barcode    = s.barcode;
    final qScore     = s.qualityScore;

    final energyKj = parseNum(nutriments['energy-kj_100g']);
    final carbs    = parseNum(nutriments['carbohydrates_100g']);
    final sugar    = parseNum(nutriments['sugars_100g']);
    final fat      = parseNum(nutriments['fat_100g']);
    final satFat   = parseNum(nutriments['saturated-fat_100g']);
    final protein  = parseNum(nutriments['proteins_100g']);
    final saltG    = parseNum(nutriments['salt_100g']);
    final fiber    = parseNum(nutriments['fiber_100g']);

    final ingredientsText = safeStr(_currentProduct['ingredients_text']);
    final rawAllergens = _currentProduct['allergens_tags'] as List<dynamic>? ?? [];
    final allergens = rawAllergens
        .map((a) => safeStr(a).replaceFirst('en:', '').replaceAll('-', ' '))
        .where((a) => a.isNotEmpty)
        .toList();

    final additiveTags = (_currentProduct['additives_tags'] as List<dynamic>? ?? [])
        .map((a) => safeStr(a).replaceFirst('en:', '').toLowerCase())
        .toList();

    final poorReasons = whyRatedPoorly(_currentProduct);
    final goodReasons = whatsDoneWell(_currentProduct);

    final List<String> ingredientTokens = ingredientsText.isEmpty
        ? []
        : ingredientsText.split(RegExp(r'[,;]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLg)),
      ),
      child: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact Header: 40% Image, 60% Info
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 40% Image
                            Expanded(
                              flex: 4,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(borderRadiusMd),
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            height: 140,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => _imagePlaceholder(140),
                                            errorWidget: (_, __, ___) => _imagePlaceholder(140),
                                          )
                                        : _imagePlaceholder(140),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _isFavorite = !_isFavorite);
                                        widget.onToggleFavorite(s);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(220),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: _isFavorite ? colorDanger : textSecondary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 60% Basic Info
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2),
                                  ),
                                  if (brand.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      brand,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  // Attention Grabber: Quality Score
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: qualityColor(qScore).withAlpha(15),
                                        borderRadius: BorderRadius.circular(borderRadiusMd),
                                        border: Border.all(color: qualityColor(qScore).withAlpha(40), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$qScore',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: qualityColor(qScore)),
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('QUALITY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: textSecondary, letterSpacing: 0.5)),
                                              Text(
                                                qScore >= 75 ? 'EXCELLENT' : qScore >= 55 ? 'GOOD' : 'POOR',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: qualityColor(qScore)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (nutriScore.isNotEmpty && nutriScore != 'UNKNOWN')
                                    _pill('Nutri-Score $nutriScore', nutriColor(nutriScore), Colors.white),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _sectionHeader('Detailed Breakdown'),
                        _buildQualityScoreCard(qScore, poorReasons, goodReasons),
                        const SizedBox(height: 20),
                        _sectionHeader('Nutrition per 100 g'),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.75,
                          children: [
                            _nutriCard('Carbs',   '${carbs.round()} g',           Icons.grain),
                            _nutriCard('Fat',     '${fat.round()} g',             Icons.opacity_rounded),
                            _nutriCard('Protein', '${protein.round()} g',         Icons.fitness_center_rounded),
                            _nutriCard('Salt',    '${(saltG * 1000).round()} mg', Icons.water_drop_outlined),
                            _nutriCard('Sugars',  '${sugar.round()} g',           Icons.cake_outlined),
                            _nutriCard('Sat. Fat','${satFat.toStringAsFixed(1)} g', Icons.lunch_dining_outlined),
                            _nutriCard('Fibre',   '${fiber.toStringAsFixed(1)} g', Icons.grass_outlined),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (additiveTags.isNotEmpty) ...[
                          _sectionHeader('Additive Risk Summary'),
                          _buildAdditiveRisk(context, additiveTags),
                          const SizedBox(height: 20),
                        ],
                        if (ingredientTokens.isNotEmpty) ...[
                          _sectionHeader('Ingredients (tap to explain)'),
                          const SizedBox(height: 8),
                          _buildTappableIngredients(context, ingredientTokens),
                          const SizedBox(height: 20),
                        ],
                        if (allergens.isNotEmpty) ...[
                          _sectionHeader('Allergens'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: allergens.map((a) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorDanger.withAlpha(15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderDanger, width: 0.5),
                              ),
                              child: Text(a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDanger)),
                            )).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _sectionHeader('Healthier Alternatives'),
                        AlternativesSection(
                          productName: name,
                          nutriScore: nutriScore,
                          categories: safeStr(_currentProduct['categories']),
                          categoryTags: (_currentProduct['categories_tags'] as List<dynamic>? ?? []).cast<String>(),
                          currentBarcode: barcode,
                          currentQualityScore: qScore,
                          searchProducts: widget.searchProducts,
                          onProductTap: (altP) {
                            final alt = _summarise(altP);
                            widget.addToHistory(alt);
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
                                  productRaw: altP,
                                  isFavorite: false,
                                  onToggleFavorite: widget.onToggleFavorite,
                                  addToHistory: widget.addToHistory,
                                  searchProducts: widget.searchProducts,
                                  scrollController: scrollController,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (barcode.isNotEmpty)
                          Center(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.barcode_reader, size: 13, color: textSecondary),
                              const SizedBox(width: 5),
                              Text(barcode, style: const TextStyle(fontSize: 12, color: textSecondary, letterSpacing: 1.8)),
                            ]),
                          ),
                        const SizedBox(height: 24),
                        Center(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/NutriScanLogo.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityScoreCard(int score, List<String> poor, List<String> good) {
    final c = qualityColor(score);
    final label = score >= 75 ? 'Excellent' : score >= 55 ? 'Average' : 'Poor';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundSecondary,
        borderRadius: BorderRadius.circular(borderRadiusLg),
        border: Border.all(color: borderSecondary, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$score', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: c)),
          const Text('/100', style: TextStyle(fontSize: 16, color: textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
          ),
        ]),
        if (poor.isNotEmpty || good.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(color: borderSecondary, thickness: 0.5, height: 1),
          const SizedBox(height: 10),
          if (poor.isNotEmpty) ...[
            const Text('Why it scores lower',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            ...poor.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.remove_circle_outline, size: 13, color: colorDanger),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: const TextStyle(fontSize: 12, color: textDanger, height: 1.4, fontWeight: FontWeight.w500))),
              ]),
            )),
          ],
          if (good.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('What it does well',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 6),
            ...good.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.check_circle_outline, size: 13, color: colorSuccess),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: const TextStyle(fontSize: 12, color: colorSuccess, height: 1.4, fontWeight: FontWeight.w500))),
              ]),
            )),
          ],
        ],
      ]),
    );
  }

  Widget _buildAdditiveRisk(BuildContext context, List<String> tags) {
    final List<AdditiveInfo> found = [];
    int unknownCount = 0;

    for (final t in tags) {
      final a = lookupAdditive(t);
      if (a != null) {
        if (!found.any((f) => f.code == a.code)) found.add(a);
      } else {
        unknownCount++;
      }
    }

    if (found.isEmpty && unknownCount == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundSecondary,
          borderRadius: BorderRadius.circular(borderRadiusMd),
          border: Border.all(color: borderSecondary, width: 0.5),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_outline, size: 15, color: colorSuccess),
          SizedBox(width: 8),
          Text('No notable additives detected.', style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundSecondary,
        borderRadius: BorderRadius.circular(borderRadiusMd),
        border: Border.all(color: borderSecondary, width: 0.5),
      ),
      child: Column(
        children: [
          ...found.map((a) {
            Color dot; String label;
            switch (a.risk) {
              case AdditiveRisk.safe:
                dot = colorSuccess; label = 'Generally safe'; break;
              case AdditiveRisk.moderate:
                dot = colorWarning; label = 'Some controversy'; break;
              case AdditiveRisk.concern:
                dot = colorDanger; label = 'Often avoided'; break;
            }
            return GestureDetector(
              onTap: () => _showAdditiveSheet(context, a),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderSecondary, width: 0.5)),
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a.code} — ${a.name}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    Text(label,
                        style: TextStyle(fontSize: 11, color: dot, fontWeight: FontWeight.w500)),
                  ])),
                  const Icon(Icons.chevron_right, size: 16, color: textSecondary),
                ]),
              ),
            );
          }),
          if (unknownCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: textSecondary, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text('$unknownCount additional additive${unknownCount == 1 ? '' : 's'} (not in database)',
                    style: const TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
              ]),
            ),
        ],
      ),
    );
  }

  void _showAdditiveSheet(BuildContext context, AdditiveInfo a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLg)),
      ),
      builder: (_) => AdditiveSheet(info: a),
    );
  }

  Widget _buildTappableIngredients(BuildContext context, List<String> tokens) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundSecondary,
        borderRadius: BorderRadius.circular(borderRadiusMd),
        border: Border.all(color: borderSecondary, width: 0.5),
      ),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: tokens.map((token) {
          final isECode = RegExp(r'^[eE]\d{3}').hasMatch(token.trim().replaceAll(' ', ''));
          final info = lookupAdditive(token.trim().replaceAll(' ', '').toLowerCase());
          return GestureDetector(
            onTap: () {
              if (info != null) {
                _showAdditiveSheet(context, info);
              } else {
                _showIngredientSheet(context, token.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: info != null
                    ? _additiveRiskColor(info.risk).withAlpha(15)
                    : backgroundTertiary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: info != null
                      ? _additiveRiskColor(info.risk).withAlpha(60)
                      : borderSecondary,
                  width: 0.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(token.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: info != null ? textPrimary : textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                if (info != null || isECode) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 11, color: textSecondary),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _additiveRiskColor(AdditiveRisk r) {
    switch (r) {
      case AdditiveRisk.safe:     return colorSuccess;
      case AdditiveRisk.moderate: return colorWarning;
      case AdditiveRisk.concern:  return colorDanger;
    }
  }

  void _showIngredientSheet(BuildContext context, String ingredient) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLg)),
      ),
      builder: (_) => IngredientSheet(ingredient: ingredient),
    );
  }

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: textSecondary, letterSpacing: 0.5,
    )),
  );

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
  );

  Widget _nutriCard(String label, String value, IconData icon) => Card(
    color: backgroundSecondary,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusLg),
      side: const BorderSide(color: borderSecondary, width: 0.5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600)),
          ]),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
        ],
      ),
    ),
  );

  Widget _imagePlaceholder(double h) => Container(
    height: h, width: double.infinity,
    decoration: BoxDecoration(
      color: backgroundSecondary,
      borderRadius: BorderRadius.circular(borderRadiusLg),
      border: Border.all(color: borderSecondary, width: 0.5),
    ),
    child: const Center(child: Icon(Icons.no_food, size: 36, color: textSecondary)),
  );
}
