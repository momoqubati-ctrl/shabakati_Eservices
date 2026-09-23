import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/dio_client.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

abstract class IOrderRepository {
  Future<OrderModel> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
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
  Future<OrderModel> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final externalOrderId = 'ord_${_uuid.v4().substring(0, 12)}';
    final payloadItems = items.map((e) => {
      'product_id': e.product.id,
      'quantity': e.quantity,
    }).toList();

    try {
      // 1. إرسال الطلب لـ Digital Vault Seller API
      final response = await dioClient.dio.post(
        '/orders',
        data: {
          'external_order_id': externalOrderId,
          'items': payloadItems,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.data['error'] ?? 'فشل في إنشاء الطلب لدى المزود');
      }

      final data = response.data['data'] as Map<String, dynamic>;
      int sellerOrderId = data['id'];
      String fulfillmentStatus = data['fulfillment_status'] ?? 'processing';
      String orderStatus = data['status'] ?? 'paid';
      int totalCents = (data['total'] is Map) ? (data['total']['amount_cents'] ?? 0) : 0;
      String currency = (data['total'] is Map) ? (data['total']['currency'] ?? 'USD') : 'USD';

      String? deliveredKey;
      String? deliveredUrl;

      // 2. إذا كان التسليم فوري ومكتمل (ready)، نقوم باستهلاك المفتاح الرقمي فوراً
      if (fulfillmentStatus == 'ready') {
        final assets = await _consumeDelivery(sellerOrderId);
        deliveredKey = assets['key'];
        deliveredUrl = assets['url'];
        fulfillmentStatus = 'ready';
        orderStatus = 'completed';
      }

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
      );

      // 3. حفظ نسخة من الطلب في قاعدة بيانات Supabase للمتابعة بدون تسجيل دخول
      await _saveOrderToSupabase(
        order: createdOrder,
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );

      return createdOrder;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        throw Exception(e.response?.data['error'] ?? 'خطأ أثناء معالجة الطلب');
      }
      throw Exception('تعذر استكمال الطلب، تأكد من الاتصال بالإنترنت');
    }
  }

  Future<Map<String, String?>> _consumeDelivery(int sellerOrderId) async {
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
            final item = assets.first;
            return {
              'key': item['value']?.toString(),
              'url': item['url']?.toString(),
            };
          }
        }
      }
    } catch (_) {
      // في حال كان التسليم ما زال قيد التجهيز (409 DELIVERY_NOT_READY)
    }
    return {'key': null, 'url': null};
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
            'delivered_assets': order.deliveredKey != null
                ? [{'type': 'key', 'value': order.deliveredKey}]
                : null,
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
    } catch (_) {
      // إكمال العملية دون إيقاف التطبيق في حال عدم توفر اتصال Supabase المباشر
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
          key = assets['key'];
          url = assets['url'];
          status = 'completed';
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
        );
      }
    } catch (_) {}
    return order;
  }
}
