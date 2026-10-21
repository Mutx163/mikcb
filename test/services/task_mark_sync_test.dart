import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/services/timetable_course_service.dart';

/// 作业与「本节有作业」标记的联动（2026-10-21）。
///
/// 背景：那个标记原先只有课程备注弹层里的一个开关会写。把开关从弹层移走
/// （作业改成独立入口）之后，**没有任何地方会写它**，而周卡/日卡/课程面板的
/// 作业圆点全看它——结果就是「加了作业，圆点永远不亮」。
/// 现在改成「加作业时自动置位」，这里钉住这条契约。
class _Port implements TimetableCoursePort {
  _Port({List<Course> courses = const <Course>[], List<CourseTask> tasks = const <CourseTask>[]})
    : courses = List<Course>.from(courses),
      tasks = List<CourseTask>.from(tasks);

  @override
  List<Course> courses;
  @override
  List<CourseTask> tasks;
  @override
  List<Exam> exams = <Exam>[];
  @override
  List<TimetableProfile> profiles = <TimetableProfile>[];

  int persistCalls = 0;
  bool failPersist = false;

  @override
  int get semesterWeekCount => 16;

  @override
  Course? getCourseById(String id) {
    for (final course in courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  @override
  DateTime? dateForCourseOccurrence(Course course, int week) =>
      DateTime(2026, 3, 2).add(Duration(days: (week - 1) * 7 + course.dayOfWeek - 1));

  @override
  String? validateCourseTimeSchemeOverride({
    String? timeSchemeId,
    required int startSection,
    required int endSection,
  }) => null;

  @override
  Course syncCourseWithEffectiveTimeScheme(Course course) => course;

  @override
  Future<void> persistActiveProfileState() async {
    persistCalls += 1;
    if (failPersist) throw StateError('disk full');
  }

  @override
  void notifyStateChanged() {}
  @override
  void logEvent(String event, [Map<String, Object>? parameters]) {}
  @override
  Future<void> initialize() async {}
  @override
  void clearCurrentLiveCourseId() {}
  @override
  Future<void> syncExamReminders() async {}
  @override
  Future<void> updateLiveActivity() async {}
  @override
  Future<void> recordTeacher(String? teacher) async {}
  @override
  Future<void> recordLocation(String? location) async {}
  @override
  bool isLiveTestingFixture(Course course) => false;
}

Course _course() => Course(
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

CourseTask _task({String? courseId = 'c1', int? sourceWeek = 2}) => CourseTask(
  id: 't1',
  title: '第三章习题',
  courseId: courseId,
  sourceWeek: sourceWeek,
  dueDate: DateTime(2026, 3, 10),
  createdAt: DateTime(2026, 3),
  updatedAt: DateTime(2026, 3),
);

void main() {
  group('加作业时自动置「本节有作业」标记', () {
    test('挂了课程与周次 → 标记亮起（圆点会亮）', () async {
      final port = _Port(courses: <Course>[_course()]);

      await TimetableCourseService.addTask(port, _task());

      expect(
        port.courses.single.hasHomeworkInWeek(2),
        isTrue,
        reason: '不置位的话周卡/日卡/面板的作业圆点永远不亮',
      );
    });

    test('原本已有备注文字 → 保留文字，只把标记置位', () async {
      final port = _Port(
        courses: <Course>[
          _course().copyWith(
            sessionNotes: {
              2: const CourseSessionNote(text: '带计算器'),
            },
          ),
        ],
      );

      await TimetableCourseService.addTask(port, _task());

      final note = port.courses.single.sessionNoteForWeek(2);
      expect(note?.text, '带计算器', reason: '不该覆盖用户写的备注文字');
      expect(note?.hasHomework, isTrue);
    });

    test('没挂课程的作业 → 不动任何课程', () async {
      final port = _Port(courses: <Course>[_course()]);

      await TimetableCourseService.addTask(
        port,
        _task(courseId: null, sourceWeek: null),
      );

      expect(port.courses.single.hasHomeworkInWeek(2), isFalse);
    });

    test('挂了课程但没周次 → 不动（落不到具体课次上）', () async {
      final port = _Port(courses: <Course>[_course()]);

      await TimetableCourseService.addTask(port, _task(sourceWeek: null));

      expect(port.courses.single.hasHomeworkInWeek(2), isFalse);
    });

    test('标记本来就已经亮着 → 幂等，不重复写', () async {
      final port = _Port(
        courses: <Course>[
          _course().copyWith(
            sessionNotes: {
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
      );

      await TimetableCourseService.addTask(port, _task());

      expect(port.courses.single.sessionNoteForWeek(2)?.text, '习题');
      expect(port.courses.single.hasHomeworkInWeek(2), isTrue);
    });

    test('落盘失败 → 作业与课程标记一起退回', () async {
      final port = _Port(courses: <Course>[_course()])..failPersist = true;

      await expectLater(
        TimetableCourseService.addTask(port, _task()),
        throwsA(isA<StateError>()),
      );

      expect(port.tasks, isEmpty, reason: '作业不能留下');
      expect(
        port.courses.single.hasHomeworkInWeek(2),
        isFalse,
        reason: '标记是作业的副作用，作业没存下就不能留',
      );
    });
  });

  group('作业被取消后标记的处理（回归：原行为不变）', () {
    test('删作业会清掉那门课那周的标记', () async {
      final port = _Port(
        courses: <Course>[
          _course().copyWith(
            sessionNotes: {
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          CourseTask(
            id: 't1',
            title: '习题',
            courseId: 'c1',
            sourceWeek: 2,
            source: CourseTaskSource.homeworkMark,
            createdAt: DateTime(2026, 3),
            updatedAt: DateTime(2026, 3),
          ),
        ],
      );

      await TimetableCourseService.deleteTask(port, 't1');

      expect(port.courses.single.hasHomeworkInWeek(2), isFalse);
    });
  });
}
