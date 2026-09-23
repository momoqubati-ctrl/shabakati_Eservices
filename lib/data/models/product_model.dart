class ProductModel {
  final int id;
  final String sku;
  final String name;
  final String availability;
  final int pricingQuantity;
  final PriceModel sellerPrice;
  final PriceModel sellerBasePrice;
  final PriceModel lineTotal;

  ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.availability,
    required this.pricingQuantity,
    required this.sellerPrice,
    required this.sellerBasePrice,
    required this.lineTotal,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int,
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      availability: json['availability'] ?? 'available',
      pricingQuantity: json['pricing_quantity'] ?? 1,
      sellerPrice: PriceModel.fromJson(json['seller_price'] ?? {}),
      sellerBasePrice: PriceModel.fromJson(json['seller_base_price'] ?? {}),
      lineTotal: PriceModel.fromJson(json['line_total'] ?? {}),
    );
  }

  bool get isAvailable => availability == 'available';

  String get category {
    final lower = name.toLowerCase();
    if (lower.contains('gemini') || lower.contains('gpt') || lower.contains('ai') || lower.contains('chat')) {
      return 'الذكاء الاصطناعي';
    } else if (lower.contains('duolingo') || lower.contains('learn') || lower.contains('course')) {
      return 'التعليم واللغات';
    } else if (lower.contains('vpn') || lower.contains('proxy') || lower.contains('shield')) {
      return 'حماية وVPN';
    } else if (lower.contains('netflix') || lower.contains('youtube') || lower.contains('spotify') || lower.contains('shahid')) {
      return 'بث وترفيه';
    } else if (lower.contains('windows') || lower.contains('office') || lower.contains('key') || lower.contains('license')) {
      return 'تراخيص وبرامج';
    }
    return 'خدمات متنوعة';
  }
}

class PriceModel {
  final String currency;
  final int amountCents;

  PriceModel({
    required this.currency,
    required this.amountCents,
  });

  factory PriceModel.fromJson(Map<String, dynamic> json) {
    return PriceModel(
      currency: json['currency'] ?? 'USD',
      amountCents: json['amount_cents'] ?? 0,
    );
  }

  double get amount => amountCents / 100.0;
  String get displayPrice => '\$${amount.toStringAsFixed(2)} $currency';
}
