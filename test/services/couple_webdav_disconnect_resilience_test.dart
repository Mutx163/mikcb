import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/couple_webdav_config.dart';
import 'package:university_timetable/services/couple_webdav_credentials_store.dart';
import 'package:university_timetable/services/couple_webdav_service.dart';

/// 「断开情侣云盘」不能被 keystore 故障卡死（第 35 轮）。
///
/// `CoupleWebdavService.disconnect()` 原先第一跳就是 `deletePassword()`，而 keystore
/// 条目失效时（换机恢复、系统升级、凭证变化）它抛 `PlatformException`
/// —— 同文件 `readPassword` 的注释记的就是这个失效面，那次修复只给**读**加了容错。
/// 抛出后用户名与 `lastPulledAt` 都没清，页面按 `username` 非空判"仍已连接"
/// （`couple_timetable_settings_screen.dart:65-67`），而按钮写的是
/// `onPressed: _disconnectCoupleWebdav`（:240 的 tear-off，Future 被丢掉）——
/// 用户反复点「断开连接」，什么都不发生，也没有任何提示。
class _DeleteFailingCredentials extends CoupleWebdavCredentialsStore {
  _DeleteFailingCredentials();

  int deleteCalls = 0;

  @override
  Future<void> deletePassword() async {
    deleteCalls++;
    throw PlatformException(
      code: 'BAD_DECRYPT',
      message: 'Keystore entry is gone.',
    );
  }
}

/// 删密码成功的对照组：确认"尽力删除"这一步在正常情况下确实执行了。
class _RecordingCredentials extends CoupleWebdavCredentialsStore {
  _RecordingCredentials();

  int deleteCalls = 0;

  @override
  Future<void> deletePassword() async {
    deleteCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('keystore 删不掉密码时，仍然清掉连接状态', () async {
    final credentials = _DeleteFailingCredentials();
    final service = CoupleWebdavService(credentialsStore: credentials);
    final base = await service.loadConfig();
    await service.saveConfig(base.copyWith(username: 'ta@corp.cn'));
    expect((await service.loadConfig()).username, 'ta@corp.cn');

    await service.disconnect();

    final after = await service.loadConfig();
    expect(after.username, isEmpty, reason: '删密码失败不能挡住"断开"本身');
    expect(credentials.deleteCalls, 1, reason: '仍然要尽力去删那份密码');
  });

  test('正常情况断开后回到未连接形态，且确实去删了密码', () async {
    final credentials = _RecordingCredentials();
    final service = CoupleWebdavService(credentialsStore: credentials);
    final base = await service.loadConfig();
    await service.saveConfig(base.copyWith(username: 'me@corp.cn'));

    await service.disconnect();

    expect((await service.loadConfig()).username, isEmpty);
    expect(credentials.deleteCalls, 1);
  });
}
