import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

/// 回归钉（2026-10-02 审查第 6 轮，导入收尾）：
///
/// `_timetableImportParsedCourses` 在 `replaceExisting: false`（「更新课表」）分支
/// 里，先做 `courseListsEqual(host._courses, result.mergedCourses)` 就
/// `return 0`。而整条导入链路里 `semesterStartDate` **只有** 那行 return 之后的
/// 一处写入口（`import_export_service.dart:300`），后面还跟着
/// `semesterStart != null` 时重算 `_currentWeek`。
///
/// 于是：教务本学期重新发布课表，课程与本地一字不差；用户在导入面板里顺手把
/// 「学期开始日期」从 9/1 改成 9/7 并确认 —— 面板弹了「课表没有变化」，
/// 日期一次都没落盘，当前周号整体错一周，首页周次、选课提醒、超级岛、
/// 桌面卡全按错误的周排，且用户看不出任何异常。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Course course(
    String id, {
    String name = '高等数学',
    int dayOfWeek = 1,
  }) => Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
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

  test('课程一字不差时，本次导入确认的开学日期仍然落盘并重算周次', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    final imported = course('c1');
    await provider.importParsedCourses(
      [imported],
      replaceExisting: true,
      source: 'test',
    );
    expect(provider.courses, hasLength(1));

    final newSemesterStart = DateTime(2026, 9, 7);
    final changed = await provider.importParsedCourses(
      [course('c1-again')],
      replaceExisting: false,
      semesterStart: newSemesterStart,
      source: 'test',
    );

    // 课程确实没变化（返回 0 是正确语义），但日期必须落盘。
    expect(changed, 0);
    expect(provider.semesterStartDate, newSemesterStart);
    expect(provider.settings.semesterStartDate, newSemesterStart);
    // 重算过的当前周必须与「按新开学日期数出来的周」一致：
    // 修复前这里停在旧开学日期上，整体错一周。
    expect(
      provider.currentWeek,
      provider.getWeekIndex(DateTime.now(), newSemesterStart),
      reason: '开学日期改了，当前周号必须跟着重算',
    );
  });

  test('没有开学日期且课程没变化时，仍然走原来的空导入早退', () async {
    final provider = await booted();
    addTearDown(provider.dispose);

    await provider.importParsedCourses(
      [course('c1')],
      replaceExisting: true,
      source: 'test',
    );
    final weekBefore = provider.currentWeek;

    final changed = await provider.importParsedCourses(
      [course('c1-again')],
      replaceExisting: false,
      source: 'test',
    );

    expect(changed, 0);
    expect(provider.currentWeek, weekBefore);
  });
}
