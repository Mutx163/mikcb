import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Separate from [WebdavSyncCredentialsStore] so couple pull and cloud sync
/// never share Nutstore credentials.
class CoupleWebdavCredentialsStore {
  static const String _passwordKey = 'couple_webdav_password';

  const CoupleWebdavCredentialsStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? _defaultStorage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// 读取容错：keystore 条目失效时（换机恢复、系统升级、用户凭证变化）
  /// `FlutterSecureStorage.read` 抛 `PlatformException`，而四个调用方
  /// （`couple_webdav_service.dart:50/:91/:113/:218`）一律按 `String?`
  /// 理解成「没有存密码」。其中 `pullPartnerTimetable` 的这一跳在任何 try
  /// 之外，而该文件自述本服务「只返回错误码、从不抛」
  /// （:138-144，那次修复包住了解码与导入、漏了读密码），UI 侧
  /// `_pullPartnerTimetable` 又只有 try/finally —— 表现为点了「拉取TA课表」
  /// 转圈结束、零提示。
  ///
  /// 密码在这一刻已经**不可恢复**，把它当作「没有存过密码」正好引导用户
  /// 重新输入；写与删仍把异常交出去，那是用户能改的事，不能静默吞掉。
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
}
