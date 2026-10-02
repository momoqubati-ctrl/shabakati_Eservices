import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/dio_client.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

abstract class IOrderRepository {
  Future<OrderSubmitResult> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    String? paymentId,
  });

  Future<List<OrderModel>> getOrdersByDevice(String deviceId);
  Stream<List<OrderModel>> streamOrdersByDevice(String deviceId);
  Future<OrderModel> refreshOrderStatus(OrderModel order);
}

class OrderRepository implements IOrderRepository {
  final DioClient dioClient;
  final SupabaseClient? supabaseClient;
  final Uuid _uuid = const Uuid();

  OrderRepository({
    required this.dioClient,
    this.supabaseClient,
  });

  @override
  Future<OrderSubmitResult> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    String? paymentId,
  }) async {
    final externalOrderId = 'ord_${_uuid.v4().substring(0, 12)}';
    final payloadItems = items.map((e) => {
      'product_id': e.product.id,
      'quantity': e.quantity,
    }).toList();

    int totalCents = items.fold<int>(0, (sum, item) => sum + (item.product.sellerPrice.amountCents * item.quantity));
    String currency = items.isNotEmpty ? items.first.product.sellerPrice.currency : 'USD';

    int? sellerOrderId;
    String fulfillmentStatus = 'processing';
    String orderStatus = 'paid';
    String? deliveredKey;
    String? deliveredUrl;
    bool isVaultSuccess = false;
    String? providerError;

    try {
      // 1. إرسال الطلب لـ Digital Vault Seller API
      final response = await dioClient.dio.post(
        '/orders',
        data: {
          'external_order_id': externalOrderId,
          'items': payloadItems,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] as Map<String, dynamic>;
        sellerOrderId = data['id'];
        fulfillmentStatus = data['fulfillment_status'] ?? 'processing';
        orderStatus = data['status'] ?? 'paid';
        if (data['total'] is Map) {
          totalCents = data['total']['amount_cents'] ?? totalCents;
          currency = data['total']['currency'] ?? currency;
        }

        // 2. إذا كان التسليم فوري ومكتمل (ready)، نقوم باستهلاك المفتاح الرقمي فوراً
        if (fulfillmentStatus == 'ready' && sellerOrderId != null) {
          final assets = await _consumeDelivery(sellerOrderId);
          deliveredKey = assets['key'];
          deliveredUrl = assets['url'];
          orderStatus = 'completed';
        }
        isVaultSuccess = true;
      } else {
        providerError = response.data?['error']?.toString() ?? 'تعذر قبول الطلب من المزود (${response.statusCode})';
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) {
        providerError = e.response!.data['error'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        providerError = e.message;
      } else {
        providerError = 'تعذر الاتصال بمزود الخدمة (Digital Vault)';
      }
    } catch (e) {
      providerError = e.toString().replaceAll('Exception: ', '');
    }

    // 3. إنشاء كائن الطلب دائماً وحفظه في Supabase لضمان بقاء العملية مسجلة ومعلقة حتى معالجة الدعم الفني
    final createdOrder = OrderModel(
      externalOrderId: externalOrderId,
      sellerOrderId: sellerOrderId,
      status: orderStatus,
      fulfillmentStatus: fulfillmentStatus,
      totalCents: totalCents,
      currency: currency,
      deliveredKey: deliveredKey,
      deliveredUrl: deliveredUrl,
      createdAt: DateTime.now(),
      telegramUser: telegramUser,
      contactPhone: contactPhone,
      paymentId: paymentId,
    );

    try {
      await _saveOrderToSupabase(
        order: createdOrder,
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );
    } catch (e) {
      // C4 Fix: تسجيل خطأ حفظ Supabase بدلاً من ابتلاعه صامتاً
      debugPrint('[OrderRepo] ⚠️ Failed to save order to Supabase: $e');
    }

    final bool isInstant = deliveredKey != null && deliveredKey.isNotEmpty;
    final message = isVaultSuccess
        ? (isInstant
            ? 'تم تفعيل واستلام المفتاح الرقمي بنجاح لدى المزود!'
            : 'تم الشراء بنجاح لدى مزود الخدمة وطلبك قيد التجهيز والتسليم.')
        : 'الطلب مسجل ومعلق قيد المعالجة من الدعم الفني: $providerError';

    return OrderSubmitResult(
      isSuccess: isVaultSuccess,
      order: createdOrder,
      errorMessage: providerError,
      isInstantDelivery: isInstant,
      message: message,
    );
  }

  Future<Map<String, dynamic>> _consumeDelivery(int sellerOrderId) async {
    try {
      // طلب access token للتسليم
      final tokenRes = await dioClient.dio.post(
        '/orders/$sellerOrderId/delivery-access',
        data: {},
      );

      if (tokenRes.statusCode == 201 || tokenRes.statusCode == 200) {
        final accessToken = tokenRes.data['data']['access_token'];
        // استهلاك الكود الرقمي
        final consumeRes = await dioClient.dio.post(
          '/delivery-access/consume',
          data: {'access_token': accessToken},
        );

        if (consumeRes.statusCode == 200) {
          final assets = consumeRes.data['data']['assets'] as List?;
          if (assets != null && assets.isNotEmpty) {
            // C3 Fix: جمع كافة الأصول الرقمية (دعم شراء كمية > 1)
            final keys = <String>[];
            String? firstUrl;
            final rawAssets = <Map<String, dynamic>>[];
            for (final item in assets) {
              final val = item['value']?.toString();
              final itemUrl = item['url']?.toString();
              if (val != null && val.isNotEmpty) keys.add(val);
              firstUrl ??= itemUrl;
              rawAssets.add({
                'type': item['type']?.toString() ?? 'key',
                'value': val ?? '',
              });
            }
            return {
              'key': keys.isNotEmpty ? keys.join('\n') : null,
              'url': firstUrl,
              'rawAssets': rawAssets,
            };
          }
        }
      }
    } catch (e) {
      // في حال كان التسليم ما زال قيد التجهيز (409 DELIVERY_NOT_READY)
      debugPrint('[OrderRepo] _consumeDelivery error for order #$sellerOrderId: $e');
    }
    return {'key': null, 'url': null, 'rawAssets': null};
  }

  Future<void> _saveOrderToSupabase({
    required OrderModel order,
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
  }) async {
    if (supabaseClient == null) return;
    try {
      final deliveredAssets = order.deliveredKey != null
          ? [
              for (final k in order.deliveredKey!.split('\n').where((k) => k.isNotEmpty))
                {'type': 'key', 'value': k},
            ]
          : null;

      final inserted = await supabaseClient!
          .from('orders')
          .insert({
            'external_order_id': order.externalOrderId,
            'device_id': deviceId,
            'telegram_user': telegramUser,
            'contact_phone': contactPhone,
            'contact_email': contactEmail,
            'seller_order_id': order.sellerOrderId,
            'status': order.status,
            'fulfillment_status': order.fulfillmentStatus,
            'total_cents': order.totalCents,
            'currency': order.currency,
            'idempotency_key': const Uuid().v4(),
            'delivered_assets': deliveredAssets,
            'payment_id': order.paymentId,
          })
          .select('id')
          .single();

      final dbOrderId = inserted['id'];
      if (dbOrderId != null) {
        final itemsPayload = items.map((item) => {
          'order_id': dbOrderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'unit_price_cents': item.product.sellerPrice.amountCents,
          'currency': item.product.sellerPrice.currency,
        }).toList();

        await supabaseClient!.from('order_items').insert(itemsPayload);
      }
    } catch (e) {
      // C4 Fix: تسجيل خطأ إدخال البيانات لتتبع المشاكل دون إيقاف التطبيق
      debugPrint('[OrderRepo] ⚠️ _saveOrderToSupabase error: $e');
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> getOrdersByDevice(String deviceId) async {
    if (supabaseClient == null) return [];
    try {
      final res = await supabaseClient!
          .from('orders')
          .select()
          .eq('device_id', deviceId)
          .order('created_at', ascending: false);

      return (res as List).map((json) => OrderModel.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<OrderModel>> streamOrdersByDevice(String deviceId) {
    if (supabaseClient == null) {
      return const Stream.empty();
    }
    return supabaseClient!
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .map((dataList) => dataList.map((json) => OrderModel.fromJson(json)).toList());
  }

  @override
  Future<OrderModel> refreshOrderStatus(OrderModel order) async {
    if (order.sellerOrderId == null) return order;

    try {
      final response = await dioClient.dio.get('/orders/${order.sellerOrderId}');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        String fulfillmentStatus = data['fulfillment_status'] ?? order.fulfillmentStatus;
        String status = data['status'] ?? order.status;
        String? key = order.deliveredKey;
        String? url = order.deliveredUrl;

        if (fulfillmentStatus == 'ready' && key == null) {
          final assets = await _consumeDelivery(order.sellerOrderId!);
          key = assets['key'] as String?;
          url = assets['url'] as String?;
          final rawAssets = assets['rawAssets'];
          status = 'completed';

          // C1 Fix: حفظ المفتاح المستهلك فوراً في Supabase لضمان عدم فقدانه
          if (supabaseClient != null && order.id != null && key != null) {
            try {
              final deliveredAssets = rawAssets is List
                  ? rawAssets
                  : [{'type': 'key', 'value': key}];
              await supabaseClient!
                  .from('orders')
                  .update({
                    'fulfillment_status': 'ready',
                    'status': 'completed',
                    'delivered_assets': deliveredAssets,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', order.id!);
              debugPrint('[OrderRepo] ✅ refreshOrderStatus: saved key to Supabase for order #${order.id}');
            } catch (e) {
              debugPrint('[OrderRepo] ⚠️ refreshOrderStatus: Supabase update failed: $e');
            }
          }
        }

        return OrderModel(
          id: order.id,
          externalOrderId: order.externalOrderId,
          sellerOrderId: order.sellerOrderId,
          status: status,
          fulfillmentStatus: fulfillmentStatus,
          totalCents: order.totalCents,
          currency: order.currency,
          deliveredKey: key,
          deliveredUrl: url,
          createdAt: order.createdAt,
          telegramUser: order.telegramUser,
          contactPhone: order.contactPhone,
          notes: order.notes,
          paymentId: order.paymentId,
        );
      }
    } catch (e) {
      debugPrint('[OrderRepo] refreshOrderStatus error: $e');
    }
    return order;
  }
}
