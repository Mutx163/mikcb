// 测试需要直接劫持平台层才能读到运行时实际生效的 options；该包是
// flutter_secure_storage 的传递依赖，未在 pubspec 里直接声明。
// 与 `test/screens/warehouse_web_login_glass_gate_test.dart:2` 同一处置
// （那里也用同一个 ignore 做同样的事）。
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/couple_webdav_credentials_store.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/webdav_sync_credentials_store.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

/// A1：三处凭证存储必须显式传 `AndroidOptions(resetOnError: false)`。
///
/// ## 为什么这条测试值得存在
///
/// flutter_secure_storage 的默认值是 `resetOnError: true`，它的语义不是「忽略错误」，
/// 而是**删光数据再重试**（10.3.4 的 `FlutterSecureStorage.java:1117/1135/1486`）。
/// 三处 store 存的分别是坚果云密码、情侣网盘密码、教务账号密码——**删除即永久丢失**。
///
/// 默认值一旦被人「简化」回去，代码照样能编译、单测照样能过、功能看起来也正常，
/// 只有在真实故障（换机、系统升级、用户改锁屏密码）那一刻才会暴露，而那时候
/// 用户的数据已经没了。**这种「静默退化」必须由测试钉住。**
///
/// ## 为什么劫持平台层而不是读源码
///
/// `AndroidOptions` 是 const 对象，三处都是 `static const` 私有字段，外部读不到。
/// 但插件在真正调用平台通道时会把 options 序列化成 `Map<String, String>` 传下去
/// （`AndroidOptions.toMap()`），其中 `resetOnError` 键就是我们要钉的值。
/// 拦截这一层等于断言「**运行时实际生效**的配置」，比读源码字符串更硬。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStoragePlatform previous;
  late _CapturingSecureStoragePlatform platform;

  setUp(() {
    StorageService().resetForTesting();
    previous = FlutterSecureStoragePlatform.instance;
    platform = _CapturingSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance = previous;
  });

  /// 断言本轮捕获到的所有调用都带着 resetOnError=false。
  ///
  /// 空捕获视为失败：说明被测代码根本没打到平台层（测试空转）。
  void expectResetOnErrorFalse(String label) {
    expect(
      platform.capturedOptions,
      isNotEmpty,
      reason: '$label：没有捕获到任何平台调用，测试空转，检查调用路径是否还走 secure storage',
    );
    for (final captured in platform.capturedOptions) {
      expect(
        captured['resetOnError'],
        'false',
        reason:
            '$label：secure storage 调用的 resetOnError 不是 false。'
            '插件默认 true 会在出错时删光用户凭证'
            '（FlutterSecureStorage.java:1117/1135/1486），'
            '这三处存的是坚果云/情侣网盘/教务账号密码，删除即永久丢失。',
      );
    }
  }

  test('CoupleWebdavCredentialsStore 写密码时 resetOnError 为 false', () async {
    const store = CoupleWebdavCredentialsStore();
    await store.writePassword('partner-secret');

    expectResetOnErrorFalse('CoupleWebdavCredentialsStore.writePassword');
  });

  test('WebdavSyncCredentialsStore 写密码时 resetOnError 为 false', () async {
    const store = WebdavSyncCredentialsStore();
    await store.writePassword('nutstore-secret');

    expectResetOnErrorFalse('WebdavSyncCredentialsStore.writePassword');
  });

  test('WebdavSyncCredentialsStore 读设备 id 时 resetOnError 为 false', () async {
    // getOrCreateDeviceId 内部会先 read 再 write，两条路径都要带同样的 options。
    const store = WebdavSyncCredentialsStore();
    await store.getOrCreateDeviceId();

    expect(platform.capturedOptions.length, greaterThanOrEqualTo(2),
        reason: 'getOrCreateDeviceId 应至少产生 read + write 两次平台调用');
    expectResetOnErrorFalse('WebdavSyncCredentialsStore.getOrCreateDeviceId');
  });

  test('FlutterWarehouseSecureStorage 写教务凭据时 resetOnError 为 false',
      () async {
    const storage = FlutterWarehouseSecureStorage();
    await storage.write(key: 'warehouse_login', value: 'edu-secret');

    expectResetOnErrorFalse('FlutterWarehouseSecureStorage.write');
  });

  test('三处 store 的 resetOnError 配置同源，不允许单点漂移', () async {
    // 三个 store 各自持有一份 `static const _defaultStorage`。它们必须一致：
    // 只改一处、漏掉另外两处，正是这类配置最容易出的错。
    await const CoupleWebdavCredentialsStore().writePassword('a');
    await const WebdavSyncCredentialsStore().writePassword('b');
    await const FlutterWarehouseSecureStorage().write(
      key: 'warehouse_login',
      value: 'c',
    );

    final values = platform.capturedOptions
        .map((options) => options['resetOnError'])
        .toSet();
    expect(
      values,
      {'false'},
      reason: '三处 store 的 resetOnError 出现分歧：$values。'
          '任何一处回退到插件默认值（true）都会让该处凭证在故障时被静默删除。',
    );
  });
}

/// 捕获每次平台调用收到的 options map。
class _CapturingSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final List<Map<String, String>> capturedOptions = <Map<String, String>>[];

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    capturedOptions.add(Map<String, String>.of(options));
    return Future<String?>.value();
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) {
    capturedOptions.add(Map<String, String>.of(options));
    return Future<Map<String, String>>.value(const <String, String>{});
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    capturedOptions.add(Map<String, String>.of(options));
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    capturedOptions.add(Map<String, String>.of(options));
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    capturedOptions.add(Map<String, String>.of(options));
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) {
    capturedOptions.add(Map<String, String>.of(options));
    return Future<bool>.value(false);
  }
}
