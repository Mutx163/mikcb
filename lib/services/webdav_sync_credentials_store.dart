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

  // ⚠️ 显式传 AndroidOptions(resetOnError: false)，**不要**改回默认值。
  //
  // 插件默认 `resetOnError: true`，出错时它会**删光所有凭证再重试**——
  // 见 flutter_secure_storage 10.3.4 的 Android 实现：
  //   FlutterSecureStorage.java:1117  "resetOnError is enabled. Deleting all data as fallback..."
  //   FlutterSecureStorage.java:1135  密钥不匹配时同样 deleteAllDataAndKeys()
  //   FlutterSecureStorage.java:1486  handleStorageError()：任何 read/write 异常
  //                                   都会先 delete(key) / deleteAll() 再重试
  //
  // 这里存的是**用户唯一凭证**（坚果云密码 / 情侣网盘密码 / 教务账号密码），
  // 删除即永久丢失。而密钥失效在本仓是**已知会发生**的故障（换机恢复、系统升级、
  // 用户凭证变化，见本文件 readPassword 上方注释），删掉的后果是用户打开 App 发现
  // 「从来没配置过」——连账号名都不记得了。
  //
  // 设为 false 后：出错抛 PlatformException，由本文件既有的
  // `on PlatformException → return null` 容错接住，退化为「当作没存过、引导重输」，
  // **数据保留、临时故障可自愈**。这是 2026-10-20 由用户本人拍板的取舍。
  //
  // 只动错误处置，**不要顺手改** storageNamespace / sharedPreferencesName /
  // 加密算法——那几个会改变数据实际存放位置或解密方式，动了就是真迁移风险。
  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

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
