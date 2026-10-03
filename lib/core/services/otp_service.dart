import 'dart:math';
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

  /// توليد رمز عشوائي مكون من 4 أرقام
  String generate4DigitOtp() {
    final random = Random.secure();
    return (1000 + random.nextInt(9000)).toString();
  }

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

  /// إرسال رمز OTP إلى الهاتف عبر واتساب أو SMS
  Future<bool> sendOtp({
    required String phoneWithCode,
    String channel = 'whatsapp',
  }) async {
    try {
      final otp = generate4DigitOtp();
      final cleanPhone = sanitizePhoneNumber(phoneWithCode);
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));

      // 1. تسجيل الرمز في قاعدة بيانات Supabase
      await _supabase.from('phone_otps').insert({
        'phone': phoneWithCode,
        'otp_code': otp,
        'channel': channel,
        'is_used': false,
        'expires_at': expiresAt.toIso8601String(),
      });

      // 2. إرسال الرسالة عبر بوابة الخادم المشفرة والآمنة (Serverless Backend /api/send-otp)
      if (channel == 'whatsapp') {
        try {
          final res = await _dio.post(
            '${ApiConfig.vercelBackendUrl}/api/send-otp',
            data: {
              'phone': cleanPhone, // رقم بدون + وخالي من أي صفر زائد
              'otp': otp,
              'channel': channel,
            },
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
          debugPrint('Backend OTP response: ${res.statusCode} ${res.data}');
        } catch (e) {
          debugPrint('Backend OTP dispatch notice: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error in sendOtp: $e');
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
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }
}
