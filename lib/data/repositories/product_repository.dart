import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/api_config.dart';
import '../../core/network/dio_client.dart';
import '../models/product_model.dart';

abstract class IProductRepository {
  Future<List<ProductModel>> getCatalog({int? cursor, int limit = 50});
  Future<ProductModel> getProductDetails(int productId);
  double get currentExchangeRate;
}

class ProductRepository implements IProductRepository {
  final DioClient dioClient;
  final SupabaseClient? supabaseClient;
  final Dio _gatewayDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  double _exchangeRate = 535.0;

  ProductRepository(this.dioClient, {this.supabaseClient});

  @override
  double get currentExchangeRate => _exchangeRate;

  @override
  Future<List<ProductModel>> getCatalog({int? cursor, int limit = 50}) async {
    try {
      // 1. جلب سعر الصرف من Supabase
      if (supabaseClient != null) {
        try {
          final settings = await supabaseClient!
              .from('app_settings')
              .select('usd_to_yer_rate')
              .eq('id', 'general_settings')
              .maybeSingle();

          if (settings != null && settings['usd_to_yer_rate'] != null) {
            _exchangeRate = (settings['usd_to_yer_rate'] as num).toDouble();
          }
        } catch (_) {}
      }

      // 2. جلب أسعار البيع والكميات المحددة للأدمن
      final Map<int, Map<String, dynamic>> customPricingMap = {};
      if (supabaseClient != null) {
        try {
          final List customList = await supabaseClient!.from('product_settings').select();
          for (var item in customList) {
            final pid = item['product_id'] as int?;
            if (pid != null) {
              customPricingMap[pid] = item;
            }
          }
        } catch (_) {}
      }

      // 3. جلب قائمة الخدمات عبر بوابة الخادم المؤمنة (/api/catalog)
      final query = <String, dynamic>{'limit': limit};
      if (cursor != null) {
        query['cursor'] = cursor;
      }

      Response? response;
      try {
        final res = await _gatewayDio.get(
          '${ApiConfig.vercelBackendUrl}/api/catalog',
          queryParameters: query,
        );
        if (res.statusCode == 200 && res.data is Map && res.data['success'] == true) {
          response = res;
        }
      } catch (_) {}

      // إذا نجحت البوابة الخادمة وكان هناك بيانات
      if (response != null && response.data['data'] is List) {
        final List items = response.data['data'] as List;
        return items.map((json) {
          final productId = json['id'] as int;
          final customSetting = customPricingMap[productId];

          double? customYer;
          int? stock;
          String? iconUrl;
          bool hasWarning = false;
          String? warningMsg;

          if (customSetting != null) {
            if (customSetting['custom_price_yer'] != null) {
              customYer = (customSetting['custom_price_yer'] as num).toDouble();
            }
            if (customSetting['stock_quantity'] != null) {
              stock = customSetting['stock_quantity'] as int;
            }
            if (customSetting['icon_url'] != null && (customSetting['icon_url'] as String).isNotEmpty) {
              iconUrl = customSetting['icon_url'] as String;
            }
            if (customSetting['has_warning_notice'] == true) {
              hasWarning = true;
            }
            if (customSetting['warning_notice_message'] != null) {
              warningMsg = customSetting['warning_notice_message'] as String;
            }
          }

          return ProductModel.fromJson(
            json,
            customPriceYer: customYer,
            stockQuantity: stock,
            iconUrl: iconUrl,
            hasWarningNotice: hasWarning,
            warningNoticeMessage: warningMsg,
          );
        }).toList();
      }

      // 4. في حال تعذر البوابة: قراءة الكتالوج المعتمد مباشرة من Supabase (cached_products)
      if (supabaseClient != null) {
        try {
          final List cachedRows = await supabaseClient!
              .from('cached_products')
              .select()
              .order('id');
          if (cachedRows.isNotEmpty) {
            return cachedRows.map((row) {
              final productId = row['id'] as int;
              final customSetting = customPricingMap[productId];

              double? customYer;
              int? stock;
              String? iconUrl;
              bool hasWarning = false;
              String? warningMsg;

              if (customSetting != null) {
                if (customSetting['custom_price_yer'] != null) {
                  customYer = (customSetting['custom_price_yer'] as num).toDouble();
                }
                if (customSetting['stock_quantity'] != null) {
                  stock = customSetting['stock_quantity'] as int;
                }
                if (customSetting['icon_url'] != null && (customSetting['icon_url'] as String).isNotEmpty) {
                  iconUrl = customSetting['icon_url'] as String;
                }
                if (customSetting['has_warning_notice'] == true) {
                  hasWarning = true;
                }
                if (customSetting['warning_notice_message'] != null) {
                  warningMsg = customSetting['warning_notice_message'] as String;
                }
              }

              final priceCents = (row['price_cents'] as num?)?.toInt() ?? 0;
              final currency = (row['currency'] as String?) ?? 'USD';
              final availability = (row['availability']?.toString().replaceAll('"', '') ?? 'available');

              final jsonPayload = {
                'id': productId,
                'sku': row['sku'] ?? '',
                'name': row['name'] ?? '',
                'availability': availability,
                'pricing_quantity': 1,
                'seller_price': {
                  'amount_cents': priceCents,
                  'currency': currency,
                },
                'seller_base_price': {
                  'amount_cents': priceCents,
                  'currency': currency,
                },
                'line_total': {
                  'amount_cents': priceCents,
                  'currency': currency,
                },
              };

              return ProductModel.fromJson(
                jsonPayload,
                customPriceYer: customYer,
                stockQuantity: stock,
                iconUrl: iconUrl,
                hasWarningNotice: hasWarning,
                warningNoticeMessage: warningMsg,
              );
            }).toList();
          }
        } catch (_) {}
      }

      throw Exception('تعذر استرجاع قائمة الخدمات الرقمية، يرجى المحاولة بعد قليل');
    } catch (e) {
      if (e.toString().contains('تعذر استرجاع')) {
        rethrow;
      }
      throw Exception('تعذر استرجاع قائمة الخدمات الرقمية، يرجى المحاولة بعد قليل');
    }
  }

  @override
  Future<ProductModel> getProductDetails(int productId) async {
    try {
      try {
        final response = await _gatewayDio.get(
          '${ApiConfig.vercelBackendUrl}/api/catalog',
          queryParameters: {'product_id': productId},
        );
        if (response.statusCode == 200 && response.data is Map && response.data['success'] == true) {
          return ProductModel.fromJson(response.data['data']);
        }
      } catch (_) {}

      // Fallback مباشر من Supabase
      if (supabaseClient != null) {
        final row = await supabaseClient!
            .from('cached_products')
            .select()
            .eq('id', productId)
            .maybeSingle();
        if (row != null) {
          final priceCents = (row['price_cents'] as num?)?.toInt() ?? 0;
          final currency = (row['currency'] as String?) ?? 'USD';
          final availability = (row['availability']?.toString().replaceAll('"', '') ?? 'available');
          return ProductModel.fromJson({
            'id': productId,
            'sku': row['sku'] ?? '',
            'name': row['name'] ?? '',
            'availability': availability,
            'pricing_quantity': 1,
            'seller_price': {
              'amount_cents': priceCents,
              'currency': currency,
            },
            'seller_base_price': {
              'amount_cents': priceCents,
              'currency': currency,
            },
            'line_total': {
              'amount_cents': priceCents,
              'currency': currency,
            },
          });
        }
      }
      throw Exception('الخدمة غير متوفرة حالياً');
    } catch (e) {
      rethrow;
    }
  }
}
