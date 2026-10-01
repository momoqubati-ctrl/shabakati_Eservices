import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_account_model.dart';

abstract class IAuthRepository {
  Future<UserAccountModel> registerUser({
    required String dialCode,
    required String phoneNational,
    required String fullName,
    required String region,
    required String pin4Digits,
  });

  Future<UserAccountModel> loginUser({
    required String accountNumber,
    required String pin4Digits,
  });

  Future<UserAccountModel> loginWithStoredHash({
    required String accountNumber,
    required String passwordHash,
  });

  Future<void> updateBiometricStatus({
    required String accountNumber,
    required bool enabled,
  });
}

class AuthRepository implements IAuthRepository {
  final SupabaseClient _supabase;

  AuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  @override
  Future<UserAccountModel> registerUser({
    required String dialCode,
    required String phoneNational,
    required String fullName,
    required String region,
    required String pin4Digits,
  }) async {
    final accountNumber = '$dialCode$phoneNational';
    final passwordHash = _hashPin(pin4Digits);

    // التحقق من وجود الحساب مسبقاً
    final existing = await _supabase
        .from('app_users')
        .select('*')
        .eq('account_number', accountNumber)
        .maybeSingle();

    if (existing != null) {
      if (existing['is_verified'] == true) {
        throw Exception('رقم الحساب مسجل ومفعل مسبقاً. يرجى تسجيل الدخول مباشرة.');
      } else {
        // تحديث الحساب غير المفعل ببيانات جديدة
        final updated = await _supabase
            .from('app_users')
            .update({
              'full_name': fullName,
              'region': region,
              'password_hash': passwordHash,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('account_number', accountNumber)
            .select()
            .single();

        return UserAccountModel.fromJson(updated);
      }
    }

    // إدراج حساب جديد
    final inserted = await _supabase
        .from('app_users')
        .insert({
          'account_number': accountNumber,
          'dial_code': dialCode,
          'phone_national': phoneNational,
          'full_name': fullName,
          'region': region,
          'password_hash': passwordHash,
          'is_verified': false,
          'biometric_enabled': false,
        })
        .select()
        .single();

    return UserAccountModel.fromJson(inserted);
  }

  @override
  Future<UserAccountModel> loginUser({
    required String accountNumber,
    required String pin4Digits,
  }) async {
    final passwordHash = _hashPin(pin4Digits);
    return await loginWithStoredHash(
      accountNumber: accountNumber,
      passwordHash: passwordHash,
    );
  }

  @override
  Future<UserAccountModel> loginWithStoredHash({
    required String accountNumber,
    required String passwordHash,
  }) async {
    final user = await _supabase
        .from('app_users')
        .select('*')
        .eq('account_number', accountNumber)
        .maybeSingle();

    if (user == null) {
      throw Exception('رقم الحساب غير مسجل في النظام. يرجى إنشاء حساب جديد أولاً.');
    }

    if (user['password_hash'] != passwordHash) {
      throw Exception('كلمة المرور غير صحيحة، يرجى التأكد وإعادة المحاولة.');
    }

    return UserAccountModel.fromJson(user);
  }

  @override
  Future<void> updateBiometricStatus({
    required String accountNumber,
    required bool enabled,
  }) async {
    await _supabase
        .from('app_users')
        .update({
          'biometric_enabled': enabled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('account_number', accountNumber);
  }
}
