import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyDeviceId = 'device_id';
  static const String _keyTelegramUser = 'saved_telegram_user';

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
}
