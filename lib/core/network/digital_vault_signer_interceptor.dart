import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class DigitalVaultSignerInterceptor extends Interceptor {
  final String keyId;
  final String apiSecret;
  final Uuid _uuid = const Uuid();

  DigitalVaultSignerInterceptor({
    required this.keyId,
    required this.apiSecret,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 1. الطابع الزمني UTC بصيغة RFC3339
    final nowUtc = DateTime.now().toUtc();
    final timestamp = '${nowUtc.toIso8601String().split('.').first}Z';
    final nonce = _uuid.v4().replaceAll('-', '');

    // 2. معالجة الجسم النصي وتوليد SHA256 lowercased hex
    String rawBody = '';
    if (options.data != null) {
      if (options.data is String) {
        rawBody = options.data as String;
      } else {
        rawBody = jsonEncode(options.data);
      }
    }
    final bodyHash = sha256.convert(utf8.encode(rawBody)).toString().toLowerCase();

    // 3. بناء المسار شاملاً الـ Query parameters
    final uri = options.uri;
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

    // 4. بناء الـ Canonical Request حسب وثيقة الربط بدقة
    final canonicalRequest = [
      options.method.toUpperCase(),
      pathWithQuery,
      timestamp,
      nonce,
      bodyHash,
    ].join('\n');

    // 5. حساب HMAC-SHA256
    final hmacKey = utf8.encode(apiSecret);
    final hmac = Hmac(sha256, hmacKey);
    final signature = hmac.convert(utf8.encode(canonicalRequest)).toString().toLowerCase();

    // 6. حقن ترويسات المصادقة والحماية
    options.headers['Accept'] = 'application/json';
    options.headers['X-Seller-Key'] = keyId;
    options.headers['X-Seller-Timestamp'] = timestamp;
    options.headers['X-Seller-Nonce'] = nonce;
    options.headers['X-Seller-Signature'] = 'sha256=$signature';
    options.headers['X-Request-ID'] = 'req_${_uuid.v4().substring(0, 8)}';

    // إضافة Idempotency-Key للمسارات التي تعدل البيانات
    final method = options.method.toUpperCase();
    if (method == 'POST' || method == 'PATCH' || method == 'PUT') {
      options.headers.putIfAbsent('Content-Type', () => 'application/json');
      options.headers.putIfAbsent('Idempotency-Key', () => _uuid.v4());
    }

    return handler.next(options);
  }
}
