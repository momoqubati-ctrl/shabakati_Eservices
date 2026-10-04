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
    String? sessionToken,
  });

  Future<void> changePassword({
    required String accountNumber,
    required String oldPin4Digits,
    required String newPin4Digits,
  });

  Future<String> checkAccountExists({
    required String accountNumber,
  });

  Future<void> resetPassword({
    required String accountNumber,
    required String cleanPhone,
    required String newPin4Digits,
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
    if (data['error'] == 'REGISTRATION_PENDING_VERIFICATION') {
      throw Exception('يوجد طلب تسجيل قيد التحقق لهذا الرقم، يرجى الانتظار دقائق أو إدخال رمز التحقق المرسل.');
    }
    if (data['error'] == 'ACCOUNT_LOCKED') {
      throw Exception('تم قفل المحاولات مؤقتاً لمدة 15 دقيقة، يرجى المحاولة لاحقاً.');
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
    if (data['error'] == 'ACCOUNT_LOCKED') {
      throw Exception('تم قفل الحساب مؤقتاً لمدة 15 دقيقة بسبب تجاوز عدد المحاولات الخاطئة المسموحة.');
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
    if (data['error'] == 'ACCOUNT_LOCKED') {
      throw Exception('تم قفل الحساب مؤقتاً لمدة 15 دقيقة بسبب تجاوز عدد المحاولات الخاطئة المسموحة.');
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
    String? sessionToken,
  }) async {
    await _supabase.rpc('rpc_update_biometric', params: {
      'p_account_number': accountNumber,
      'p_enabled': enabled,
      'p_session_token': sessionToken,
    });
  }

  @override
  Future<void> changePassword({
    required String accountNumber,
    required String oldPin4Digits,
    required String newPin4Digits,
  }) async {
    final oldSalted = _hashPinSalted(accountNumber, oldPin4Digits);
    final oldLegacy = _hashPin(oldPin4Digits);
    final newSalted = _hashPinSalted(accountNumber, newPin4Digits);

    final res = await _supabase.rpc('rpc_change_password', params: {
      'p_account_number': accountNumber,
      'p_old_hash': oldSalted,
      'p_old_legacy_hash': oldLegacy,
      'p_new_hash': newSalted,
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['error'] == 'USER_NOT_FOUND') {
      throw Exception('لم يتم العثور على الحساب في النظام.');
    }
    if (data['error'] == 'ACCOUNT_LOCKED') {
      throw Exception('تم قفل الحساب مؤقتاً لمدة 15 دقيقة بسبب تجاوز عدد المحاولات الخاطئة المسموحة.');
    }
    if (data['error'] == 'INVALID_OLD_PASSWORD') {
      throw Exception('كلمة المرور القديمة غير صحيحة، يرجى التأكد وإعادة المحاولة.');
    }
  }

  @override
  Future<String> checkAccountExists({
    required String accountNumber,
  }) async {
    final res = await _supabase.rpc('rpc_check_account_exists', params: {
      'p_account_number': accountNumber.trim(),
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['exists'] != true) {
      throw Exception('رقم الحساب غير مسجل في النظام، يرجى التأكد من الرقم المدخل.');
    }

    return data['account_number']?.toString() ?? accountNumber.trim();
  }

  @override
  Future<void> resetPassword({
    required String accountNumber,
    required String cleanPhone,
    required String newPin4Digits,
  }) async {
    final newSalted = _hashPinSalted(accountNumber, newPin4Digits);

    final res = await _supabase.rpc('rpc_reset_password', params: {
      'p_account_number': accountNumber.trim(),
      'p_clean_phone': cleanPhone.trim(),
      'p_new_hash': newSalted,
    });

    final data = (res is Map<String, dynamic>)
        ? res
        : Map<String, dynamic>.from(res as Map);

    if (data['error'] == 'USER_NOT_FOUND') {
      throw Exception('رقم الحساب غير مسجل في النظام.');
    }
    if (data['error'] == 'OTP_NOT_VERIFIED') {
      throw Exception('انتهت صلاحية جلسة التحقق (OTP)، يرجى إعادة طلب الرمز.');
    }
  }
}
