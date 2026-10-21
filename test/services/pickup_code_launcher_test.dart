import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/pickup_code_launcher.dart';

/// [PickupCodeNativeChannel] 在「通道没接通」时的行为。
///
/// 为什么这层需要独立测试：它和原生之间的唯一约定就是通道名，而**通道名写岔
/// 了不会编译失败、也不会让任何 widget 测试变红**——它只在真机点下去时表现成
/// 「当前平台不支持跳到其它应用」。2026-10-20 改名时 Dart 侧改成 `pickup_code`、
/// Kotlin 侧还留着 `campus_tools`，整页 7 条入口全挂在这个误报上。
/// `pickup_codes_wiring_test.dart` 用源码字符串钉住了「两侧名字一致」，
/// 这里再钉住「名字不一致时 Dart 侧不乱编结果」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // `supported` 看的是 defaultTargetPlatform：测试默认跑在宿主平台（桌面
    // 上是 windows），不覆盖的话所有调用都会在 `if (!supported)` 那里直接
    // 返回 unsupported，根本走不到通道，测试就成了空转。
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('通道未注册（MissingPluginException）', () {
    test('installedPackages 抛异常，不把「查不到」谎报成「一个都没装」', () async {
      // 空集合的语义是「查过了，确实一个都没装」：页面据此把每条入口降成灰态，
      // 执行器也会跳过所有 App 兜底。查不到必须区分开，否则用户看到的是
      // 「你什么都没装」，而不是「我们没查成」。
      await expectLater(
        const PickupCodeNativeChannel().installedPackages(const <String>[
          'com.taobao.taobao',
        ]),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('launchUri 仍归成 unsupported（这一条是「点了没反应」的兜底文案）', () async {
      final result = await const PickupCodeNativeChannel().launchUri(
        uri: 'cainiao://page/parcel',
      );
      expect(result.ok, isFalse);
      expect(result.reason, 'unsupported');
    });

    test('canResolve 返回 false 而不是抛出去（体检不该让整页崩）', () async {
      expect(
        await const PickupCodeNativeChannel().canResolve(uri: 'cainiao://x'),
        isFalse,
      );
    });
  });
}
