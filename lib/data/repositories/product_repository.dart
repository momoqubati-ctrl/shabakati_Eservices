import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

      // 3. جلب قائمة الخدمات من المزود
      final query = <String, dynamic>{'limit': limit};
      if (cursor != null) {
        query['cursor'] = cursor;
      }

      final response = await dioClient.dio.get(
        '/catalog/products',
        queryParameters: query,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List items = response.data['data'] as List;
        return items.map((json) {
          final productId = json['id'] as int;
          final customSetting = customPricingMap[productId];

          double? customYer;
          int? stock;
          String? iconUrl;

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
          }

          return ProductModel.fromJson(
            json,
            customPriceYer: customYer,
            stockQuantity: stock,
            iconUrl: iconUrl,
          );
        }).toList();
      } else {
        throw Exception(response.data['error'] ?? 'فشل في استرجاع قائمة الخدمات');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        throw Exception(e.response?.data['error'] ?? 'خطأ في الاتصال بالخادم');
      }
      throw Exception('تعذر الاتصال بخادم الخدمات الرقمية، تحقق من اتصالك بالإنترنت');
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع: $e');
    }
  }

  @override
  Future<ProductModel> getProductDetails(int productId) async {
    try {
      final response = await dioClient.dio.get('/catalog/products/$productId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return ProductModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['error'] ?? 'الخدمة غير متوفرة حالياً');
    } catch (e) {
      rethrow;
    }
  }
}
