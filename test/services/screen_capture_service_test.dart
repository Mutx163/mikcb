import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/screen_capture_service.dart';

/// 截屏检测的 Dart 侧契约。
///
/// 原生侧（Android 14 的 `registerScreenCaptureCallback`）只能在真机上验，
/// 这里钉住的是 Dart 侧的三件事：能力判定、引用计数、以及原生事件确实会被
/// 送到订阅者手里。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/screen_capture');
  final calls = <MethodCall>[];

  void stubChannel({required bool supported}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isSupported' => supported,
            'start' || 'stop' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  /// 模拟原生侧把「刚截了一张」投回 Dart。
  Future<void> emitNativeScreenshot() {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onScreenshot'),
          ),
          (ByteData? _) {},
        );
  }

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ScreenCaptureService.resetForTesting();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ScreenCaptureService.resetForTesting();
  });

  test('Android 14 以下（原生报不支持）不注册监听', () async {
    stubChannel(supported: false);

    await ScreenCaptureService.start();

    expect(ScreenCaptureService.isSupported, isFalse);
    expect(calls.map((call) => call.method), isNot(contains('start')));
  });

  test('支持时注册监听，原生事件到达订阅者', () async {
    stubChannel(supported: true);
    final events = <void>[];
    final subscription = ScreenCaptureService.onScreenshot.listen(events.add);
    addTearDown(subscription.cancel);

    await ScreenCaptureService.start();
    expect(calls.map((call) => call.method), contains('start'));

    await emitNativeScreenshot();
    expect(events, hasLength(1));

    await ScreenCaptureService.stop();
    expect(calls.map((call) => call.method), contains('stop'));

    // 卸载后事件不该再进来。
    await emitNativeScreenshot();
    expect(events, hasLength(1));
  });

  test('引用计数：先走的调用方不会把还在听的调用方一起关掉', () async {
    stubChannel(supported: true);

    await ScreenCaptureService.start();
    await ScreenCaptureService.start();
    expect(
      calls.where((call) => call.method == 'start'),
      hasLength(1),
      reason: '第二个调用方复用已注册的回调',
    );

    await ScreenCaptureService.stop();
    expect(
      calls.map((call) => call.method),
      isNot(contains('stop')),
      reason: '还有一个调用方在听',
    );

    await ScreenCaptureService.stop();
    expect(calls.where((call) => call.method == 'stop'), hasLength(1));
  });

  test('未监听时 stop 是空操作', () async {
    stubChannel(supported: true);

    await ScreenCaptureService.stop();

    expect(calls, isEmpty);
  });

  test('非 Android 平台直接判定为不支持，不碰原生通道', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    stubChannel(supported: true);

    expect(await ScreenCaptureService.ensureSupported(), isFalse);
    expect(calls, isEmpty);
  });
}
