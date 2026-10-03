import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class OtpService {
  final SupabaseClient _supabase;
  final Dio _dio;

  OtpService({
    SupabaseClient? supabase,
    Dio? dio,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _dio = dio ?? Dio();

  /// تنظيف رقم الهاتف وإزالة أي مسافات أو إشارات زائد ومعالجة الأصفار الزائدة
  String sanitizePhoneNumber(String phoneWithCode) {
    var cleaned = phoneWithCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('9670')) {
      cleaned = '967${cleaned.substring(4)}';
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '967${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('967') && cleaned.length == 9) {
      cleaned = '967$cleaned';
    }
    return cleaned;
  }

  /// طلب توليد وإرسال رمز OTP من الخادم الآمن (/api/send-otp) دون توليد محلي
  Future<bool> sendOtp({
    required String phoneWithCode,
    String channel = 'whatsapp',
  }) async {
    try {
      final cleanPhone = sanitizePhoneNumber(phoneWithCode);

      final res = await _dio.post(
        '${ApiConfig.vercelBackendUrl}/api/send-otp',
        data: {
          'phone': cleanPhone,
          'raw_phone': phoneWithCode.trim(),
          'channel': channel,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[OtpService] Failed to dispatch OTP request');
      return false;
    }
  }

  /// التحقق من صحة رمز الـ OTP المدخل عبر دالة قاعدة البيانات المؤمنة (RPC)
  Future<bool> verifyOtp({
    required String phoneWithCode,
    required String enteredOtp,
  }) async {
    try {
      final cleanPhone = sanitizePhoneNumber(phoneWithCode);
      final res = await _supabase.rpc('verify_phone_otp', params: {
        'p_phone': phoneWithCode.trim(),
        'p_clean_phone': cleanPhone,
        'p_otp': enteredOtp.trim(),
      });
      return res == true;
    } catch (e) {
      debugPrint('[OtpService] OTP verification failed');
      return false;
    }
  }
}
