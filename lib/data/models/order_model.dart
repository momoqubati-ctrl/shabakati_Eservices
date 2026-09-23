class OrderModel {
  final int? id;
  final String externalOrderId;
  final int? sellerOrderId;
  final String status;
  final String fulfillmentStatus;
  final int totalCents;
  final String currency;
  final String? deliveredKey;
  final String? deliveredUrl;
  final DateTime createdAt;
  final String? telegramUser;

  OrderModel({
    this.id,
    required this.externalOrderId,
    this.sellerOrderId,
    required this.status,
    required this.fulfillmentStatus,
    required this.totalCents,
    required this.currency,
    this.deliveredKey,
    this.deliveredUrl,
    required this.createdAt,
    this.telegramUser,
  });

  bool get isReady => fulfillmentStatus == 'ready' || status == 'completed';
  bool get isProcessing => fulfillmentStatus == 'processing' || status == 'paid';
  bool get isFailed => fulfillmentStatus == 'failed' || status == 'cancelled';

  double get totalAmount => totalCents / 100.0;
  String get displayTotal => '\$${totalAmount.toStringAsFixed(2)} $currency';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? key;
    String? url;
    if (json['delivered_assets'] != null) {
      final assets = json['delivered_assets'];
      if (assets is List && assets.isNotEmpty) {
        final first = assets.first;
        if (first is Map) {
          key = first['value']?.toString();
          url = first['url']?.toString();
        }
      } else if (assets is Map) {
        key = assets['key'] ?? assets['value'];
        url = assets['url'];
      }
    }

    return OrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      externalOrderId: json['external_order_id'] ?? '',
      sellerOrderId: json['seller_order_id'] is int
          ? json['seller_order_id']
          : int.tryParse(json['seller_order_id']?.toString() ?? ''),
      status: json['status'] ?? 'paid',
      fulfillmentStatus: json['fulfillment_status'] ?? 'processing',
      totalCents: json['total_cents'] is int
          ? json['total_cents']
          : (json['total'] is Map ? (json['total']['amount_cents'] ?? 0) : 0),
      currency: json['currency'] ??
          (json['total'] is Map ? (json['total']['currency'] ?? 'USD') : 'USD'),
      deliveredKey: key,
      deliveredUrl: url,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      telegramUser: json['telegram_user']?.toString(),
    );
  }

  Map<String, dynamic> toSupabaseMap({required String deviceId, String? contactPhone, String? contactEmail}) {
    return {
      'external_order_id': externalOrderId,
      'device_id': deviceId,
      'telegram_user': telegramUser,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'seller_order_id': sellerOrderId,
      'status': status,
      'fulfillment_status': fulfillmentStatus,
      'total_cents': totalCents,
      'currency': currency,
      'idempotency_key': externalOrderId, // Use stable order uuid
      'delivered_assets': deliveredKey != null ? [{'type': 'key', 'value': deliveredKey}] : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
