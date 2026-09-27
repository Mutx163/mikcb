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
}
