// [TimedMethodChannel] 的超时行为守卫。
//
// 为什么要有这条：这层包装的全部价值在于「原生不回话时不会永远卡住」，而这件事
// 在真机上要等主线程卡住才复现得到，没法靠肉眼盯。测试里把 handler 换成永不完成
// 的 Future，就把「安静卡死」变成了确定性的失败。
//
// 同时钉住一个更隐蔽的约定：**超时时抛的是 `PlatformException` 而不是
// `TimeoutException`**。全仓 18 处调用点只捕获 `PlatformException`、另有 13 处
// 就近没有 catch —— 换成 `TimeoutException` 会凭空多出 31 个未处理异步错误，把
// 「安静卡住」升级成「突然抛错」。这条断言就是防止有人日后觉得「语义上应该是
// TimeoutException」而顺手改回去。
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/timed_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = TimedMethodChannel(
    'com.mutx163.qingyu/test_timed_channel',
    timeout: Duration(milliseconds: 50),
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// 装一个 handler，返回值由 [responder] 决定。
  void mock(Future<Object?> Function(MethodCall call) responder) {
    messenger.setMockMethodCallHandler(channel, (call) => responder(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('正常路径不受影响', () {
    test('invokeMethod 原样回传原生结果', () async {
      mock((_) async => 42);
      expect(await channel.invokeMethod<int>('answer'), 42);
    });

    test('invokeListMethod / invokeMapMethod 原样回传', () async {
      mock((_) async => <Object?>['a', 'b']);
      expect(await channel.invokeListMethod<String>('list'), ['a', 'b']);

      mock((_) async => <Object?, Object?>{'k': 'v'});
      expect(await channel.invokeMapMethod<String, String>('map'), {'k': 'v'});
    });

    test('原生明确报错时，异常类型与 code 不被改写', () async {
      mock((_) async => throw PlatformException(code: 'NATIVE_ERR'));
      await expectLater(
        channel.invokeMethod<int>('boom'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'NATIVE_ERR',
          ),
        ),
      );
    });

    test('原生回 null 时回 null，不是超时', () async {
      mock((_) async => null);
      expect(await channel.invokeMethod<int>('nothing'), isNull);
    });
  });

  group('原生不回话时按超时收口', () {
    test('invokeMethod 抛 PlatformException(TIMEOUT)，而不是挂住', () async {
      // 永不完成的 Future = 原生主线程被占住的等价物。
      mock((_) => Completer<Object?>().future);

      await expectLater(
        channel.invokeMethod<int>('hang'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', kPlatformChannelTimeoutCode)
              // 消息里要带通道名与方法名：真机出问题时日志里只有这一句可看。
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains(channel.name),
                  contains('hang'),
                ),
              ),
        ),
      );
    });

    test('invokeListMethod / invokeMapMethod 同样有上限', () async {
      mock((_) => Completer<Object?>().future);
      await expectLater(
        channel.invokeListMethod<String>('hang'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', kPlatformChannelTimeoutCode),
        ),
      );

      mock((_) => Completer<Object?>().future);
      await expectLater(
        channel.invokeMapMethod<String, String>('hang'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', kPlatformChannelTimeoutCode),
        ),
      );
    });

    test('超时时抛的不是 TimeoutException（既有 catch 才接得住）', () async {
      mock((_) => Completer<Object?>().future);
      // 这条与上面那条互为注解：如果哪天有人改成抛 TimeoutException，
      // 只捕获 PlatformException 的 18 处调用点会全部漏接。
      await expectLater(
        channel.invokeMethod<int>('hang'),
        throwsA(isNot(isA<TimeoutException>())),
      );
    });

    test('慢但在阈值内的调用不算超时', () async {
      // 阈值 50ms，睡 10ms：确认超时不是「立即返回」的伪实现。
      mock((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'ok';
      });
      expect(await channel.invokeMethod<String>('slow'), 'ok');
    });
  });

  group('默认超时值', () {
    test('是 10s，且不影响自定义阈值的通道', () {
      expect(kPlatformChannelTimeout, const Duration(seconds: 10));
      expect(channel.timeout, const Duration(milliseconds: 50));
    });
  });
}
