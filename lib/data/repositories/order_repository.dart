import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/api_config.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/secure_storage_service.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/user_account_model.dart';

abstract class IOrderRepository {
  Future<OrderSubmitResult> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    String? paymentId,
    String? paymentReference,
    String? paymentMethod,
    String? walletName,
    int? userId,
    String? accountNumber,
  });

  Future<List<OrderModel>> getOrdersForUser(UserAccountModel user);
  Stream<List<OrderModel>> streamOrdersForUser(UserAccountModel user);
  Future<List<OrderModel>> getOrdersByDevice(String deviceId);
  Stream<List<OrderModel>> streamOrdersByDevice(String deviceId);
  Future<OrderModel> refreshOrderStatus(OrderModel order);
}

class OrderRepository implements IOrderRepository {
  final DioClient dioClient;
  final SupabaseClient? supabaseClient;
  final SecureStorageService? secureStorageService;
  final Uuid _uuid = const Uuid();
  final Dio _gatewayDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
      headers: {'Accept': 'application/json'},
    ),
  );

  OrderRepository({
    required this.dioClient,
    this.supabaseClient,
    this.secureStorageService,
  });

  @override
  Future<OrderSubmitResult> submitOrder({
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    String? paymentId,
    String? paymentReference,
    String? paymentMethod,
    String? walletName,
    int? userId,
    String? accountNumber,
  }) async {
    final externalOrderId = 'ord_${_uuid.v4().substring(0, 12)}';

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
      // 1. إرسال الطلب عبر بوابة الخادم المؤمنة (/api/orders)
      final response = await _gatewayDio.post(
        '${ApiConfig.vercelBackendUrl}/api/orders',
        data: {
          'external_order_id': externalOrderId,
          'items': items.map((e) => {
            'product_id': e.product.id,
            'product_name': e.product.name,
            'quantity': e.quantity,
            'unit_price_cents': e.product.sellerPrice.amountCents,
            'currency': e.product.sellerPrice.currency,
          }).toList(),
          'device_id': deviceId,
          'telegram_user': telegramUser,
          'contact_phone': contactPhone,
          'contact_email': contactEmail,
          'payment_id': paymentId,
          'payment_reference': paymentReference ?? paymentId,
          'payment_method': paymentMethod ?? 'المحافظ الإلكترونية',
          'wallet_name': walletName,
          'user_id': userId,
          'account_number': accountNumber,
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

        if (data['delivered_key'] != null && data['delivered_key'].toString().isNotEmpty) {
          deliveredKey = data['delivered_key'].toString();
          fulfillmentStatus = 'ready';
          orderStatus = 'completed';
          if (secureStorageService != null) {
            await secureStorageService!.saveDeliveredAsset(externalOrderId, deliveredKey, deliveredUrl);
          }
        } else if (fulfillmentStatus == 'ready' && sellerOrderId != null) {
          // 2. إذا كان التسليم فوري ومكتمل (ready)، نقوم باستهلاك المفتاح الرقمي فوراً
          final assets = await _consumeDelivery(sellerOrderId, externalOrderId: externalOrderId);
          deliveredKey = assets['key'];
          deliveredUrl = assets['url'];
          if (deliveredKey != null && deliveredKey.isNotEmpty) {
            orderStatus = 'completed';
            if (secureStorageService != null) {
              await secureStorageService!.saveDeliveredAsset(externalOrderId, deliveredKey, deliveredUrl);
            }
          }
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
      paymentReference: paymentReference ?? paymentId,
      paymentMethod: paymentMethod ?? 'المحافظ الإلكترونية',
      walletName: walletName,
      userId: userId,
      accountNumber: accountNumber,
    );

    try {
      await _saveOrderToSupabase(
        order: createdOrder,
        items: items,
        deviceId: deviceId,
        telegramUser: telegramUser,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        userId: userId,
        accountNumber: accountNumber,
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

  Future<Map<String, dynamic>> _consumeDelivery(int sellerOrderId, {String? externalOrderId}) async {
    try {
      // 1. المحاولة الأساسية عبر بوابة الخادم المؤمنة
      final extParam = (externalOrderId != null && externalOrderId.isNotEmpty)
          ? '&external_order_id=${Uri.encodeComponent(externalOrderId)}'
          : '';
      final gwRes = await _gatewayDio.get(
        '${ApiConfig.vercelBackendUrl}/api/orders?seller_order_id=$sellerOrderId$extParam&action=consume_key',
      );
      if (gwRes.statusCode == 200 && gwRes.data is Map) {
        final assets = gwRes.data['data']?['assets'] as List?;
        if (assets != null && assets.isNotEmpty) {
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
          if (keys.isNotEmpty) {
            return {
              'key': keys.join('\n'),
              'url': firstUrl,
              'rawAssets': rawAssets,
            };
          }
        }
      }
    } catch (_) {}

    try {
      // 2. المحاولة الاحتياطية المباشرة
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

  Future<List<OrderModel>> _mergeDeliveredAssets(List<OrderModel> list) async {
    if (secureStorageService == null) return list;
    final mergedList = <OrderModel>[];
    for (final o in list) {
      if (o.deliveredKey == null || o.deliveredKey!.isEmpty) {
        final cached = await secureStorageService!.getDeliveredAsset(o.externalOrderId);
        if (cached != null && cached['key'] != null && cached['key']!.isNotEmpty) {
          mergedList.add(o.copyWith(
            status: 'completed',
            fulfillmentStatus: 'ready',
            deliveredKey: cached['key'],
            deliveredUrl: cached['url'],
          ));
          continue;
        }
        if (o.id != null) {
          final cachedById = await secureStorageService!.getDeliveredAsset(o.id.toString());
          if (cachedById != null && cachedById['key'] != null && cachedById['key']!.isNotEmpty) {
            mergedList.add(o.copyWith(
              status: 'completed',
              fulfillmentStatus: 'ready',
              deliveredKey: cachedById['key'],
              deliveredUrl: cachedById['url'],
            ));
            continue;
          }
        }
      }
      mergedList.add(o);
    }
    return mergedList;
  }

  Future<void> _saveOrderToSupabase({
    required OrderModel order,
    required List<CartItemModel> items,
    required String deviceId,
    String? telegramUser,
    String? contactPhone,
    String? contactEmail,
    int? userId,
    String? accountNumber,
  }) async {
    if (supabaseClient == null) return;
    try {
      final existing = await supabaseClient!
          .from('orders')
          .select('id')
          .eq('external_order_id', order.externalOrderId)
          .maybeSingle();
      if (existing != null) return;

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
            'payment_reference': order.paymentReference ?? order.paymentId,
            'payment_method': order.paymentMethod ?? 'المحافظ الإلكترونية',
            'wallet_name': order.walletName,
            'user_id': userId,
            'account_number': accountNumber,
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
  Future<List<OrderModel>> getOrdersForUser(UserAccountModel user) async {
    if (supabaseClient == null) return [];
    try {
      final res = await supabaseClient!.rpc('rpc_get_user_orders', params: {
        'p_account_number': user.accountNumber,
        'p_phone_national': user.phoneNational,
        'p_user_id': user.id,
        'p_session_token': user.sessionToken,
      });

      final list = (res as List).map((json) => OrderModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      final userOrders = list.where((o) => o.matchesUser(user)).toList();
      return await _mergeDeliveredAssets(userOrders);
    } catch (e) {
      debugPrint('[OrderRepo] getOrdersForUser error: $e');
      return [];
    }
  }

  @override
  Stream<List<OrderModel>> streamOrdersForUser(UserAccountModel user) async* {
    if (supabaseClient == null) return;
    yield await getOrdersForUser(user);
    yield* Stream.periodic(const Duration(seconds: 10)).asyncMap((_) => getOrdersForUser(user));
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

      final list = (res as List).map((json) => OrderModel.fromJson(json)).toList();
      return await _mergeDeliveredAssets(list);
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
    // 1. إذا كان الطلب مكتملاً ومفتاحه موجود مسبقاً، لا داعي لإعادة الفحص
    if (order.deliveredKey != null && order.deliveredKey!.isNotEmpty && order.isReady) {
      return order;
    }

    // 2. فحص التخزين المحلي المشفر أولاً
    if (secureStorageService != null) {
      final cached = await secureStorageService!.getDeliveredAsset(order.externalOrderId);
      if (cached != null && cached['key'] != null && cached['key']!.isNotEmpty) {
        return order.copyWith(
          status: 'completed',
          fulfillmentStatus: 'ready',
          deliveredKey: cached['key'],
          deliveredUrl: cached['url'],
        );
      }
      if (order.id != null) {
        final cachedById = await secureStorageService!.getDeliveredAsset(order.id.toString());
        if (cachedById != null && cachedById['key'] != null && cachedById['key']!.isNotEmpty) {
          return order.copyWith(
            status: 'completed',
            fulfillmentStatus: 'ready',
            deliveredKey: cachedById['key'],
            deliveredUrl: cachedById['url'],
          );
        }
      }
    }

    if (order.sellerOrderId == null) return order;

    String fulfillmentStatus = order.fulfillmentStatus;
    String status = order.status;
    String? key = order.deliveredKey;
    String? url = order.deliveredUrl;
    List<Map<String, dynamic>>? rawAssets;

    // 3. المحاولة الأساسية: عبر بوابة Vercel السحابية (أسرع وأكثر موثوقية وتجاوز حجب الشبكات المحلية)
    try {
      final gatewayUrl = '${ApiConfig.vercelBackendUrl}/api/orders?seller_order_id=${order.sellerOrderId}&external_order_id=${Uri.encodeComponent(order.externalOrderId)}&action=consume_key';
      final res = await _gatewayDio.get(gatewayUrl);
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data['data'];
        if (data != null && data['assets'] is List) {
          final assets = data['assets'] as List;
          if (assets.isNotEmpty) {
            final keys = <String>[];
            final raw = <Map<String, dynamic>>[];
            for (final item in assets) {
              if (item is Map) {
                final val = item['value']?.toString() ?? item['key']?.toString();
                final itemUrl = item['url']?.toString();
                if (val != null && val.isNotEmpty) keys.add(val);
                url ??= itemUrl;
                final assetMap = <String, dynamic>{
                  'type': item['type']?.toString() ?? 'key',
                  'value': val ?? '',
                };
                if (itemUrl != null) assetMap['url'] = itemUrl;
                raw.add(assetMap);
              }
            }
            if (keys.isNotEmpty) {
              key = keys.join('\n');
              rawAssets = raw;
              fulfillmentStatus = 'ready';
              status = 'completed';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OrderRepo] Gateway consume_key error for #${order.sellerOrderId}: $e');
    }

    // 4. المحاولة الاحتياطية: إذا لم نحصل على المفتاح، الاتصال المباشر بمزود Digital Vault
    if (key == null || key.isEmpty) {
      try {
        final response = await dioClient.dio.get('/orders/${order.sellerOrderId}');
        if (response.statusCode == 200) {
          final data = response.data['data'];
          fulfillmentStatus = data['fulfillment_status'] ?? fulfillmentStatus;
          status = data['status'] ?? status;

          if (fulfillmentStatus == 'ready') {
            final assets = await _consumeDelivery(order.sellerOrderId!, externalOrderId: order.externalOrderId);
            if (assets['key'] != null) {
              key = assets['key'] as String?;
              url = assets['url'] as String?;
              rawAssets = assets['rawAssets'] as List<Map<String, dynamic>>?;
              status = 'completed';
            }
          }
        }
      } catch (e) {
        debugPrint('[OrderRepo] Direct Digital Vault refresh error for #${order.sellerOrderId}: $e');
      }
    }

    // 5. إذا تم جلب المفتاح بنجاح، حفظه محلياً في SecureStorage وتحديث السحابة
    if (key != null && key.isNotEmpty) {
      fulfillmentStatus = 'ready';
      status = 'completed';

      // أ) الحفظ المحلي الفوري المشفر
      if (secureStorageService != null) {
        await secureStorageService!.saveDeliveredAsset(order.externalOrderId, key, url);
        if (order.id != null) {
          await secureStorageService!.saveDeliveredAsset(order.id.toString(), key, url);
        }
      }

      final deliveredAssetsPayload = rawAssets ??
          key
              .split('\n')
              .where((k) => k.isNotEmpty)
              .map((k) {
                final m = <String, dynamic>{'type': 'key', 'value': k};
                if (url != null) m['url'] = url;
                return m;
              })
              .toList();

      // ب) التحديث عبر بوابة Vercel السحابية (لتجاوز أي قيود صلاحيات RLS على Supabase)
      try {
        await _gatewayDio.patch(
          '${ApiConfig.vercelBackendUrl}/api/orders',
          data: {
            if (order.id != null) 'id': order.id,
            'external_order_id': order.externalOrderId,
            'seller_order_id': order.sellerOrderId,
            'status': 'completed',
            'fulfillment_status': 'ready',
            'delivered_assets': deliveredAssetsPayload,
          },
        );
      } catch (_) {}

      // ج) التحديث المباشر عبر عميل Supabase
      if (supabaseClient != null) {
        try {
          final updateData = {
            'fulfillment_status': 'ready',
            'status': 'completed',
            'delivered_assets': deliveredAssetsPayload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          if (order.id != null) {
            await supabaseClient!.from('orders').update(updateData).eq('id', order.id!);
          } else {
            await supabaseClient!.from('orders').update(updateData).eq('external_order_id', order.externalOrderId);
          }
        } catch (_) {}
      }
    }

    return order.copyWith(
      status: status,
      fulfillmentStatus: fulfillmentStatus,
      deliveredKey: key,
      deliveredUrl: url,
    );
  }
}
