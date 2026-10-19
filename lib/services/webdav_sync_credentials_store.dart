import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebdavSyncCredentialsStore {
  static const String _passwordKey = 'webdav_sync_password';
  static const String _deviceIdKey = 'webdav_sync_device_id';
  static const String _deviceLabelKey = 'webdav_sync_device_label';

  const WebdavSyncCredentialsStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _defaultStorage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// 读取容错：与 `CoupleWebdavCredentialsStore.readPassword`（couple
  /// 版 :28-34）同一口径 —— keystore 条目失效时（换机恢复、系统升级、
  /// 用户凭证变化）`FlutterSecureStorage.read` 抛 `PlatformException`，
  /// 而调用方一律把 `String?` 理解成「没有存过密码」：
  ///
  /// - `webdav_sync_service.buildConnectionParams`（:177）拿到 null 会返回
  ///   null，云同步按「凭据未配置」停走，引导用户重新输入；
  /// - `testConnection`（:199）拿到 null 抛 `missing_credentials`，同样指向
  ///   重新输入；
  /// - `cloud_sync_screen._loadConfig`（:138）拿到 null 只是 `_hasStoredPassword
  ///   = false`。这里若把异常抛上去，整个配置加载被 catch 降级成
  ///   「未连接」的样子（配置框全部清空）—— 而密码此刻**已不可恢复**，
  ///   按没存过处理正好引导唯一的自救路径：重新输入。
  ///
  /// 写与删仍把异常交出去：那是用户能改的事（磁盘满 / 服务损坏），静默吞掉
  /// 会让「保存成功」变成谎言。
  Future<String?> readPassword() async {
    try {
      return await _storage.read(key: _passwordKey);
    } on PlatformException {
      return null;
    }
  }

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
