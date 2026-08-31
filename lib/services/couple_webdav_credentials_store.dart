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

  Future<String?> readPassword() => _storage.read(key: _passwordKey);

  Future<void> writePassword(String password) =>
      _storage.write(key: _passwordKey, value: password);

  Future<void> deletePassword() => _storage.delete(key: _passwordKey);
}
