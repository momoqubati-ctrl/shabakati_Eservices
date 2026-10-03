import 'package:intl/intl.dart';
import 'user_account_model.dart';

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
  final String? contactPhone;
  final String? notes;
  final String? paymentId;
  final int? userId;
  final String? accountNumber;

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
    this.contactPhone,
    this.notes,
    this.paymentId,
    this.userId,
    this.accountNumber,
  });

  bool get isReady =>
      fulfillmentStatus == 'ready' ||
      status == 'completed' ||
      (deliveredKey != null && deliveredKey!.isNotEmpty);
  bool get isProcessing =>
      !isReady &&
      !isFailed &&
      (fulfillmentStatus == 'processing' || status == 'paid' || status == 'pending');
  bool get isFailed => fulfillmentStatus == 'failed' || status == 'cancelled';

  /// فحص هل الطلب ينتمي لهذا المستخدم بالتحديد لمنع تداخل بيانات المستخدمين
  bool matchesUser(UserAccountModel user) {
    if (userId != null && user.id != null && userId == user.id) return true;
    if (accountNumber != null && accountNumber!.isNotEmpty) {
      final cleanAcc = accountNumber!.replaceAll('+', '').trim();
      final cleanUserAcc = user.accountNumber.replaceAll('+', '').trim();
      final cleanUserNat = user.phoneNational.replaceAll('+', '').trim();
      if (cleanAcc == cleanUserAcc || cleanAcc == cleanUserNat) return true;
    }
    if (contactPhone != null && contactPhone!.isNotEmpty) {
      final cleanContact = contactPhone!.replaceAll('+', '').trim();
      final cleanUserAcc = user.accountNumber.replaceAll('+', '').trim();
      final cleanUserNat = user.phoneNational.replaceAll('+', '').trim();
      if (cleanContact == cleanUserAcc || cleanContact == cleanUserNat) return true;
    }
    return false;
  }

  OrderModel copyWith({
    int? id,
    String? externalOrderId,
    int? sellerOrderId,
    String? status,
    String? fulfillmentStatus,
    int? totalCents,
    String? currency,
    String? deliveredKey,
    String? deliveredUrl,
    DateTime? createdAt,
    String? telegramUser,
    String? contactPhone,
    String? notes,
    String? paymentId,
    int? userId,
    String? accountNumber,
  }) {
    return OrderModel(
      id: id ?? this.id,
      externalOrderId: externalOrderId ?? this.externalOrderId,
      sellerOrderId: sellerOrderId ?? this.sellerOrderId,
      status: status ?? this.status,
      fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
      totalCents: totalCents ?? this.totalCents,
      currency: currency ?? this.currency,
      deliveredKey: deliveredKey ?? this.deliveredKey,
      deliveredUrl: deliveredUrl ?? this.deliveredUrl,
      createdAt: createdAt ?? this.createdAt,
      telegramUser: telegramUser ?? this.telegramUser,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      paymentId: paymentId ?? this.paymentId,
      userId: userId ?? this.userId,
      accountNumber: accountNumber ?? this.accountNumber,
    );
  }

  double get totalAmount => totalCents / 100.0;
  String get displayTotal => '\$${totalAmount.toStringAsFixed(2)} $currency';

  /// احتساب السعر بالريال اليمني للطلب
  double totalAmountYer({double exchangeRate = 535.0}) {
    final costYer = (totalCents / 100.0) * exchangeRate;
    final withMargin = costYer + 1000.0;
    return (withMargin / 1000.0).ceil() * 1000.0;
  }

  String displayTotalYer({double exchangeRate = 535.0}) {
    final yer = totalAmountYer(exchangeRate: exchangeRate);
    final formatter = NumberFormat('#,###');
    return '${formatter.format(yer)} ر.ي';
  }

  /// السعر المعادل بالدولار لسعر البيع للجمهور بالريال اليمني
  double totalRetailUsd({double exchangeRate = 535.0}) {
    final rate = (exchangeRate > 0) ? exchangeRate : 535.0;
    return totalAmountYer(exchangeRate: rate) / rate;
  }

  String displayRetailUsd({double exchangeRate = 535.0}) {
    final usd = totalRetailUsd(exchangeRate: exchangeRate);
    return '\$${usd.toStringAsFixed(2)} USD';
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? key;
    String? url;
    if (json['delivered_assets'] != null) {
      final assets = json['delivered_assets'];
      if (assets is List && assets.isNotEmpty) {
        // C3 Fix: دعم كافة الأصول الرقمية عند شراء كمية أكبر من 1
        final keys = <String>[];
        String? firstUrl;
        for (final asset in assets) {
          if (asset is Map) {
            final val = asset['value']?.toString() ?? asset['key']?.toString();
            if (val != null && val.isNotEmpty) keys.add(val);
            firstUrl ??= asset['url']?.toString();
          } else if (asset is String && asset.isNotEmpty) {
            keys.add(asset);
          }
        }
        key = keys.isNotEmpty ? keys.join('\n') : null;
        url = firstUrl;
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
      contactPhone: json['contact_phone']?.toString(),
      notes: json['notes']?.toString() ?? json['failure_reason']?.toString(),
      paymentId: json['payment_id']?.toString(),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      accountNumber: json['account_number']?.toString(),
    );
  }

  Map<String, dynamic> toSupabaseMap({required String deviceId, String? contactPhone, String? contactEmail}) {
    return {
      'external_order_id': externalOrderId,
      'device_id': deviceId,
      'telegram_user': telegramUser,
      'contact_phone': contactPhone ?? this.contactPhone,
      'contact_email': contactEmail,
      'seller_order_id': sellerOrderId,
      'status': status,
      'fulfillment_status': fulfillmentStatus,
      'total_cents': totalCents,
      'currency': currency,
      'idempotency_key': externalOrderId, // Use stable order uuid
      'delivered_assets': deliveredKey != null
          ? [
              for (final k in deliveredKey!.split('\n').where((k) => k.isNotEmpty))
                {'type': 'key', 'value': k},
            ]
          : null,
      'payment_id': paymentId,
      'notes': notes,
      'user_id': userId,
      'account_number': accountNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class OrderSubmitResult {
  final bool isSuccess;
  final OrderModel order;
  final String? errorMessage;
  final bool isInstantDelivery;
  final String message;

  OrderSubmitResult({
    required this.isSuccess,
    required this.order,
    this.errorMessage,
    this.isInstantDelivery = false,
    required this.message,
  });
}

