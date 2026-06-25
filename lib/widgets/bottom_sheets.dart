import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/additive_info.dart';

class AdditiveSheet extends StatelessWidget {
  final AdditiveInfo info;
  const AdditiveSheet({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    Color riskColor; String riskLabel;
    switch (info.risk) {
      case AdditiveRisk.safe:
        riskColor = colorSuccess; riskLabel = 'Generally regarded as safe'; break;
      case AdditiveRisk.moderate:
        riskColor = colorWarning; riskLabel = 'Some controversy'; break;
      case AdditiveRisk.concern:
        riskColor = colorDanger;  riskLabel = 'Often avoided by consumers'; break;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: backgroundSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusLg)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: borderSecondary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: backgroundSecondary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderSecondary, width: 0.5),
                    ),
                    child: Text(info.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(info.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(info.function, style: const TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(borderRadiusMd),
                    border: Border.all(color: riskColor.withAlpha(40), width: 0.5),
                  ),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(riskLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: riskColor)),
                  ]),
                ),
                const SizedBox(height: 16),
                _sheetSection('What it is', info.what),
                _sheetSection('Why it\'s used', info.why),
                _sheetSection('Safety information', info.safety),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sheetSection(String label, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: textSecondary, letterSpacing: 0.4)),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(fontSize: 13, color: textPrimary, height: 1.6)),
      const SizedBox(height: 14),
    ],
  );
}

class IngredientSheet extends StatefulWidget {
  final String ingredient;
  const IngredientSheet({super.key, required this.ingredient});
  @override
  State<IngredientSheet> createState() => _IngredientSheetState();
}

class _IngredientSheetState extends State<IngredientSheet> {
  static const Map<String, Map<String, String>> _kb = {
    'sugar': {'what': 'Sucrose extracted from sugar cane or beet.', 'why': 'Sweetener and preservative.', 'note': 'Excess intake linked to obesity, type 2 diabetes, and dental decay.'},
    'salt': {'what': 'Sodium chloride (NaCl).', 'why': 'Flavour enhancer and preservative.', 'note': 'WHO recommends under 5 g/day. High intake raises blood pressure.'},
    'water': {'what': 'H₂O — universal solvent.', 'why': 'Diluent, carrier for other ingredients.', 'note': 'Safe.'},
    'palm oil': {'what': 'Vegetable oil from the fruit of the oil palm.', 'why': 'Cheap, shelf-stable fat with semi-solid texture at room temperature.', 'note': 'High in saturated fat. Environmental concerns regarding deforestation.'},
    'cocoa': {'what': 'Ground cacao beans.', 'why': 'Flavour and colour in chocolate products.', 'note': 'Rich in flavanols with antioxidant properties.'},
    'flour': {'what': 'Ground cereal grain, usually wheat.', 'why': 'Structure-forming base in baked goods.', 'note': 'Refined white flour lacks fibre; wholegrain is nutritionally superior.'},
    'skimmed milk powder': {'what': 'Dehydrated skim milk.', 'why': 'Adds protein, calcium, and dairy flavour.', 'note': 'Good source of calcium and protein.'},
    'whey powder': {'what': 'By-product of cheese making.', 'why': 'Adds protein content.', 'note': 'High-quality complete protein. May cause issues for lactose-intolerant individuals.'},
    'lecithin': {'what': 'Phospholipid typically from soy or sunflower.', 'why': 'Emulsifier — keeps water and fat mixed.', 'note': 'Generally regarded as safe.'},
    'vanilla': {'what': 'Extract or flavour from vanilla beans.', 'why': 'Flavouring.', 'note': 'Natural vanilla is safe; synthetic vanillin is also considered safe.'},
  };

  String? _what;
  String? _why;
  String? _note;

  @override
  void initState() {
    super.initState();
    final key = widget.ingredient.toLowerCase().trim();
    final entry = _kb.entries
        .firstWhere((e) => key.contains(e.key), orElse: () => const MapEntry('', {}));
    if (entry.value.isNotEmpty) {
      _what = entry.value['what'];
      _why  = entry.value['why'];
      _note = entry.value['note'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: borderSecondary, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(widget.ingredient,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 12),
          if (_what != null) ...[
            _row('What it is', _what!),
            _row('Why it\'s used', _why!),
            _row('Notes', _note!),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: backgroundSecondary,
                borderRadius: BorderRadius.circular(borderRadiusMd),
                border: Border.all(color: borderSecondary, width: 0.5),
              ),
              child: const Text(
                'This ingredient is not in our database yet.\n'
                    'Open Food Facts community data may have more details.',
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: textSecondary, letterSpacing: 0.4)),
      const SizedBox(height: 3),
      Text(body, style: const TextStyle(fontSize: 13, color: textPrimary, height: 1.5)),
    ]),
  );
}
