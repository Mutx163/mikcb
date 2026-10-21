import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/controllers/course_auto_refresh_controller.dart';
import 'package:university_timetable/domain/course_auto_refresh_decision.dart';
import 'package:university_timetable/services/course_auto_refresh_store.dart';

/// 自动更新的**编排**（判定 → 跑 → 记账 → 给结局）。
///
/// 期望值一律是「用户会遇到的情形」推出来的：关着不动、没到点不动、没配好不动、
/// 跑成功记成功、跑失败**也要**记尝试（否则下次打开立刻重来）、内容没变不打扰。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CourseAutoRefreshStore.resetForTesting();
  });

  /// 造一个已加载的 store，并写入上次时间。
  Future<CourseAutoRefreshStore> loadedStore({
    CourseAutoRefreshSchedule schedule = const CourseAutoRefreshSchedule(),
    DateTime? lastSuccess,
    DateTime? lastAttempt,
  }) async {
    final store = CourseAutoRefreshStore.instance;
    await store.load();
    await store.saveSchedule(schedule);
    if (lastSuccess != null) {
      await store.recordSuccess(lastSuccess);
    }
    if (lastAttempt != null) {
      // 直接走 recordAttempt：它把「尝试」写得比「成功」晚，正是「上次失败」的
      // 形态。先成功、后尝试 —— 顺序不能反。
      await store.recordAttempt(lastAttempt);
    }
    return store;
  }

  CourseAutoRefreshController build({
    required Future<bool> Function() runImport,
    String Function()? signature,
    Future<bool> Function()? preflight,
    DateTime Function()? now,
    void Function(CourseAutoRefreshOutcome)? onOutcome,
  }) {
    final current = signature ?? () => 'sig-0';
    return CourseAutoRefreshController(
      runImport: runImport,
      captureSignature: current,
      preflight: preflight,
      onOutcome: onOutcome,
      now: now,
    );
  }

  group('功能关闭', () {
    test('默认关着：一次都不跑', () async {
      await loadedStore();
      var calls = 0;
      final controller = build(
        runImport: () async {
          calls++;
          return true;
        },
      );
      expect(
        await controller.maybeRunNow(),
        CourseAutoRefreshOutcome.disabled,
      );
      expect(calls, 0);
    });
  });

  group('没到点', () {
    test('刚成功过 → 不跑', () async {
      final now = DateTime(2026, 10, 21, 9, 5);
      await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
        lastSuccess: DateTime(2026, 10, 21, 9),
      );
      var calls = 0;
      final controller = build(
        now: () => now,
        runImport: () async {
          calls++;
          return true;
        },
      );
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.notDue);
      expect(calls, 0);
    });
  });

  group('可运行性检查', () {
    test('没配过快捷导入（preflight 假）→ noSource，且**不记**尝试时间', () async {
      await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      var calls = 0;
      final controller = build(
        preflight: () async => false,
        runImport: () async {
          calls++;
          return true;
        },
      );
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.noSource);
      expect(calls, 0);
      expect(
        CourseAutoRefreshStore.instance.lastAttemptAt,
        isNull,
        reason: '「还没配好」不该算一次尝试：记了就会让用户配好后还要干等半小时',
      );
    });
  });

  group('跑完的结局', () {
    test('内容变了 → updated，并记成功', () async {
      final now = DateTime(2026, 10, 21, 9);
      final store = await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      var signature = 'sig-before';
      final outcomes = <CourseAutoRefreshOutcome>[];
      final controller = build(
        now: () => now,
        signature: () => signature,
        runImport: () async {
          signature = 'sig-after';
          return true;
        },
        onOutcome: outcomes.add,
      );
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.updated);
      expect(store.lastSuccessAt, now);
      expect(outcomes, <CourseAutoRefreshOutcome>[
        CourseAutoRefreshOutcome.updated,
      ], reason: '只有「拿到新课表」与「失败」该让用户知道');
    });

    test('内容没变 → unchanged，但**照样**记成功（否则每次都重抓）', () async {
      final now = DateTime(2026, 10, 21, 9);
      final store = await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      final outcomes = <CourseAutoRefreshOutcome>[];
      final controller = build(
        now: () => now,
        runImport: () async => true,
        onOutcome: outcomes.add,
      );
      expect(
        await controller.maybeRunNow(),
        CourseAutoRefreshOutcome.unchanged,
      );
      expect(store.lastSuccessAt, now);
      expect(outcomes, isEmpty, reason: '内容没变化不该打扰用户');
    });

    test('跑失败 → failed，记尝试时间但不记成功', () async {
      final now = DateTime(2026, 10, 21, 9);
      final store = await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      final outcomes = <CourseAutoRefreshOutcome>[];
      final controller = build(
        now: () => now,
        runImport: () async => false,
        onOutcome: outcomes.add,
      );
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.failed);
      expect(store.lastSuccessAt, isNull);
      expect(store.lastAttemptAt, now);
      expect(outcomes, <CourseAutoRefreshOutcome>[
        CourseAutoRefreshOutcome.failed,
      ]);
    });

    test('runImport 抛异常也算失败，不冒给调用方', () async {
      final now = DateTime(2026, 10, 21, 9);
      final store = await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      final controller = build(
        now: () => now,
        runImport: () async => throw StateError('教务挂了'),
      );
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.failed);
      expect(store.lastAttemptAt, now);
    });

    test('失败后立刻再调 → 冷却中不跑', () async {
      final now = DateTime(2026, 10, 21, 9);
      await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      var calls = 0;
      final controller = build(
        now: () => DateTime(2026, 10, 21, 9, 10),
        runImport: () async {
          calls++;
          return false;
        },
      );
      // 第一次先让它失败：把 now 固定在 9:00 那次。
      final first = CourseAutoRefreshController(
        runImport: () async {
          calls++;
          return false;
        },
        captureSignature: () => 'x',
        now: () => now,
      );
      expect(await first.maybeRunNow(), CourseAutoRefreshOutcome.failed);
      expect(await controller.maybeRunNow(), CourseAutoRefreshOutcome.notDue);
      expect(calls, 1);
    });
  });

  group('并发', () {
    test('跑到一半再调一次 → busy，不会叠两场', () async {
      await loadedStore(
        schedule: const CourseAutoRefreshSchedule(enabled: true),
      );
      var calls = 0;
      late CourseAutoRefreshController controller;
      final gate = Completer<void>();
      controller = CourseAutoRefreshController(
        runImport: () async {
          calls++;
          await gate.future;
          return true;
        },
        captureSignature: () => 's',
        now: () => DateTime(2026, 10, 21, 9),
      );
      final firstRun = controller.maybeRunNow();
      // 让第一场进到 runImport 里。
      await Future<void>.delayed(Duration.zero);
      expect(controller.isRunning, isTrue);
      expect(
        await controller.maybeRunNow(),
        CourseAutoRefreshOutcome.busy,
      );
      gate.complete();
      await firstRun;
      expect(calls, 1);
    });
  });

  group('下次运行时刻（界面显示）', () {
    test('关着 → null', () async {
      await loadedStore();
      final controller = build(runImport: () async => true);
      expect(controller.nextRunAt, isNull);
    });

    test('间隔模式 → 上次成功 + N 小时', () async {
      final last = DateTime(2026, 10, 21, 9);
      await loadedStore(
        schedule: const CourseAutoRefreshSchedule(
          enabled: true,
          mode: CourseAutoRefreshMode.intervalHours,
          intervalHours: 12,
        ),
        lastSuccess: last,
      );
      final controller = build(
        now: () => last,
        runImport: () async => true,
      );
      expect(controller.nextRunAt, last.add(const Duration(hours: 12)));
    });
  });
}
