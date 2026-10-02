import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 自定义钟点只存在于「课程解析后的节次表」里（回归钉，2026-10-02）。
///
/// `TimetableProvider._applyCourseCustomTime` 的注释写明它的设计意图：把自定义
/// 钟点钉回该课自己的首尾两节，下游（闹钟、超级岛、进度里程碑）一律按
/// `startSection`/`endSection` 索引这份结果，"so the whole app honours
/// Course.hasCustomTime without any caller change"。
///
/// 但**模板表本身并不带这份钉好值**：任何直接取
/// `resolveCourseTimeScheme(course).sections` 的调用点都会绕开它。改期弹层就是这么
/// 一个调用点（timetable_screen.dart:9152），于是钉过钟点的早读（07:00-07:40 被钉在
/// 第 1 节）在弹层里显示成模板的 08:00-08:45 —— 用户照弹层时间行动就错，而课表卡与
/// 闹钟都显示 07:00。这里钉住两者的差异，防止下一个调用点再踩同一个坑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const template = [
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '09:00', endTime: '09:45'),
    SectionTime(startTime: '10:00', endTime: '10:45'),
  ];

  Future<TimetableProvider> booted() async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  Course customCourse({int startSection = 1, int endSection = 2}) {
    return Course(
      id: 'read-1',
      name: '早读',
      teacher: '班主任',
      location: '教室A',
      dayOfWeek: 1,
      startSection: startSection,
      endSection: endSection,
      startTime: '07:00',
      endTime: '07:40',
      hasCustomTime: true,
    );
  }

  test('解析后的节次表把自定义钟点钉回首尾两节', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    await provider.updateTimetableSettings(
      provider.settings.copyWith(sections: template),
    );
    await provider.addCourse(customCourse());

    final course = provider.courses.single;
    final resolved = provider.resolvedSectionsForCourse(course);

    expect(resolved, isNotNull);
    expect(resolved![0].startTime, '07:00');
    expect(resolved[1].endTime, '07:40');
    // 中间与首尾之外的节次保持模板，否则课间的休息里程碑会被一起改掉。
    expect(resolved[2].startTime, '10:00');
  });

  test('模板表本身不带钉好的值，取它就会显示错时间', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    await provider.updateTimetableSettings(
      provider.settings.copyWith(sections: template),
    );
    await provider.addCourse(customCourse());

    final scheme = provider.resolveCourseTimeScheme(provider.courses.single);
    final templateSections = scheme?.sections ?? provider.settings.sections;

    expect(templateSections[0].startTime, '08:00');
    expect(
      templateSections[0].startTime,
      isNot(provider.resolvedSectionsForCourse(provider.courses.single)![0].startTime),
      reason: '两条来源必须可区分，否则调用点取错也看不出来',
    );
  });

}
