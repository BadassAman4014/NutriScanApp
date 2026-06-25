import 'dart:convert';

/// Lightweight summary stored in History and Favorites
class ProductSummary {
  final String barcode;
  final String name;
  final String brand;
  final String imageUrl;
  final String nutriScore;
  final int qualityScore;
  final DateTime scannedAt;
  final Map<String, dynamic> raw;

  ProductSummary({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.nutriScore,
    required this.qualityScore,
    required this.scannedAt,
    required this.raw,
  });

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'brand': brand,
    'imageUrl': imageUrl,
    'nutriScore': nutriScore,
    'qualityScore': qualityScore,
    'scannedAt': scannedAt.toIso8601String(),
    'raw': raw,
  };

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Product',
      brand: json['brand'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      nutriScore: json['nutriScore'] as String? ?? '',
      qualityScore: json['qualityScore'] as int? ?? 0,
      scannedAt: DateTime.tryParse(json['scannedAt'] as String? ?? '') ?? DateTime.now(),
      raw: json['raw'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Encode a list of ProductSummary to a JSON string for storage
  static String encodeList(List<ProductSummary> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  /// Decode a JSON string back to a list of ProductSummary
  static List<ProductSummary> decodeList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ProductSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
