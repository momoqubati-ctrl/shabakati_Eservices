import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/user_account_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyDeviceId = 'device_id';
  static const String _keyTelegramUser = 'saved_telegram_user';
  static const String _keyActiveUser = 'saved_active_user_data';
  static const String _keySessionExpiresAt = 'saved_session_expires_at';
  static const String _keyOnboardingSeen = 'has_seen_onboarding_v1';

  static const Duration defaultSessionDuration = Duration(hours: 4);

  /// هل شاهد المستخدم شاشات التعريف والترحيب مسبقاً؟
  Future<bool> hasSeenOnboarding() async {
    final val = await _storage.read(key: _keyOnboardingSeen);
    return val == 'true';
  }

  /// تعيين شاشات التعريف والترحيب كمشاهدة
  Future<void> setOnboardingSeen() async {
    await _storage.write(key: _keyOnboardingSeen, value: 'true');
  }

  /// إعادة تعيين حالة شاشات التعريف (لإمكانية استعراضها مجدداً)
  Future<void> resetOnboardingSeen() async {
    await _storage.delete(key: _keyOnboardingSeen);
  }

  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'dev_${const Uuid().v4()}';
      await _storage.write(key: _keyDeviceId, value: deviceId);
    }
    return deviceId;
  }

  Future<void> saveTelegramUser(String username) async {
    await _storage.write(key: _keyTelegramUser, value: username);
  }

  Future<String?> getSavedTelegramUser() async {
    return await _storage.read(key: _keyTelegramUser);
  }

  Future<void> saveActiveUser(UserAccountModel user) async {
    final jsonStr = jsonEncode({
      'id': user.id,
      'account_number': user.accountNumber,
      'dial_code': user.dialCode,
      'phone_national': user.phoneNational,
      'full_name': user.fullName,
      'region': user.region,
      'is_verified': user.isVerified,
      'biometric_enabled': user.biometricEnabled,
      'created_at': user.createdAt.toIso8601String(),
      if (user.sessionToken != null) 'session_token': user.sessionToken,
    });
    await _storage.write(key: _keyActiveUser, value: jsonStr);
    await extendSession();
  }

  /// تمديد صلاحية الجلسة الحالية
  Future<void> extendSession({Duration duration = defaultSessionDuration}) async {
    final expiresAt = DateTime.now().add(duration);
    await _storage.write(key: _keySessionExpiresAt, value: expiresAt.toIso8601String());
  }

  /// جلب وقت وتاريخ انتهاء الجلسة الحالي
  Future<DateTime?> getSessionExpiry() async {
    final str = await _storage.read(key: _keySessionExpiresAt);
    if (str == null || str.isEmpty) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  /// هل الجلسة الحالية سارية المفعول ولم تنتهِ صلاحيتها؟
  Future<bool> isSessionValid() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// الوقت المتبقي لانتهاء صلاحية الجلسة
  Future<Duration> getRemainingSessionTime() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return Duration.zero;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// إنهاء صلاحية الجلسة يدوياً
  Future<void> expireSession() async {
    await _storage.delete(key: _keySessionExpiresAt);
  }

  Future<UserAccountModel?> getActiveUser() async {
    final jsonStr = await _storage.read(key: _keyActiveUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserAccountModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveUser() async {
    await _storage.delete(key: _keyActiveUser);
    await _storage.delete(key: _keySessionExpiresAt);
  }

  /// حفظ المفتاح المسلّم محلياً لضمان عدم فقدانه أو اعتماده فقط على قاعدة البيانات
  Future<void> saveDeliveredAsset(String orderIdOrExternal, String key, [String? url]) async {
    final cacheKey = 'delivered_asset_$orderIdOrExternal';
    await _storage.write(key: cacheKey, value: jsonEncode({'key': key, 'url': url}));
  }

  /// استرجاع المفتاح المسلّم محلياً
  Future<Map<String, String?>?> getDeliveredAsset(String orderIdOrExternal) async {
    final cacheKey = 'delivered_asset_$orderIdOrExternal';
    final str = await _storage.read(key: cacheKey);
    if (str == null || str.isEmpty) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return {'key': map['key']?.toString(), 'url': map['url']?.toString()};
    } catch (_) {
      return null;
    }
  }

  /// مسح نهائي وشامل لكافة بيانات التطبيق والتخزين المشفر عند تسجيل الخروج النهائي
  Future<void> wipeAllData() async {
    await _storage.deleteAll();
    // إنشاء معرف جهاز جديد ونظيف للجلسات اللاحقة
    final newDeviceId = 'dev_${const Uuid().v4()}';
    await _storage.write(key: _keyDeviceId, value: newDeviceId);
  }
}

