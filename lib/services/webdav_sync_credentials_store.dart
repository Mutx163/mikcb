import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebdavSyncCredentialsStore {
  static const String _passwordKey = 'webdav_sync_password';
  static const String _deviceIdKey = 'webdav_sync_device_id';
  static const String _deviceLabelKey = 'webdav_sync_device_label';

  const WebdavSyncCredentialsStore({
    this._storage = _defaultStorage,
  });

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> readPassword() => _storage.read(key: _passwordKey);

  Future<void> writePassword(String password) =>
      _storage.write(key: _passwordKey, value: password);

  Future<void> deletePassword() => _storage.delete(key: _passwordKey);

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final deviceId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<String?> readDeviceLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(_deviceLabelKey);
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    return label.trim();
  }

  Future<void> writeDeviceLabel(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceLabelKey, label.trim());
  }

  Future<void> deleteDeviceLabel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceLabelKey);
  }
}
