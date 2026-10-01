import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthBiometricService {
  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  static const String _keyBiometricEnabled = 'biometric_login_enabled';
  static const String _keySavedAccount = 'saved_account_number';
  static const String _keySavedPasswordHash = 'saved_password_hash';
  static const String _keySavedUserName = 'saved_user_name';
  static const String _keySavedRegion = 'saved_user_region';

  AuthBiometricService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// هل الجهاز يدعم البصمة أو التعرف على الوجه؟
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// هل المستخدم قام بتفعيل الدخول بالبصمة سابقاً؟
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    final savedAccount = await _secureStorage.read(key: _keySavedAccount);
    return enabled == 'true' && savedAccount != null && savedAccount.isNotEmpty;
  }

  /// تفعيل أو تعطيل خيار البصمة وحفظ البيانات
  Future<void> setBiometricEnabled({
    required bool enabled,
    String? accountNumber,
    String? passwordHash,
    String? userName,
    String? region,
  }) async {
    if (enabled) {
      await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
      if (accountNumber != null) {
        await _secureStorage.write(key: _keySavedAccount, value: accountNumber);
      }
      if (passwordHash != null) {
        await _secureStorage.write(key: _keySavedPasswordHash, value: passwordHash);
      }
      if (userName != null) {
        await _secureStorage.write(key: _keySavedUserName, value: userName);
      }
      if (region != null) {
        await _secureStorage.write(key: _keySavedRegion, value: region);
      }
    } else {
      await _secureStorage.delete(key: _keyBiometricEnabled);
      await _secureStorage.delete(key: _keySavedPasswordHash);
    }
  }

  /// جلب رقم الحساب المخزن للبصمة
  Future<String?> getSavedAccount() async {
    return await _secureStorage.read(key: _keySavedAccount);
  }

  Future<String?> getSavedPasswordHash() async {
    return await _secureStorage.read(key: _keySavedPasswordHash);
  }

  Future<String?> getSavedUserName() async {
    return await _secureStorage.read(key: _keySavedUserName);
  }

  Future<String?> getSavedRegion() async {
    return await _secureStorage.read(key: _keySavedRegion);
  }

  /// تنفيذ فحص البصمة الفعلي
  Future<bool> authenticateWithBiometrics({String reason = 'المصادقة لتسجيل الدخول إلى حسابك'}) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (_) {
      return false;
    }
  }

  /// مسح بيانات الجلسة عند تسجيل الخروج
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _keySavedPasswordHash);
    await _secureStorage.delete(key: _keyBiometricEnabled);
  }
}
