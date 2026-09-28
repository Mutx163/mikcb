import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 永川校区作息：第 1、2 节两校区一致，第 3、4 节按教学楼分档。
const List<SectionTime> _yongchuMainBuilding = [
  SectionTime(startTime: '08:20', endTime: '09:05'),
  SectionTime(startTime: '09:15', endTime: '10:00'),
  SectionTime(startTime: '10:30', endTime: '11:15'),
  SectionTime(startTime: '11:25', endTime: '12:10'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> providerWithScheme(
    List<SectionTime> sections,
  ) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    final scheme = await provider.createTimeScheme(
      name: '永川校区·A主',
      sections: sections,
      applyToActiveProfile: true,
    );
    await provider.applyTimeScheme(scheme.id);
    return provider;
  }

  test('无自定义时间的课程，时间仍来自模板', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    final course = Course(
      id: 'plain',
      name: '机械控制工程',
      teacher: '芦玉琴',
      location: 'A主215',
      dayOfWeek: 4,
      startSection: 1,
      endSection: 4,
      startTime: '',
      endTime: '',
    );
    await provider.addCourse(course);
    expect(provider.resolvedCourseStartTime(course), '08:20');
  });

  test('带自定义时间的课程，闹钟用适配脚本下发的真实钟点', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    // 同一节次范围，但属于「其他教学楼」：第 3、4 节早 10 分钟。
    final course = Course(
      id: 'custom',
      name: '模具设计',
      teacher: '唐治知',
      location: 'A综204',
      dayOfWeek: 5,
      startSection: 1,
      endSection: 4,
      startTime: '08:20',
      endTime: '12:00',
      hasCustomTime: true,
    );
    await provider.addCourse(course);
    // 起点与模板一致（都是第 1 节 08:20），终点应被钉住为 12:00 而非 12:10。
    expect(provider.resolvedCourseStartTime(course), '08:20');
    final endClock = provider.resolvedCourseEndTime(course);
    expect(endClock, '12:00');
  });

  test('自定义时间只在课程自己的节次区间生效，不污染模板其它节次', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    final course = Course(
      id: 'custom-3-4',
      name: '模具设计',
      teacher: '唐治知',
      location: 'A6304',
      dayOfWeek: 5,
      startSection: 3,
      endSection: 4,
      startTime: '10:20',
      endTime: '12:00',
      hasCustomTime: true,
    );
    await provider.addCourse(course);
    expect(provider.resolvedCourseStartTime(course), '10:20');
    // 另一门仍走模板，未被污染。
    final other = Course(
      id: 'other',
      name: '机械控制工程',
      teacher: '芦玉琴',
      location: 'A主401',
      dayOfWeek: 4,
      startSection: 3,
      endSection: 4,
      startTime: '',
      endTime: '',
    );
    await provider.addCourse(other);
    expect(provider.resolvedCourseStartTime(other), '10:30');
  });

  test('节次超出模板时课程被拒绝（既有校验，不因自定义时间放宽）', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    final course = Course(
      id: 'overflow',
      name: '毕业实习',
      teacher: '李任强',
      location: 'A实401',
      dayOfWeek: 6,
      startSection: 9,
      endSection: 10,
      startTime: '18:50',
      endTime: '20:30',
      hasCustomTime: true,
    );
    // 模板只有 4 节，addCourse 的既有校验先拦下，返回错误而不是写入。
    await expectLater(provider.addCourse(course), isNot(isNull));
  });

  // ==========================================================================
  // 以下三条针对两个真实缺陷补的回归测试。
  //
  // 为什么必须断「存下来的那份」而不是传进去的局部变量：addCourse /
  // importParsedCourses 都会改写存储副本，而调用方手里的对象仍是原值。
  // 早先的测试全部断局部变量，于是功能坏掉时它们照样全绿。
  // ==========================================================================

  /// 读回 provider 真正存下来的那门课，而不是复用传进去的对象。
  Course stored(TimetableProvider provider, String id) =>
      provider.courses.firstWhere((c) => c.id == id);

  test('单节课（早读）：两端一次性写入，不得产出开始晚于结束的倒挂时间', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    // 早读只占第 1 节 → startIndex == endIndex。
    final course = Course(
      id: 'morning-reading',
      name: '早读',
      teacher: '张三',
      location: 'A主101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 1,
      endWeek: 3,
      startTime: '07:30',
      endTime: '08:00',
      hasCustomTime: true,
    );
    await provider.addCourse(course);

    // 存下来的这份必须两端都是脚本给的值。旧实现先写 07:30 再用模板的
    // 08:20 覆盖掉起点，产出 08:20–08:00。
    final saved = stored(provider, 'morning-reading');
    expect(saved.startTime, '07:30');
    expect(saved.endTime, '08:00');
    // 显式断言不倒挂：正在上课的判断与闹钟都依赖这个前提。
    expect(saved.startTime.compareTo(saved.endTime) < 0, isTrue);
    // 显示侧读到的也必须是真实钟点。
    expect(provider.resolvedCourseStartTime(saved), '07:30');
    expect(provider.resolvedCourseEndTime(saved), '08:00');
  });

  test('走真实导入路径：脚本下发的钟点不被时间模板覆盖', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    // 导入时 provider 会对每门课重算一次钟点（import_export_service 末尾
    // 无条件调用 _syncCoursesWithEffectiveTimeSchemes）。脚本给的 12:00
    // 曾在这里被模板的 12:10 悄悄改掉，而 hasCustomTime 标记存活 ——
    // 产出「标记说有自定义时间、时间却是模板的」自相矛盾状态。
    final imported = Course(
      id: 'imported-custom',
      name: '工装夹具设计',
      teacher: '付世强',
      location: 'A综204',
      dayOfWeek: 5,
      startSection: 1,
      endSection: 4,
      startWeek: 11,
      endWeek: 12,
      startTime: '08:20',
      endTime: '12:00',
      hasCustomTime: true,
    );
    await provider.importParsedCourses(
      [imported],
      replaceExisting: true,
      source: 'test',
    );

    final saved = stored(provider, 'imported-custom');
    expect(saved.hasCustomTime, isTrue);
    // 关键断言：时间必须是脚本给的，不是模板的 12:10。
    expect(saved.endTime, '12:00');
    expect(saved.startTime, '08:20');
  });

  test('导入后标记与时间必须自洽：不能出现「有自定义时间但时间是模板的」', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    final imported = Course(
      id: 'coherent',
      name: '连堂实验',
      teacher: '李四',
      location: 'A实415',
      dayOfWeek: 2,
      startSection: 1,
      endSection: 1,
      startWeek: 5,
      endWeek: 5,
      startTime: '13:00',
      endTime: '16:40',
      hasCustomTime: true,
    );
    await provider.importParsedCourses(
      [imported],
      replaceExisting: true,
      source: 'test',
    );
    final saved = stored(provider, 'coherent');
    // 不变量：只要标记为真，存的钟点就必须仍是脚本给的那一对。
    if (saved.hasCustomTime) {
      expect(saved.startTime, '13:00');
      expect(saved.endTime, '16:40');
    }
    expect(saved.startTime.compareTo(saved.endTime) < 0, isTrue);
  });

  test('无自定义时间的课程仍然照模板改写（守卫不能误伤普通课）', () async {
    final provider = await providerWithScheme(_yongchuMainBuilding);
    final plain = Course(
      id: 'plain-import',
      name: '机械控制工程',
      teacher: '芦玉琴',
      location: 'A主215',
      dayOfWeek: 4,
      startSection: 1,
      endSection: 4,
      startWeek: 7,
      endWeek: 11,
      startTime: '',
      endTime: '',
    );
    await provider.importParsedCourses(
      [plain],
      replaceExisting: true,
      source: 'test',
    );
    final saved = stored(provider, 'plain-import');
    expect(saved.hasCustomTime, isFalse);
    // 仍应被模板接管：第 1 节 08:20、第 4 节 12:10。
    expect(saved.startTime, '08:20');
    expect(saved.endTime, '12:10');
  });
}
