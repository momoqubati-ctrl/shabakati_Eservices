import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../models/product_model.dart';

abstract class IProductRepository {
  Future<List<ProductModel>> getCatalog({int? cursor, int limit = 50});
  Future<ProductModel> getProductDetails(int productId);
}

class ProductRepository implements IProductRepository {
  final DioClient dioClient;

  ProductRepository(this.dioClient);

  @override
  Future<List<ProductModel>> getCatalog({int? cursor, int limit = 50}) async {
    try {
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
        return items.map((json) => ProductModel.fromJson(json)).toList();
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
