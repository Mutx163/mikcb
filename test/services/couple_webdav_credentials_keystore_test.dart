import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/couple_webdav_credentials_store.dart';

/// 回归钉（第二十二轮，keystore 读不出密码时整条情侣课表链路冒异常）：
///
/// `CoupleWebdavCredentialsStore.readPassword()`（credentials store :16）是裸
/// `_storage.read(...)`，Android 上 keystore 条目失效（换机恢复、系统升级、
/// 用户凭证变化）时 `FlutterSecureStorage.read` 抛 `PlatformException`。
/// 调用方全部按 `String?` 处理"没有密码"，其中
/// `CoupleWebdavService.pullPartnerTimetable`（couple_webdav_service.dart:113）
/// 把这一跳放在任何 try 之外 —— 而同文件 :138-144 的注释自述本服务
/// 「只返回错误码、从不抛」，那次修复包住了解码与导入，唯独漏了读密码；
/// UI 侧 `_pullPartnerWebdav`（couple_timetable_settings_screen.dart:291-340）
/// 只有 try/finally 没有 catch，同文件的上传路径（:343-368）却有。
/// 用户表现为：点「拉取TA课表」转圈结束、零提示，只能反复点。
///
/// 容错只给**读**：密码此刻已经不可恢复，把它当成「没有存过密码」正好引导
/// 用户重新输入；写与删仍要把异常交出去，那是用户能改的事。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = _BrokenKeystorePlatform();
  });

  test('keystore 失效时读密码返回 null，而不是抛出', () async {
    const store = CoupleWebdavCredentialsStore();

    expect(await store.readPassword(), isNull);
  });

  test('写密码仍然把异常交给调用方', () async {
    const store = CoupleWebdavCredentialsStore();

    await expectLater(
      store.writePassword('secret'),
      throwsA(isA<PlatformException>()),
    );
  });
}

/// 只实现「一律抛 PlatformException」这一件事的 secure storage 平台桩。
class _BrokenKeystorePlatform extends FlutterSecureStoragePlatform {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    throw PlatformException(
      code: 'BAD_DECRYPT',
      message: 'Decode fail. Keystore entry is gone.',
    );
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'BAD_DECRYPT');
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'BAD_ENCRYPT');
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'BAD_DECRYPT');
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    throw PlatformException(code: 'BAD_DECRYPT');
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'BAD_DECRYPT');
  }
}
