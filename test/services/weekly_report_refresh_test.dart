import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/weekly_report_service.dart';

/// 回归钉（第二十六轮，周报正文只在拨开关那一刻生成一次，原生却按同一份文案
/// 每周重发）：
///
/// 原生 `WeeklyReportScheduler.kt:164-171` 投递成功后只推进 `KEY_FIRE_AT`，
/// `KEY_TITLE`/`KEY_BODY` 原样留着；它自己的契约注释（:17-20）要求 Flutter
/// "whenever the toggle **or the timetable changes**" 都重推。Dart 侧原先只有
/// `statistics_settings_screen.dart:69-86` 那一处（拨开关），于是正文永久冻结在
/// 拨开关那一周 —— 学期第 16 周还弹"第 8 周 · 共 12 节"，换课表后照旧。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mutx163.qingyu/weekly_report');
  var scheduleNextCalls = 0;
  final bodies = <String?>[];

  late TimetableProvider provider;

  Course course(String id, {int dayOfWeek = 1, int startSection = 1}) => Course(
    id: id,
    name: '课程$id',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: startSection,
    startTime: '08:00',
    endTime: '08:45',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduleNextCalls = 0;
    bodies.clear();
    resetWeeklyReportPushCacheForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'scheduleNext') {
            scheduleNextCalls++;
            bodies.add(call.arguments is Map
                ? (call.arguments as Map)['body'] as String?
                : null);
          }
          return null;
        });
    provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('开着周报时，加一门课会把新正文重推给原生', () async {
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: true),
    );
    final afterToggle = scheduleNextCalls;
    expect(afterToggle, greaterThan(0), reason: '拨开关本身就该推一次（既有行为）');

    await provider.addCourse(course('c1'));
    await pumpChannelQueue();

    expect(
      scheduleNextCalls,
      greaterThan(afterToggle),
      reason: '课表变了必须重推；修复前这里恒等于 afterToggle —— 正文永久冻结',
    );
  });

  test('内容没变的保存不去碰原生闹钟', () async {
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: true),
    );
    await provider.addCourse(course('c1'));
    await pumpChannelQueue();
    final afterFirst = scheduleNextCalls;
    final body = bodies.last;

    // 一次与课表内容无关的设置写入：内容签名相同 → 不该再推。
    await provider.updateSettings(
      provider.settings.copyWith(weeklyReportEnabled: true),
    );
    await pumpChannelQueue();

    expect(scheduleNextCalls, afterFirst, reason: '去重按渲染出的正文，不按保存次数');
    expect(body, isNotNull);
    expect(body, contains('1'), reason: '正文里必须带上当前的周数与节数');
  });

  test('没开周报时任何保存都不推', () async {
    await provider.addCourse(course('c1'));
    await pumpChannelQueue();
    expect(scheduleNextCalls, 0);
  });
}

/// 让 `unawaited` 的通道调用跑到完成：微任务队列排空即可（MockHandler 是同步返回）。
Future<void> pumpChannelQueue() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
