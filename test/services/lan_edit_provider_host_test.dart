import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/lan_edit_provider_host.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

Course buildTestCourse({required String id, required String color}) {
  return Course(
    id: id,
    name: '测试课程',
    teacher: '',
    location: '',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 1,
    startTime: '08:00',
    endTime: '08:45',
    color: color,
  );
}

Course buildScheduleSlot({
  required String id,
  required String name,
  required String teacher,
  int dayOfWeek = 1,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );
}

void main() {
  test('LAN API colors accept only six-digit hex values', () {
    expect(LanEditProviderHost.normalizeLanCourseColor(' #aBc123 '), '#ABC123');
    expect(
      LanEditProviderHost.normalizeLanCourseColor('red" onmouseover="alert(1)'),
      LanEditProviderHost.defaultLanCourseColor,
    );
    expect(
      LanEditProviderHost.normalizeLanCourseColor('rgb(255, 0, 0)'),
      LanEditProviderHost.defaultLanCourseColor,
    );
  });

  test('courseFromApiJson removes unsafe colors before persistence', () {
    final settings = TimetableSettings.defaults();
    final course = LanEditProviderHost.courseFromApiJson(
      {'name': '测试课程', 'color': 'red" onmouseover="alert(1)'},
      sections: settings.sections,
      semesterWeekCount: settings.semesterWeekCount,
    );

    expect(course.color, LanEditProviderHost.defaultLanCourseColor);
  });

  test('transfer normalization covers top-level and profile courses', () {
    final profile = TimetableProfile(
      id: 'profile-a',
      name: '测试课表',
      courses: [
        buildTestCourse(
          id: 'profile-course',
          color: 'red" onmouseover="alert(1)',
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
    );
    final package = TransferPackage(
      packageId: 'transfer-test',
      scope: TransferScope.currentTimetable,
      courses: [
        buildTestCourse(
          id: 'top-level-course',
          color: 'red" onmouseover="alert(1)',
        ),
      ],
      profiles: [profile],
    );

    final normalizedPackage = LanEditProviderHost.normalizeTransferCourseColors(
      package,
    );

    expect(
      normalizedPackage.courses.single.color,
      LanEditProviderHost.defaultLanCourseColor,
    );
    expect(
      normalizedPackage.profiles.single.courses.single.color,
      LanEditProviderHost.defaultLanCourseColor,
    );
  });

  test('LAN replaceCourseGroup keeps each slot teacher on create', () async {
    SharedPreferences.setMockInitialValues({});
    StorageService().resetForTesting();
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final host = LanEditProviderHost(provider);

    final created = await host.replaceCourseGroup(
      originalName: null,
      slots: [
        buildScheduleSlot(
          id: 'lan-a',
          name: '高等数学',
          teacher: '张老师',
        ),
        buildScheduleSlot(
          id: 'lan-b',
          name: '高等数学',
          teacher: '李老师',
          dayOfWeek: 3,
        ),
      ],
    );

    expect(created, hasLength(2));
    final byId = {for (final c in provider.courses) c.id: c};
    expect(byId['lan-a']!.teacher, '张老师');
    expect(byId['lan-b']!.teacher, '李老师');
  });

  test('LAN replaceGroup keeps each slot teacher on update', () async {
    SharedPreferences.setMockInitialValues({});
    StorageService().resetForTesting();
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      buildScheduleSlot(id: 'old', name: '离散数学', teacher: '旧老师'),
    );
    final host = LanEditProviderHost(provider);

    final replaced = await host.replaceCourseGroup(
      originalName: '离散数学',
      slots: [
        buildScheduleSlot(
          id: 'replaced-a',
          name: '离散数学',
          teacher: '张老师',
        ),
        buildScheduleSlot(
          id: 'replaced-b',
          name: '离散数学',
          teacher: '李老师',
          dayOfWeek: 3,
        ),
      ],
    );

    expect(replaced, hasLength(2));
    final byId = {for (final c in provider.courses) c.id: c};
    expect(byId['replaced-a']!.teacher, '张老师');
    expect(byId['replaced-b']!.teacher, '李老师');
  });

  group('局域网写入的作用域与字段边界', () {
    Future<(TimetableProvider, LanEditProviderHost)> seedHost() async {
      SharedPreferences.setMockInitialValues({});
      StorageService().resetForTesting();
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      return (provider, LanEditProviderHost(provider));
    }

    /// 局域网导出的课表包改头换面成 all_data、并把设备级两张表清空。
    String tamperToEmptyAllData(LanEditProviderHost host) {
      final body = jsonDecode(host.buildProfileBackupJson())
          as Map<String, dynamic>;
      body['scope'] = TransferScope.allData.value;
      body['locationTimeGroups'] = <dynamic>[];
      body['scheduleDateRules'] = <dynamic>[];
      return jsonEncode(body);
    }

    test('all_data 作用域即使 profiles 为空也不能从局域网入口落盘', () async {
      final (provider, host) = await seedHost();
      await provider.replaceLocationTimeGroups([
        const LocationTimeGroup(
          id: 'g-a',
          name: 'A 楼',
          timeSchemeId: 'scheme-a',
        ),
      ]);
      await provider.replaceScheduleDateRules([
        const ScheduleDateRule(
          id: 'r-a',
          name: '调休',
          timeSchemeId: 'scheme-a',
          startDate: '2026-03-02',
          endDate: '2026-03-02',
        ),
      ]);
      final tampered = tamperToEmptyAllData(host);

      // 守卫本身：四个入口都必须拒。
      expect(() => host.previewTransferJson(tampered), throwsFormatException);
      await expectLater(
        host.applyTransferJson(tampered, mode: TransferApplyMode.overwrite),
        throwsFormatException,
      );
      await expectLater(
        host.importProfileBackupJson(tampered),
        throwsFormatException,
      );
      await expectLater(
        host.importMergeBackupJson(tampered),
        throwsFormatException,
      );

      // 副作用：设备级地点分组/日期规则是**全设备**数据，不能被抹掉。
      expect(provider.locationTimeGroups, hasLength(1));
      expect(provider.scheduleDateRules, hasLength(1));
    });

    test('PATCH 只改地点时保留 hasCustomTime，上课时间不被模板改回', () async {
      final (provider, host) = await seedHost();
      await provider.addCourse(
        Course(
          id: 'custom-1',
          name: '形势与政策',
          teacher: '周老师',
          location: 'A101',
          dayOfWeek: 2,
          startSection: 1,
          endSection: 1,
          startTime: '07:00',
          endTime: '07:40',
          hasCustomTime: true,
        ),
      );
      final stored = provider.courses.firstWhere((c) => c.id == 'custom-1');
      expect(stored.startTime, '07:00');

      final updated = LanEditProviderHost.mergeCoursePatch(
        host.findCourse('custom-1')!,
        {'location': 'B301'},
        sections: provider.settings.sections,
        semesterWeekCount: provider.settings.semesterWeekCount,
      );
      expect(updated.hasCustomTime, isTrue);
      await host.updateCourse(updated);

      final after = provider.courses.firstWhere((c) => c.id == 'custom-1');
      expect(after.location, 'B301');
      expect(after.startTime, '07:00');
      expect(after.endTime, '07:40');
    });

    test('显式送来与模板不同的钟点才算自定义', () {
      final settings = TimetableSettings.defaults();
      final custom = LanEditProviderHost.courseFromApiJson(
        {
          'name': '实验课',
          'dayOfWeek': 3,
          'startSection': 2,
          'endSection': 2,
          'startTime': '07:15',
          'endTime': '07:55',
        },
        sections: settings.sections,
        semesterWeekCount: settings.semesterWeekCount,
      );
      expect(custom.startTime, '07:15');
      expect(custom.hasCustomTime, isTrue);

      final matchesTemplate = LanEditProviderHost.courseFromApiJson(
        {
          'name': '讲座',
          'dayOfWeek': 4,
          'startSection': 1,
          'endSection': 1,
          'startTime': '08:00',
          'endTime': '08:45',
        },
        sections: settings.sections,
        semesterWeekCount: settings.semesterWeekCount,
      );
      expect(matchesTemplate.hasCustomTime, isFalse);

      // 畸形/空白钟点不能当自定义时间落库（否则 ClockTime/原生侧各算一套）。
      final malformed = LanEditProviderHost.courseFromApiJson(
        {
          'name': '空时间',
          'startSection': 1,
          'endSection': 1,
          'startTime': '',
          'endTime': '25:00',
        },
        sections: settings.sections,
        semesterWeekCount: settings.semesterWeekCount,
      );
      expect(malformed.startTime, '08:00');
      expect(malformed.endTime, '08:45');
      expect(malformed.hasCustomTime, isFalse);

      // 8:00 与模板的 08:00 是同一个时间，不该被判成自定义。
      final unpadded = LanEditProviderHost.courseFromApiJson(
        {'name': '同时间', 'startSection': 1, 'endSection': 1, 'startTime': '8:00'},
        sections: settings.sections,
        semesterWeekCount: settings.semesterWeekCount,
      );
      expect(unpadded.startTime, '08:00');
      expect(unpadded.hasCustomTime, isFalse);
    });

    test('customWeeks/suspendedWeeks 在写侧也归一', () {
      final settings = TimetableSettings.defaults();
      final course = LanEditProviderHost.courseFromApiJson(
        {
          'name': '体育课',
          'startWeek': 1,
          'endWeek': 20,
          'customWeeks': <dynamic>[999, 3, 3, 0, -5],
          'suspendedWeeks': <dynamic>[777, 4],
        },
        sections: settings.sections,
        semesterWeekCount: 20,
      );
      expect(course.customWeeks, <int>[3]);
      expect(course.suspendedWeeks, <int>[4]);
    });

    test('客户端自带的课程 id 不能撞车也不能留空', () async {
      final (provider, host) = await seedHost();
      await provider.addCourse(buildTestCourse(id: 'dup', color: '#2196F3'));

      final draft = LanEditProviderHost.courseFromApiJson(
        {'id': 'dup', 'name': '撞 id 的课'},
        sections: provider.settings.sections,
        semesterWeekCount: provider.settings.semesterWeekCount,
      );
      await expectLater(host.createCourse(draft), throwsArgumentError);
      expect(provider.courses.where((c) => c.id == 'dup'), hasLength(1));

      final blank = LanEditProviderHost.courseFromApiJson(
        {'id': '   ', 'name': '空 id 的课'},
        sections: provider.settings.sections,
        semesterWeekCount: provider.settings.semesterWeekCount,
      );
      expect(blank.id.trim(), isNotEmpty);
    });
  });
}
