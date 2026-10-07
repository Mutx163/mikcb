import 'dart:async';
import 'dart:io' show HttpOverrides;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// App 自有的全部平台通道名。
///
/// 由 `lib/` 里 `MethodChannel('com.mutx163.qingyu/…')` 的声明汇总而来。
/// 新增通道时**记得同步补进来**——少一个就等于给 CI 留一颗定时器地雷。
const List<String> kAppPlatformChannels = <String>[
  'com.mutx163.qingyu/calendar_sync',
  'com.mutx163.qingyu/exam_reminder',
  'com.mutx163.qingyu/fair_memory',
  'com.mutx163.qingyu/frosted_blur',
  'com.mutx163.qingyu/home_widget',
  'com.mutx163.qingyu/lan_edit',
  'com.mutx163.qingyu/launch_url',
  'com.mutx163.qingyu/location',
  'com.mutx163.qingyu/memory_stats',
  'com.mutx163.qingyu/migration',
  'com.mutx163.qingyu/miui_live',
  'com.mutx163.qingyu/screen_capture',
  'com.mutx163.qingyu/support',
  'com.mutx163.qingyu/system_alarm',
  'com.mutx163.qingyu/system_ui',
  'com.mutx163.qingyu/umeng_analytics',
  'com.mutx163.qingyu/weekly_report',
];

/// 给上面这些通道装一个「立刻回包」的兜底处理器。
///
/// ## 为什么必须有它
///
/// 「探测型」平台通道在测试环境里**没有原生回包**：`invokeMethod` 的消息发进
/// channel buffer 后，reply 永远不会到来，那个 Future 就挂死。TimedMethodChannel
/// 加超时（fb8f1258）之前，这只是静默悬挂、无人在意；加了超时之后，每次探测
/// 都会在 FakeAsync 区里留一个 10s 的假 Timer，`testWidgets` 收尾的
/// `!timersPending` 不变量断言必炸（2026-10-01 实测；2026-10-06 CI 上一次
/// 「Analyze and Test」挂掉 143 例，两套 Flutter 版本都是）。
///
/// 给这类通道一个**即时回包**，调用方走正常完成路径：`Future.timeout` 的
/// 计时器当场取消，测试收尾干净。
///
/// ## 为什么回 `null` 而不是抛 `MissingPluginException`
///
/// 抛异常也能让 Future 当场完成，但会给调用点凭空塞进一条它本来走不到的异常
/// 路径——`ScreenCaptureService.ensureSupported` 之类已经自己写了
/// `on MissingPluginException` 的地方没事，**没写 catch 的地方就会变成未处理
/// 异步错误**。回 `null` 同样能取消计时器，却不改变任何异常语义。
/// 需要验证具体回包的测试文件自己登记 handler，会顶掉这份兜底。
void _installPlatformChannelStubs() {
  // 关键前提：**只在本文件本来就会有 binding 时**才装。
  //
  // `AutomatedTestWidgetsFlutterBinding` 构造时会 `setupHttpOverrides()`，把
  // `HttpOverrides.global` 换成恒回 400 的假客户端（flutter_test 的
  // `_binding_io.dart`）。而 `app_update_service_test.dart` 用 `HttpServer.bind`
  // 起真实本地服务器做下载测试，且它是纯 `test()` 文件、自己不建 binding——
  // 一旦这里替它把 binding 建起来，那 5 条下载用例会全部拿到 400。
  //
  // `HttpOverrides.current != null` 就是「binding 已经存在」的可靠信号：
  // `testWidgets()` 在**注册时**就会 `ensureInitialized()`，所以跑到 `setUp`
  // 时它一定已经就位；而纯 `test()` 且从不 `ensureInitialized` 的文件这里仍是
  // null，于是原样放行，真实本地 HTTP 照旧可用。
  if (HttpOverrides.current == null) return;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in kAppPlatformChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

/// flutter_test 的每文件约定入口：装载任何测试前先跑一次。
///
/// **刻意不在这里调 `TestWidgetsFlutterBinding.ensureInitialized()`** ——
/// 那会给每个测试文件都装上 flutter_test 的假 HttpClient，把
/// `app_update_service_test.dart` 里 5 条起真实本地服务器的下载用例打成 400。
/// 兜底改在 `setUp` 里按需安装，见 [_installPlatformChannelStubs]。
///
/// 各测试文件自己 `setMockMethodCallHandler` 的（如 `screen_capture_service_test.dart`）
/// 不受影响：它们登记的同通道处理器会顶掉这里这份。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 逐个用例重装一次：全仓有 30 多个测试文件在 `tearDown` 里把 handler 置回
  // `null`，那等于把兜底一起摘掉——同一文件后续用例再碰到这些通道就会重新挂死。
  // 本文件这份 `setUp` 注册在最外层，先于各测试文件自己的 `setUp` 执行，
  // 所以它们仍然照旧能顶掉兜底。
  setUp(_installPlatformChannelStubs);
  await testMain();
}