import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/screens/add_exam_screen.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/screens/timetable_form_pages_impl.dart';
import 'package:university_timetable/utils/course_group.dart';
import 'package:university_timetable/widgets/timetable/timetable_form_pages.dart';

/// 表单族注入契约：**参数必须原样到达页面实例**。
///
/// 背景：`widgets → screens` 那批「带上下文推表单页」的边改成了注入式构造
/// （widgets 侧只持有 `TimetableFormPages`，实现住 screens 层）。这类改动最大
/// 的风险不是「页面打不开」，而是**参数在中间层被吞掉**——用户看到的是
/// 「页面打开了，但表单是空的」，像是数据丢了。
///
/// 存量的 `timetable_day_view_test` 只断言 `find.byType(AddCourseScreen)`，
/// 参数丢了它照样绿（实测：把 `initialCourse` 转发删掉，43 例全过）。所以这里
/// **直接对着页面实例上的字段断言**，不经过 UI 渲染，快且精确。
///
/// 这些页面只在这里被构造、不 pump，所以不需要 provider / 本地化上下文。
void main() {
  final course = Course(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );

  test('课程表单：initialCourse / courseGroup / 周次节次 全部透传', () {
    final widget = kTimetableFormPages.courseForm(
      initialCourse: course,
      initialWeek: 7,
      initialDayOfWeek: 3,
      initialStartSection: 2,
      initialEndSection: 5,
    ) as AddCourseScreen;

    expect(widget.initialCourse, same(course), reason: '丢了它，编辑页就是空表单');
    expect(widget.initialWeek, 7);
    expect(widget.initialDayOfWeek, 3);
    expect(widget.initialStartSection, 2);
    expect(widget.initialEndSection, 5);
  });

  test('课程表单：无参调用仍是新建（全部为 null）', () {
    final widget = kTimetableFormPages.courseForm() as AddCourseScreen;
    expect(widget.initialCourse, isNull);
    expect(widget.courseGroup, isNull);
    expect(widget.initialWeek, isNull);
    expect(widget.initialDayOfWeek, isNull);
    expect(widget.initialStartSection, isNull);
    expect(widget.initialEndSection, isNull);
  });

  test('考试表单：exam 透传；无参是新建', () {
    final exam = Exam(
      id: 'e1',
      courseId: 'c1',
      name: '期末考试',
      dateTime: DateTime(2026, 6, 20),
      startTime: '09:00',
      endTime: '11:00',
      createdAt: DateTime(2026, 5, 12),
      updatedAt: DateTime(2026, 5, 12),
    );
    final editing = kTimetableFormPages.examForm(exam: exam) as AddExamScreen;
    expect(editing.exam, same(exam));
    expect((kTimetableFormPages.examForm() as AddExamScreen).exam, isNull);
  });

  test('日程表单：initialDate 与 occurrenceDate 是两条不同入口，不许互相顶替', () {
    final item = ScheduleItem(
      id: 's1',
      title: '答疑',
      date: DateTime(2026, 5, 12),
      startTime: '19:00',
      endTime: '20:00',
      createdAt: DateTime(2026, 4, 12),
      updatedAt: DateTime(2026, 4, 12),
    );
    final occurrenceDate = DateTime(2026, 5, 8);

    final editing =
        kTimetableFormPages.scheduleItemForm(
              scheduleItem: item,
              occurrenceDate: occurrenceDate,
            )
            as AddScheduleItemScreen;
    expect(editing.scheduleItem, same(item));
    expect(editing.occurrenceDate, occurrenceDate);
    expect(
      editing.initialDate,
      isNull,
      reason: '编辑单次覆盖不该凭空带出新建日期',
    );

    final creating =
        kTimetableFormPages.scheduleItemForm(
              initialDate: DateTime(2026, 5, 2),
            )
            as AddScheduleItemScreen;
    expect(creating.initialDate, DateTime(2026, 5, 2));
    expect(
      creating.occurrenceDate,
      isNull,
      reason: '新建不该带 occurrenceDate',
    );
    expect(creating.scheduleItem, isNull);
  });

  test('未注入时取实现必须抛 StateError（不给静默空表）', () {
    // 本测试文件全程没调 registerTimetableFormPages，天然就是「未注入」态。
    expect(() => timetableFormPages, throwsA(isA<StateError>()));
  });

  test('注入是幂等的：后注册覆盖前者', () {
    const first = TimetableFormPages(
      courseForm: _stubCourseForm,
      examForm: _stubExamForm,
      scheduleItemForm: _stubScheduleItemForm,
      timeSchemeManagement: _unusedTimeScheme,
      aboutUpdate: _unusedAboutUpdate,
    );
    registerTimetableFormPages(first);
    expect(timetableFormPages, same(first));

    const second = TimetableFormPages(
      courseForm: _stubCourseForm,
      examForm: _stubExamForm,
      scheduleItemForm: _stubScheduleItemForm,
      timeSchemeManagement: _unusedTimeScheme,
      aboutUpdate: _unusedAboutUpdate,
    );
    registerTimetableFormPages(second);
    expect(timetableFormPages, same(second), reason: '测试会多次挂首页，须幂等');
  });
}

Widget _stubCourseForm({
  Course? initialCourse,
  CourseGroup? courseGroup,
  int? initialWeek,
  int? initialDayOfWeek,
  int? initialStartSection,
  int? initialEndSection,
}) => const AddCourseScreen();

Widget _stubExamForm({Exam? exam}) => const AddExamScreen();

Widget _stubScheduleItemForm({
  ScheduleItem? scheduleItem,
  DateTime? initialDate,
  DateTime? occurrenceDate,
}) => const AddScheduleItemScreen();

Widget _unusedTimeScheme({String? initialEditSchemeId}) =>
    const SizedBox.shrink();

Widget _unusedAboutUpdate({required PackageInfo packageInfo}) =>
    const SizedBox.shrink();
