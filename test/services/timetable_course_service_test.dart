import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_course_service.dart';

/// 假端口：内存状态 + 钩子计数。方案补齐故意走"原样返回"，
/// 让被测对象是服务自己的校验、归一、广播与回滚逻辑。
class _FakePort implements TimetableCoursePort {
  _FakePort({
    List<Course> courses = const <Course>[],
    List<CourseTask> tasks = const <CourseTask>[],
    List<Exam> exams = const <Exam>[],
    List<TimetableProfile> profiles = const <TimetableProfile>[],
  }) : courses = List<Course>.from(courses),
       tasks = List<CourseTask>.from(tasks),
       exams = List<Exam>.from(exams),
       profiles = List<TimetableProfile>.from(profiles);

  @override
  List<Course> courses;

  @override
  List<CourseTask> tasks;

  @override
  List<Exam> exams;

  @override
  List<TimetableProfile> profiles;

  int initializeCalls = 0;
  int persistCalls = 0;
  int notifyCalls = 0;
  int clearLiveCalls = 0;
  int syncReminderCalls = 0;
  int updateLiveCalls = 0;
  int recordTeacherCalls = 0;
  int recordLocationCalls = 0;
  final List<String> loggedEvents = <String>[];
  final List<Map<String, Object>> loggedParameters = <Map<String, Object>>[];
  bool failPersist = false;
  String? validationMessage;

  @override
  int get semesterWeekCount => 16;

  @override
  Course? getCourseById(String id) {
    for (final course in courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  @override
  DateTime? dateForCourseOccurrence(Course course, int week) {
    if (week < 1) {
      return null;
    }
    return DateTime(
      2026,
      3,
      2,
    ).add(Duration(days: (week - 1) * 7 + course.dayOfWeek - 1));
  }

  @override
  String? validateCourseTimeSchemeOverride({
    String? timeSchemeId,
    required int startSection,
    required int endSection,
  }) => validationMessage;

  @override
  Course syncCourseWithEffectiveTimeScheme(Course course) => course;

  @override
  bool isLiveTestingFixture(Course course) =>
      course.id.startsWith('live_test_');

  @override
  Future<void> recordTeacher(String teacher) async => recordTeacherCalls++;

  @override
  Future<void> recordLocation(String location) async => recordLocationCalls++;

  @override
  Future<void> persistActiveProfileState() async {
    persistCalls++;
    if (failPersist) {
      throw StateError('disk down');
    }
  }

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  void clearCurrentLiveCourseId() => clearLiveCalls++;

  @override
  void notifyStateChanged() => notifyCalls++;

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    loggedEvents.add(name);
    loggedParameters.add(parameters);
  }

  @override
  Future<void> syncExamReminders() async => syncReminderCalls++;

  @override
  Future<void> updateLiveActivity() async => updateLiveCalls++;
}

Course _course(
  String id, {
  String name = '数学',
  String teacher = '',
  String location = '',
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  int startWeek = 1,
  int endWeek = 16,
  String? shortName,
  String? description,
  String? note,
  String? timeSchemeIdOverride,
  Map<int, CourseSessionNote>? sessionNotes,
}) => Course(
  id: id,
  name: name,
  teacher: teacher,
  location: location,
  dayOfWeek: dayOfWeek,
  startSection: startSection,
  endSection: endSection,
  startTime: '08:00',
  endTime: '09:45',
  startWeek: startWeek,
  endWeek: endWeek,
  shortName: shortName,
  description: description,
  note: note,
  timeSchemeIdOverride: timeSchemeIdOverride,
  sessionNotes: sessionNotes,
);

CourseTask _task(
  String id, {
  String title = '作业',
  String? courseId,
  int? sourceWeek,
  bool completed = false,
  CourseTaskSource source = CourseTaskSource.manual,
  DateTime? dueDate,
}) => CourseTask(
  id: id,
  title: title,
  courseId: courseId,
  sourceWeek: sourceWeek,
  source: source,
  isCompleted: completed,
  dueDate: dueDate,
  createdAt: DateTime(2026, 3),
  updatedAt: DateTime(2026, 3),
);

Exam _exam(String id, String courseId) => Exam(
  id: id,
  courseId: courseId,
  name: '期末考试',
  dateTime: DateTime(2026, 6),
  startTime: '09:00',
  endTime: '11:00',
  createdAt: DateTime(2026, 3),
  updatedAt: DateTime(2026, 3),
);

TimetableProfile _profile(String id) => TimetableProfile(
  id: id,
  name: '课表$id',
  courses: const <Course>[],
  settings: TimetableSettings.defaults(),
  currentWeek: 1,
  createdAt: DateTime(2026, 3),
  lastUsedAt: DateTime(2026, 3),
);

void main() {
  group('改一门课：共享字段广播与落盘失败回滚', () {
    test('同组其它课次继承共享字段，只落盘一次、只通知一次', () async {
      final port = _FakePort(
        courses: <Course>[
          _course('c1', teacher: '张老师'),
          _course('c2', dayOfWeek: 3),
          _course('c3', name: '英语'),
        ],
      );

      await TimetableCourseService.update(
        port,
        _course('c1', teacher: '张老师', shortName: '数'),
        previousSharedName: '数学',
      );

      final c1 = port.getCourseById('c1')!;
      final c2 = port.getCourseById('c2')!;
      final c3 = port.getCourseById('c3')!;
      expect(c1.shortName, '数');
      expect(c2.shortName, '数', reason: '同组课次要一起继承共享字段');
      expect(c3.shortName, isNull, reason: '别的科目不该被改');
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.clearLiveCalls, 1);
      expect(port.loggedEvents, contains('course_updated'));
    });

    test('落盘失败：课程/作业/档案三份整体退回，并上抛原错', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1'), _course('c2')],
        tasks: <CourseTask>[_task('t1', courseId: 'c1')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.update(
          port,
          _course('c1', shortName: '数'),
          previousSharedName: '数学',
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.getCourseById('c1')!.shortName, isNull);
      expect(port.getCourseById('c2')!.shortName, isNull);
      expect(port.tasks, hasLength(1));
      expect(port.profiles, hasLength(1));
      expect(port.notifyCalls, 0, reason: '失败的写入不该通知界面');
      expect(port.clearLiveCalls, 0);
    });

    test('课程不存在：什么都不改，也不落盘', () async {
      final port = _FakePort(courses: <Course>[_course('c1')]);

      await TimetableCourseService.update(port, _course('missing'));

      expect(port.persistCalls, 0);
      expect(port.notifyCalls, 0);
    });

    test('绑定方案的课节次不合法：抛参数错误且不落盘', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1', timeSchemeIdOverride: 's1')],
      );
      port.validationMessage = 'course_sections_invalid';

      await expectLater(
        TimetableCourseService.update(
          port,
          _course('c1', timeSchemeIdOverride: 's1'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'course_sections_invalid',
          ),
        ),
      );
      expect(port.persistCalls, 0);
    });

    test('未绑方案的课越界：仍走最小健全性校验', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
      );

      await expectLater(
        TimetableCourseService.update(
          port,
          _course('c1', endSection: 40),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'course_sections_invalid',
          ),
        ),
      );
    });
  });

  group('删课程', () {
    test('课程连同名下考试与作业一起摘掉，别的记录不动', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1'), _course('c2')],
        exams: <Exam>[_exam('e1', 'c1'), _exam('e2', 'c2')],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1'),
          _task('t2', courseId: 'c2'),
          _task('t3'),
        ],
      );

      await TimetableCourseService.delete(port, 'c1');

      expect(port.courses.map((course) => course.id), <String>['c2']);
      expect(port.exams.map((exam) => exam.id), <String>['e2']);
      expect(port.tasks.map((task) => task.id), <String>['t2', 't3']);
      expect(port.persistCalls, 1);
      expect(port.loggedEvents, contains('course_deleted'));
    });

    test('落盘失败：课程/考试/作业/档案全部退回', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        exams: <Exam>[_exam('e1', 'c1')],
        tasks: <CourseTask>[_task('t1', courseId: 'c1')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.delete(port, 'c1'),
        throwsA(isA<StateError>()),
      );

      expect(port.courses, hasLength(1));
      expect(port.exams, hasLength(1));
      expect(port.tasks, hasLength(1));
      expect(port.profiles, hasLength(1));
      expect(port.notifyCalls, 0);
    });
  });

  group('清空当前课表', () {
    test('课表本来就空：先初始化，再返回 false、不落盘', () async {
      final port = _FakePort();

      expect(
        await TimetableCourseService.clearActiveProfileCourses(port),
        isFalse,
      );
      expect(port.initializeCalls, 1);
      expect(port.persistCalls, 0);
    });

    test('清课程与挂课作业，考试刻意留着', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1'),
          _task('t2'),
        ],
        exams: <Exam>[_exam('e1', 'c1')],
      );

      expect(
        await TimetableCourseService.clearActiveProfileCourses(port),
        isTrue,
      );
      expect(port.courses, isEmpty);
      expect(port.tasks.map((task) => task.id), <String>['t2']);
      expect(port.exams, hasLength(1), reason: '清空后还要重新导入，考试留着才接得上');
      expect(port.persistCalls, 1);
      expect(port.loggedEvents, contains('courses_cleared'));
    });

    test('落盘失败：课程/作业/档案退回，痕迹不改', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        tasks: <CourseTask>[_task('t1', courseId: 'c1')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.clearActiveProfileCourses(port),
        throwsA(isA<StateError>()),
      );
      expect(port.courses, hasLength(1));
      expect(port.tasks, hasLength(1));
      expect(port.profiles, hasLength(1));
    });
  });

  group('作业写入口', () {
    test('新增作业：标题 trim、按到期日排序、落盘并通知', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        tasks: <CourseTask>[
          _task('t1', dueDate: DateTime(2026, 4)),
        ],
      );

      await TimetableCourseService.addTask(
        port,
        _task('t2', title: '  写实验报告  ', courseId: 'c1', dueDate: DateTime(2026, 3, 20)),
      );

      expect(port.tasks.map((task) => task.id), <String>['t2', 't1']);
      expect(port.tasks.first.title, '写实验报告');
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.loggedEvents, contains('task_created'));
    });

    test('标题为空 → task_title_required，不落盘', () async {
      final port = _FakePort();

      await expectLater(
        TimetableCourseService.addTask(port, _task('t1', title: '   ')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'task_title_required',
          ),
        ),
      );
      expect(port.persistCalls, 0);
    });

    test('挂的课程不存在 → task_course_not_found', () async {
      final port = _FakePort();

      await expectLater(
        TimetableCourseService.addTask(port, _task('t1', courseId: 'missing')),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'task_course_not_found',
          ),
        ),
      );
    });

    test('改作业：保留 createdAt、未知 id 不动也不落盘', () async {
      final port = _FakePort(tasks: <CourseTask>[_task('t1', title: '旧标题')]);
      final createdAt = port.tasks.single.createdAt;

      await TimetableCourseService.updateTask(
        port,
        _task('t1', title: '新标题', dueDate: DateTime(2026, 5)),
      );

      final updated = port.tasks.single;
      expect(updated.title, '新标题');
      expect(updated.createdAt, createdAt, reason: '创建时间是身份，不该被编辑覆盖');
      expect(port.persistCalls, 1);

      await TimetableCourseService.updateTask(port, _task('missing'));
      expect(port.persistCalls, 1, reason: '未知 id 是 no-op');
    });

    test('勾选作业：完成态翻转并落盘', () async {
      final port = _FakePort(tasks: <CourseTask>[_task('t1')]);

      await TimetableCourseService.toggleTaskCompleted(port, 't1');

      expect(port.tasks.single.isCompleted, isTrue);
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
    });

    test('删作业：顺手清掉那门课对应周的作业标记', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            'c1',
            sessionNotes: <int, CourseSessionNote>{
              3: const CourseSessionNote(text: '第三章', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1', sourceWeek: 3, source: CourseTaskSource.homeworkMark),
        ],
      );

      await TimetableCourseService.deleteTask(port, 't1');

      expect(port.tasks, isEmpty);
      expect(port.getCourseById('c1')!.sessionNoteForWeek(3)!.hasHomework, isFalse);
      expect(port.loggedEvents, contains('task_deleted'));
    });

    test('删作业落盘失败：作业与课程标记一起退回', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            'c1',
            sessionNotes: <int, CourseSessionNote>{
              3: const CourseSessionNote(hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1', sourceWeek: 3, source: CourseTaskSource.homeworkMark),
        ],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.deleteTask(port, 't1'),
        throwsA(isA<StateError>()),
      );
      expect(port.tasks, hasLength(1));
      expect(port.getCourseById('c1')!.sessionNoteForWeek(3)!.hasHomework, isTrue);
      expect(port.profiles, hasLength(1));
    });
  });

  group('作业重算与课程归一', () {
    test('周备注勾了作业 → 长出作业，到期日取该周那次课', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            'c1',
            dayOfWeek: 2,
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题 1', hasHomework: true),
            },
          ),
        ],
      );

      final changed = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
      );

      expect(changed, isTrue);
      final generated = port.tasks.single;
      expect(generated.title, '习题 1');
      expect(generated.courseId, 'c1');
      expect(generated.sourceWeek, 2);
      expect(generated.source, CourseTaskSource.homeworkMark);
      // 学期首周周一 = 2026-03-02，第 2 周周二 = 03-02 + 7 + 1 = 03-10。
      expect(generated.dueDate, DateTime(2026, 3, 10));
      expect(port.persistCalls, 0, reason: 'persist 默认关闭');
    });

    test('勾掉标记 → 对应作业被摘掉，别人的作业不动', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1', sourceWeek: 2, source: CourseTaskSource.homeworkMark),
          _task('t2', title: '手写作业'),
        ],
      );

      final changed = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
      );

      expect(changed, isTrue);
      expect(port.tasks.map((task) => task.id), <String>['t2']);
    });

    test('归一：trim、单条备注提升为描述、周次夹到学期内', () async {
      final normalized = TimetableCourseService.normalize(
        _course(
          'c1',
          name: '  数学  ',
          teacher: ' 张老师 ',
          startWeek: 0,
          endWeek: 99,
          note: '  旧备注  ',
        ),
        semesterWeekCount: 16,
      );

      expect(normalized.name, '数学');
      expect(normalized.teacher, '张老师');
      expect(normalized.description, '旧备注');
      expect(normalized.startWeek, 1);
      expect(normalized.endWeek, 16);
    });

    test('未绑方案的节次校验：越界一律 course_sections_invalid', () {
      expect(
        TimetableCourseService.validateUnboundSections(
          startSection: 0,
          endSection: 2,
        ),
        'course_sections_invalid',
      );
      expect(
        TimetableCourseService.validateUnboundSections(
          startSection: 3,
          endSection: 2,
        ),
        'course_sections_invalid',
      );
      expect(
        TimetableCourseService.validateUnboundSections(
          startSection: 1,
          endSection: 31,
        ),
        'course_sections_invalid',
      );
      expect(
        TimetableCourseService.validateUnboundSections(
          startSection: 1,
          endSection: 30,
        ),
        isNull,
      );
    });
  });

  group('新增课程', () {
    test('追加课程、重算作业、记录教师与地点，并落盘通知', () async {
      final port = _FakePort();

      await TimetableCourseService.add(
        port,
        _course('c1', name: ' 物理 ', teacher: '李老师', location: 'A101'),
      );

      final added = port.courses.single;
      expect(added.name, '物理');
      expect(port.recordTeacherCalls, 1);
      expect(port.recordLocationCalls, 1);
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.loggedEvents, contains('course_created'));
    });

    test('同组已存在的课：新条目继承共享字段', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1', shortName: '数')],
      );

      await TimetableCourseService.add(port, _course('c2'));

      expect(port.getCourseById('c2')!.shortName, '数');
    });

    test('实时活动测试夹具不走方案补齐', () async {
      final port = _FakePort();

      await TimetableCourseService.add(port, _course('live_test_1'));

      expect(port.courses.single.id, 'live_test_1');
    });
  });

  group('课程组：整组替换与整组删除', () {
    test('删整组：本组课程与名下考试/作业一起摘掉，别的组不动', () async {
      final port = _FakePort(
        courses: <Course>[
          _course('c1'),
          _course('c2', dayOfWeek: 3),
          _course('c3', name: '英语'),
        ],
        exams: <Exam>[_exam('e1', 'c1'), _exam('e2', 'c3')],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c2'),
          _task('t2', courseId: 'c3'),
        ],
      );

      await TimetableCourseService.deleteGroup(port, ' 数学 ');

      expect(port.courses.map((course) => course.id), <String>['c3']);
      expect(port.exams.map((exam) => exam.id), <String>['e2']);
      expect(port.tasks.map((task) => task.id), <String>['t2']);
      expect(port.persistCalls, 1);
      expect(port.loggedEvents, contains('course_group_deleted'));
    });

    test('删整组落盘失败：课程/考试/作业/档案全部退回', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        exams: <Exam>[_exam('e1', 'c1')],
        tasks: <CourseTask>[_task('t1', courseId: 'c1')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.deleteGroup(port, '数学'),
        throwsA(isA<StateError>()),
      );
      expect(port.courses, hasLength(1));
      expect(port.exams, hasLength(1));
      expect(port.tasks, hasLength(1));
      expect(port.profiles, hasLength(1));
      expect(port.notifyCalls, 0);
    });

    test('整组替换：旧课次换成新集合，孤儿作业被剪掉，共享字段生效', () async {
      final port = _FakePort(
        courses: <Course>[
          _course('c1'),
          _course('c2', dayOfWeek: 3),
        ],
        tasks: <CourseTask>[
          _task('t1', courseId: 'c1'),
          _task('t2', courseId: 'c2'),
          _task('t3', title: '手写作业'),
        ],
      );

      await TimetableCourseService.updateGroup(port, '数学', <Course>[
        _course('c1', shortName: '数'),
        _course('c3', dayOfWeek: 5),
      ]);

      expect(port.courses.map((course) => course.id), <String>['c1', 'c3']);
      expect(port.getCourseById('c3')!.shortName, '数');
      expect(
        port.tasks.map((task) => task.id),
        <String>['t1', 't3'],
        reason: '挂在已删课次 c2 上的作业是孤儿，要剪掉',
      );
      expect(port.persistCalls, 1);
      expect(port.loggedEvents, contains('course_group_updated'));
    });

    test('整组替换传空列表：no-op，不落盘也不动内存', () async {
      final port = _FakePort(courses: <Course>[_course('c1')]);

      await TimetableCourseService.updateGroup(port, '数学', const <Course>[]);

      expect(port.courses, hasLength(1));
      expect(port.persistCalls, 0);
    });

    test('整组替换落盘失败：课程/作业/档案退回', () async {
      final port = _FakePort(
        courses: <Course>[_course('c1')],
        profiles: <TimetableProfile>[_profile('p1')],
      );
      port.failPersist = true;

      await expectLater(
        TimetableCourseService.updateGroup(port, '数学', <Course>[
          _course('c9'),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(port.courses.map((course) => course.id), <String>['c1']);
      expect(port.profiles, hasLength(1));
    });

    test('加整组：一次追加多条课次，教师与地点去重后各记一次', () async {
      final port = _FakePort();

      await TimetableCourseService.addGroup(port, <Course>[
        _course('c1', name: '物理', teacher: '李老师', location: 'A101'),
        _course('c2', name: '物理', teacher: '李老师', dayOfWeek: 4),
      ]);

      expect(port.courses, hasLength(2));
      expect(port.recordTeacherCalls, 1);
      expect(port.recordLocationCalls, 1);
      expect(port.persistCalls, 1);
      expect(port.loggedEvents, contains('course_group_created'));
    });

    test('加整组：有一条课次不合法就一条都不加', () async {
      final port = _FakePort();

      await expectLater(
        TimetableCourseService.addGroup(port, <Course>[
          _course('c1', name: '物理'),
          _course('c2', name: '物理', endSection: 40),
        ]),
        throwsA(isA<ArgumentError>()),
      );
      expect(port.courses, isEmpty);
      expect(port.persistCalls, 0);
    });
  });
}
