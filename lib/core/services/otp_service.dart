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

  /// تنظيف رقم الهاتف وإزالة أي مسافات أو إشارات زائد
  String sanitizePhoneNumber(String phoneWithCode) {
    return phoneWithCode.replaceAll(RegExp(r'[^0-9]'), '');
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
          await _dio.post(
            '${ApiConfig.vercelBackendUrl}/api/send-otp',
            data: {
              'phone': cleanPhone,
              'otp': otp,
              'channel': channel,
            },
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
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

  /// التحقق من صحة رمز الـ OTP المدخل
  Future<bool> verifyOtp({
    required String phoneWithCode,
    required String enteredOtp,
  }) async {
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final res = await _supabase
          .from('phone_otps')
          .select('id, otp_code, expires_at')
          .eq('phone', phoneWithCode)
          .eq('otp_code', enteredOtp)
          .eq('is_used', false)
          .gte('expires_at', nowUtc)
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final otpId = res.first['id'];
        // تعليم الرمز كمستخدم لمنع إعادة استخدامه
        await _supabase.from('phone_otps').update({'is_used': true}).eq('id', otpId);

        // تفعيل حساب المستخدم في جدول app_users
        await _supabase.from('app_users').update({'is_verified': true}).eq('account_number', phoneWithCode);

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }
}
