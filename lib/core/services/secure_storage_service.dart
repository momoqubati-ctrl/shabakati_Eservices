import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/user_account_model.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyDeviceId = 'device_id';
  static const String _keyTelegramUser = 'saved_telegram_user';
  static const String _keyActiveUser = 'saved_active_user_data';

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
    });
    await _storage.write(key: _keyActiveUser, value: jsonStr);
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
  }
}

