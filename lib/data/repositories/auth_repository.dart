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

  String _hashPinSalted(String accountNumber, String pin) {
    final cleanAcc = accountNumber.trim();
    final cleanPin = pin.trim();
    final bytes = utf8.encode('$cleanAcc:$cleanPin:shabakti_sec_v1');
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
    final passwordHash = _hashPinSalted(accountNumber, pin4Digits);

    final res = await _supabase.rpc('rpc_register_user', params: {
      'p_account_number': accountNumber,
      'p_dial_code': dialCode,
      'p_phone_national': phoneNational,
      'p_full_name': fullName,
      'p_region': region,
      'p_password_hash': passwordHash,
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['error'] == 'ACCOUNT_ALREADY_VERIFIED') {
      throw Exception('رقم الحساب مسجل ومفعل مسبقاً. يرجى تسجيل الدخول مباشرة.');
    }

    return UserAccountModel.fromJson(data);
  }

  @override
  Future<UserAccountModel> loginUser({
    required String accountNumber,
    required String pin4Digits,
  }) async {
    final saltedHash = _hashPinSalted(accountNumber, pin4Digits);
    final legacyHash = _hashPin(pin4Digits);

    final res = await _supabase.rpc('rpc_login_user', params: {
      'p_account_number': accountNumber,
      'p_password_hash': saltedHash,
      'p_legacy_hash': legacyHash,
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['error'] == 'USER_NOT_FOUND') {
      throw Exception('رقم الحساب غير مسجل في النظام. يرجى إنشاء حساب جديد أولاً.');
    }
    if (data['error'] == 'INVALID_PASSWORD') {
      throw Exception('كلمة المرور غير صحيحة، يرجى التأكد وإعادة المحاولة.');
    }

    return UserAccountModel.fromJson(data);
  }

  @override
  Future<UserAccountModel> loginWithStoredHash({
    required String accountNumber,
    required String passwordHash,
  }) async {
    final res = await _supabase.rpc('rpc_login_user', params: {
      'p_account_number': accountNumber,
      'p_password_hash': passwordHash,
      'p_legacy_hash': null,
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['error'] == 'USER_NOT_FOUND') {
      throw Exception('رقم الحساب غير مسجل في النظام. يرجى إنشاء حساب جديد أولاً.');
    }
    if (data['error'] == 'INVALID_PASSWORD') {
      throw Exception('انتهت صلاحية بيانات البصمة المحفوظة، يرجى الدخول بكلمة المرور.');
    }

    return UserAccountModel.fromJson(data);
  }

  @override
  Future<void> updateBiometricStatus({
    required String accountNumber,
    required bool enabled,
  }) async {
    await _supabase.rpc('rpc_update_biometric', params: {
      'p_account_number': accountNumber,
      'p_enabled': enabled,
    });
  }
}
