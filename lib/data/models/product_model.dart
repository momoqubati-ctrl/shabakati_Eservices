import 'package:intl/intl.dart';

class ProductModel {
  final int id;
  final String sku;
  final String name;
  final String availability;
  final int pricingQuantity;
  final PriceModel sellerPrice;
  final PriceModel sellerBasePrice;
  final PriceModel lineTotal;
  final double? customPriceYer;
  final int stockQuantity;

  ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.availability,
    required this.pricingQuantity,
    required this.sellerPrice,
    required this.sellerBasePrice,
    required this.lineTotal,
    this.customPriceYer,
    this.stockQuantity = 99,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json, {double? customPriceYer, int? stockQuantity}) {
    return ProductModel(
      id: json['id'] as int,
      sku: json['sku'] ?? '',
      name: json['name'] ?? '',
      availability: json['availability'] ?? 'available',
      pricingQuantity: json['pricing_quantity'] ?? 1,
      sellerPrice: PriceModel.fromJson(json['seller_price'] ?? {}),
      sellerBasePrice: PriceModel.fromJson(json['seller_base_price'] ?? {}),
      lineTotal: PriceModel.fromJson(json['line_total'] ?? {}),
      customPriceYer: customPriceYer ?? (json['custom_price_yer'] != null ? (json['custom_price_yer'] as num).toDouble() : null),
      stockQuantity: stockQuantity ?? (json['stock_quantity'] as int? ?? 99),
    );
  }

  ProductModel copyWith({
    double? customPriceYer,
    int? stockQuantity,
  }) {
    return ProductModel(
      id: id,
      sku: sku,
      name: name,
      availability: availability,
      pricingQuantity: pricingQuantity,
      sellerPrice: sellerPrice,
      sellerBasePrice: sellerBasePrice,
      lineTotal: lineTotal,
      customPriceYer: customPriceYer ?? this.customPriceYer,
      stockQuantity: stockQuantity ?? this.stockQuantity,
    );
  }

  bool get isAvailable => availability == 'available' && stockQuantity > 0;

  // احتساب السعر بالريال اليمني مع إضافة هامش 1000 ريال والتقريب لأعلى إلى أقرب ألف
  double getFinalPriceYer({double exchangeRate = 535.0}) {
    if (customPriceYer != null && customPriceYer! > 0) {
      return customPriceYer!;
    }
    // 1. التكلفة من المزود بالريال اليمني
    final costYer = (sellerPrice.amountCents / 100.0) * exchangeRate;
    // 2. إضافة هامش ربح 1000 ريال يمني
    final withMargin = costYer + 1000.0;
    // 3. التقريب لأعلى إلى أقرب ألف (Ceil to next 1000, مثل 1163 تصبح 2000)
    return (withMargin / 1000.0).ceil() * 1000.0;
  }

  String displayPriceYer({double exchangeRate = 535.0}) {
    final yer = getFinalPriceYer(exchangeRate: exchangeRate);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(yer)} ر.ي';
  }

  String get displaySecondaryUsd => '\$${sellerPrice.amount.toStringAsFixed(2)} USD';

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
