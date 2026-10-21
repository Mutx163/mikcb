import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/services/timetable_course_service.dart';

/// 作业与课程备注「双向同步」的契约（2026-10-21 立）。
///
/// 这一族钉的是**用户改过的东西不会被单方面改回去**。原先的实现把课程备注
/// 当成唯一真源：`homeworkMark` 作业的标题、截止日每次重算都无条件按备注
/// 与课程日期重写，而重算的触发点包括冷启动与任意一次课程编辑——用户在
/// 编辑页写的东西会在一次普通操作后静默消失（见 2026-10-21 笔记）。
///
/// 期望值全部人手推出来，不从实现里抄。
class _FakePort implements TimetableCoursePort {
  _FakePort({
    List<Course> courses = const <Course>[],
    List<CourseTask> tasks = const <CourseTask>[],
  }) : courses = List<Course>.from(courses),
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

  /// 与生产实现同口径：学期首周周一 = 2026-03-02，第 N 周星期 D 顺推。
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
  }) => null;

  @override
  Course syncCourseWithEffectiveTimeScheme(Course course) => course;

  @override
  Future<void> persistActiveProfileState() async {
    persistCalls += 1;
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

Course _course({
  String id = 'c1',
  String name = '高等数学',
  int dayOfWeek = 2,
  Map<int, CourseSessionNote>? sessionNotes,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    sessionNotes: sessionNotes,
  );
}

CourseTask _homeworkTask({
  String id = 't1',
  String title = '习题',
  String courseId = 'c1',
  int? sourceWeek = 2,
  DateTime? dueDate,
  bool isUserEdited = false,
  bool isCompleted = false,
}) {
  return CourseTask(
    id: id,
    title: title,
    courseId: courseId,
    sourceWeek: sourceWeek,
    source: CourseTaskSource.homeworkMark,
    dueDate: dueDate,
    isCompleted: isCompleted,
    isUserEdited: isUserEdited,
    createdAt: DateTime(2026, 3),
    updatedAt: DateTime(2026, 3, 5),
  );
}

void main() {
  group('重算不得覆盖用户改过的作业', () {
    test('用户改过的标题在重算后原样保留（不被备注原文打回）', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          _homeworkTask(title: '第三章习题 1-10', isUserEdited: true),
        ],
      );

      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      expect(port.tasks.single.title, '第三章习题 1-10');
    });

    test('用户改过的截止日在重算后原样保留（不被课程日期打回）', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          _homeworkTask(
            dueDate: DateTime(2026, 3, 20), // 用户往后推了 10 天
            isUserEdited: true,
          ),
        ],
      );

      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      // 第 2 周周二应是 03-10；用户写的是 03-20，重算必须让路。
      expect(port.tasks.single.dueDate, DateTime(2026, 3, 20));
    });

    test('用户把作业改挂到另一门课：courseId 保留、id 不变，且原课程不再生成一条重复的', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            id: 'c-math',
            name: '数学',
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
          _course(id: 'c-phy', name: '物理'),
        ],
        tasks: <CourseTask>[_homeworkTask(courseId: 'c-math')],
      );

      // 走真实写路径：用户在编辑页把「来源课程」从数学改成物理。
      await TimetableCourseService.updateTask(
        port,
        port.tasks.single.copyWith(courseId: 'c-phy'),
      );
      // 之后任意一次课程编辑 / 冷启动都会触发重算。
      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      expect(port.tasks, hasLength(1), reason: '不该多出一条同标题的重复作业');
      expect(port.tasks.single.courseId, 'c-phy');
      expect(
        port.tasks.single.id,
        't1',
        reason: 'id 换新会让多端按 id 对齐时变成两条或整条丢失',
      );
    });

    test('用户接管过的作业：即使课程备注取消勾选也不被静默删除', () async {
      final port = _FakePort(
        // 备注里已没有作业标记
        courses: <Course>[_course()],
        tasks: <CourseTask>[
          _homeworkTask(title: '我写过的作业', isUserEdited: true),
        ],
      );

      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      expect(port.tasks, hasLength(1));
      expect(port.tasks.single.title, '我写过的作业');
    });

    test('没被用户改过的作业仍然跟着备注走（回归：原行为不变）', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '新的作业要求', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[_homeworkTask(title: '旧标题')],
      );

      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      expect(port.tasks.single.title, '新的作业要求');
      expect(port.tasks.single.id, 't1', reason: '同一条记录就地更新，不新建');
    });

    test('没被改过的作业在备注取消勾选时被摘掉（回归：原行为不变）', () async {
      final port = _FakePort(
        courses: <Course>[_course()],
        tasks: <CourseTask>[_homeworkTask()],
      );

      await TimetableCourseService.syncHomeworkTasksWithCourses(port);

      expect(port.tasks, isEmpty);
    });
  });

  group('重算在没有任何改动时不得谎报「有变化」', () {
    test('连跑两次：第二次返回 false，且 updatedAt 不被刷新', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[
          _homeworkTask(dueDate: DateTime(2026, 3, 10)),
        ],
      );

      final first = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
      );
      final updatedAtAfterFirst = port.tasks.single.updatedAt;
      final second = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
      );

      expect(first, isFalse, reason: '输入本来就与备注一致，不该算变化');
      expect(second, isFalse);
      expect(
        port.tasks.single.updatedAt,
        updatedAtAfterFirst,
        reason: '无改动却刷新时间戳，会让冷启动每次都判「变了」并全量写盘',
      );
    });

    test('无改动时即使 persist=true 也不写盘', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '习题', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[_homeworkTask(dueDate: DateTime(2026, 3, 10))],
      );

      final changed = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
        persist: true,
      );

      expect(changed, isFalse);
      expect(port.persistCalls, 0);
    });

    test('备注真的改了：返回 true，且 refresh updatedAt', () async {
      final port = _FakePort(
        courses: <Course>[
          _course(
            sessionNotes: <int, CourseSessionNote>{
              2: const CourseSessionNote(text: '改过的要求', hasHomework: true),
            },
          ),
        ],
        tasks: <CourseTask>[_homeworkTask(dueDate: DateTime(2026, 3, 10))],
      );

      final changed = await TimetableCourseService.syncHomeworkTasksWithCourses(
        port,
      );

      expect(changed, isTrue);
      expect(port.tasks.single.title, '改过的要求');
    });
  });

  group('写入口自动给「用户改动」盖标记', () {
    test('改标题 → isUserEdited 置位', () async {
      final port = _FakePort(
        courses: <Course>[_course()],
        tasks: <CourseTask>[_homeworkTask()],
      );

      await TimetableCourseService.updateTask(
        port,
        port.tasks.single.copyWith(title: '我自己写的标题'),
      );

      expect(port.tasks.single.isUserEdited, isTrue);
    });

    test('改截止日 → isUserEdited 置位', () async {
      final port = _FakePort(
        courses: <Course>[_course()],
        tasks: <CourseTask>[_homeworkTask()],
      );

      await TimetableCourseService.updateTask(
        port,
        port.tasks.single.copyWith(dueDate: DateTime(2026, 4)),
      );

      expect(port.tasks.single.isUserEdited, isTrue);
    });

    test('只改备注 / 完成态 → 不置位（这些字段本来就不参与重算）', () async {
      final port = _FakePort(
        courses: <Course>[_course()],
        tasks: <CourseTask>[_homeworkTask()],
      );

      await TimetableCourseService.updateTask(
        port,
        port.tasks.single.copyWith(note: '上传到教学平台', isCompleted: true),
      );

      expect(port.tasks.single.isUserEdited, isFalse);
    });

    test('只改标题里的首尾空格（归一后不变）→ 不置位', () async {
      final port = _FakePort(
        courses: <Course>[_course()],
        tasks: <CourseTask>[_homeworkTask()],
      );

      await TimetableCourseService.updateTask(
        port,
        port.tasks.single.copyWith(title: '  习题  '),
      );

      expect(port.tasks.single.title, '习题');
      expect(port.tasks.single.isUserEdited, isFalse);
    });
  });

  group('模型：isUserEdited 的序列化口径', () {
    test('true 时写出，读回仍为 true', () {
      final task = _homeworkTask(isUserEdited: true);
      final json = task.toJson();

      expect(json['isUserEdited'], isTrue);
      expect(CourseTask.fromJson(json).isUserEdited, isTrue);
    });

    test('false 时不写这个键（旧档案与导出文件的字节保持不变）', () {
      final task = _homeworkTask();
      final json = task.toJson();

      expect(json.containsKey('isUserEdited'), isFalse);
      expect(CourseTask.fromJson(json).isUserEdited, isFalse);
    });

    test('键缺失的旧档案读得回来（默认 false，不丢整条）', () {
      final json = _homeworkTask().toJson()..remove('isUserEdited');

      final restored = CourseTask.fromJson(json);

      expect(restored.isUserEdited, isFalse);
      expect(restored.title, '习题');
    });

    test('类型不对（字符串 "true"）按缺省 false 收下，不让整条任务消失', () {
      final json = _homeworkTask().toJson()..['isUserEdited'] = 'true';

      final restored = CourseTask.fromJson(json);

      expect(restored.isUserEdited, isFalse);
      expect(restored.id, 't1');
    });

    test('copyWith 能把标记置位，也能原样带过去', () {
      final task = _homeworkTask();

      expect(task.copyWith(isUserEdited: true).isUserEdited, isTrue);
      expect(task.copyWith(title: '新标题').isUserEdited, isFalse);
      expect(
        task.copyWith(isUserEdited: true).copyWith(note: 'x').isUserEdited,
        isTrue,
        reason: '不显式传参时必须保留原值',
      );
    });
  });
}
