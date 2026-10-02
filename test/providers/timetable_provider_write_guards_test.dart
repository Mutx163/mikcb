import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（CODE_REVIEW 2026-10-02，provider 写入收口）：
///
/// 1. `updateCourseGroup` 原先在 `removeWhere` 摘掉整组之后才取
///    `updatedCourses.first`。传入空列表时 StateError 在删除之后抛出：既没落库也
///    没 notify，界面显示旧组、内存里整组已消失，下一次任意成功写入会把「整组没了」
///    落盘 —— 用户视角是「某天的课莫名全消失了」。同文件 `addCourseGroup`
///    （:2889）与 `addCourseGroup` 的 isEmpty 守卫早就存在，只是 update 侧漏了。
/// 2. 主题 save/delete/rename 原先是「改内存 → await 落库 → notify」，落库抛错时
///    内存已变、盘上没变、UI 不刷新，且这份未落库的改动会被下一次成功写入当成
///    既有状态落盘。现在统一走带回滚的 `_applySavedThemes`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Course course(String id, {required String name, required int day}) => Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: day,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  Future<TimetableProvider> booted() async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  group('updateCourseGroup 空集合守卫', () {
    test('空列表不会把已有的整组课程抹掉', () async {
      final provider = await booted();
      addTearDown(provider.dispose);

      await provider.addCourseGroup([
        course('g1', name: '篮球', day: 1),
        course('g2', name: '篮球', day: 3),
      ]);
      expect(provider.courses, hasLength(2));

      await provider.updateCourseGroup('篮球', const <Course>[]);

      // 修复前：整组被 removeWhere 摘掉后 .first 抛错，这里会看到 0 门课。
      expect(provider.courses, hasLength(2));
      expect(provider.courses.map((c) => c.dayOfWeek), [1, 3]);
    });

    test('非空列表仍然照常整组替换', () async {
      final provider = await booted();
      addTearDown(provider.dispose);

      await provider.addCourseGroup([
        course('g1', name: '篮球', day: 1),
        course('g2', name: '篮球', day: 3),
      ]);

      await provider.updateCourseGroup('篮球', [
        course('g1', name: '篮球', day: 2),
      ]);

      expect(provider.courses, hasLength(1));
      expect(provider.courses.single.dayOfWeek, 2);
    });
  });

  group('主题写入收口', () {
    test('save / rename / delete 走完整落库链路', () async {
      final provider = await booted();
      addTearDown(provider.dispose);

      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.saveTheme('我的主题', const <String, dynamic>{
        'v': 2,
        'seed': '#FF0000',
      });
      expect(provider.settings.savedThemes, hasLength(1));
      expect(notifications, greaterThan(0), reason: '成功后必须通知监听者');

      final id = provider.settings.savedThemes.single.id;
      await provider.renameTheme(id, '改名后');
      expect(provider.settings.savedThemes.single.name, '改名后');

      // 落库验证：换一个 provider 从盘上重读，确认不是只改了内存。
      StorageService().resetForTesting();
      final reopened = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.settings.savedThemes, hasLength(1));
      expect(reopened.settings.savedThemes.single.name, '改名后');

      await reopened.deleteTheme(reopened.settings.savedThemes.single.id);
      expect(reopened.settings.savedThemes, isEmpty);
    });
  });

  // 3. 写入互斥门。课表/设置的「读快照 → await 落盘 → 回滚」全套都建立在
  //    `_mutationGate` 串行化之上：门内写者（addCourse / 导入 / 云恢复）在
  //    :4021 这类位置抓 t0 全量快照，中途 await 让出，失败时按 t0 回滚。
  //    门外的写者插进这个窗口改内存并落盘，就会在回滚时被当成"恢复前的旧数据"
  //    一起抹掉 —— 而它自己的 await 早已正常返回，UI 只会在下次重建时静默退回。
  group('写入互斥门', () {
    Future<void> holdGate(
      TimetableProvider provider,
      Completer<void> started,
      Completer<void> blocker,
    ) async {
      unawaited(
        provider.runMutationExclusive(() {
          started.complete();
          return blocker.future;
        }),
      );
      await started.future;
    }

    test('updateTimetableSettings 门被持有时排队，不插进窗口改写', () async {
      final provider = await booted();
      addTearDown(provider.dispose);
      expect(provider.settings.enableHaptics, isTrue);

      final started = Completer<void>();
      final blocker = Completer<void>();
      await holdGate(provider, started, blocker);

      var settled = false;
      final write = provider
          .updateTimetableSettings(
            provider.settings.copyWith(enableHaptics: false),
          )
          .whenComplete(() => settled = true);
      await Future<void>.delayed(Duration.zero);

      // 修复前这里已经是 false：整份回写在门被持有时就完成了。
      expect(settled, isFalse, reason: '门外写者必须排队等门');
      expect(provider.settings.enableHaptics, isTrue);

      blocker.complete();
      await write;
      expect(provider.settings.enableHaptics, isFalse);
    });

    test('persistHomeViewState 同样串行', () async {
      final provider = await booted();
      addTearDown(provider.dispose);

      final started = Completer<void>();
      final blocker = Completer<void>();
      await holdGate(provider, started, blocker);

      var settled = false;
      final write = provider
          .persistHomeViewState(
            mode: TimetableHomeViewMode.day,
            dayOfWeek: 5,
          )
          .whenComplete(() => settled = true);
      await Future<void>.delayed(Duration.zero);

      expect(settled, isFalse);
      expect(provider.settings.timetableLastViewedDayOfWeek, isNot(5));

      blocker.complete();
      await write;
      expect(provider.settings.timetableLastViewedDayOfWeek, 5);
    });

    test('地点分组入口跨 await 的校验-写入序列不许被插队', () async {
      final provider = await booted();
      addTearDown(provider.dispose);
      final scheme = await provider.createTimeScheme(
        name: '作息',
        sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
      );

      final started = Completer<void>();
      final blocker = Completer<void>();
      await holdGate(provider, started, blocker);

      var settled = false;
      final create = provider
          .createLocationTimeGroup(
            name: '教学楼A',
            timeSchemeId: scheme.id,
            keywords: const [LocationKeyword(pattern: 'A')],
          )
          .whenComplete(() => settled = true);
      await Future<void>.delayed(Duration.zero);

      expect(settled, isFalse, reason: '门被持有时分组写入必须排队');
      expect(provider.locationTimeGroups, isEmpty);

      blocker.complete();
      await create;
      expect(provider.locationTimeGroups, hasLength(1));
    });

    test('并发给两节课设提醒不会互相覆盖', () async {
      final provider = await booted();
      addTearDown(provider.dispose);

      // setClassReminder 原先在门外 `final current = settings;`，
      // 而 updateSettings 在门内把 _settings 整份替换 ——
      // 两次调用都以同一份 t0 快照为基准，后完成的那次把前一次的提醒抹掉，
      // 双方都收到成功返回（日期规则自动套用、外观防抖保存落在同一窗口时同理）。
      await Future.wait([
        provider.setClassReminder(
          const ClassReminderEntry(
            courseId: 'c1',
            date: '2026-09-07',
            minuteOfDay: 480,
          ),
        ),
        provider.setClassReminder(
          const ClassReminderEntry(
            courseId: 'c2',
            date: '2026-09-07',
            minuteOfDay: 570,
          ),
        ),
      ]);

      expect(
        provider.settings.classReminders.map((entry) => entry.courseId),
        containsAll(<String>['c1', 'c2']),
      );

      await provider.removeClassReminder('c1', '2026-09-07');
      expect(
        provider.settings.classReminders.map((entry) => entry.courseId),
        <String>['c2'],
      );
    });
  });
}
