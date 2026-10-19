import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_exam_service.dart';

Course _course() => Course(
  id: 'c1',
  name: '高等数学',
  teacher: '老师',
  location: 'A101',
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  startTime: '08:00',
  endTime: '09:35',
);

TimetableProfile _profile() => TimetableProfile(
  id: 'p1',
  name: '默认',
  courses: const [],
  settings: TimetableSettings.defaults(),
  currentWeek: 1,
  createdAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
);

Exam _exam({
  String id = 'e1',
  String courseId = 'c1',
  DateTime? dateTime,
}) => Exam(
  id: id,
  courseId: courseId,
  name: '期末考试',
  dateTime: dateTime ?? DateTime(2099, 1, 10),
  startTime: '09:00',
  endTime: '11:00',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeExamPort implements TimetableExamPort {
  @override
  List<Exam> exams = [];
  @override
  List<TimetableProfile> profiles = [];

  bool hasCourse = true;
  bool failPersist = false;
  int persistCount = 0;
  int notifyCount = 0;
  int reminderCount = 0;
  int invalidateCount = 0;
  int widgetSyncCount = 0;
  final List<String> events = [];

  @override
  Course? courseForExam(Exam exam) => hasCourse ? _course() : null;

  @override
  Future<void> initialize() async {}

  @override
  Future<T> runMutation<T>(Future<T> Function() operation) => operation();

  @override
  Future<void> persistActiveProfileState() async {
    persistCount += 1;
    if (failPersist) {
      // 模拟 provider 的第一步 merge：内存档案已带上未落盘的新状态。
      profiles = [...profiles, _profile()];
      throw StateError('disk full');
    }
  }

  @override
  void notifyStateChanged() => notifyCount += 1;

  @override
  void syncExamReminders() => reminderCount += 1;

  @override
  void invalidateHomeWidgetSnapshot() => invalidateCount += 1;

  @override
  void syncHomeWidgetSnapshot() => widgetSyncCount += 1;

  @override
  void logExamEvent(String name, Map<String, Object> parameters) =>
      events.add(name);
}

void main() {
  test('查询：按课程过滤、按开始时间排序、只留未过期', () {
    final port = _FakeExamPort()
      ..exams = [
        _exam(id: 'later', dateTime: DateTime(2099, 1, 20)),
        _exam(id: 'earlier', dateTime: DateTime(2099, 1, 10)),
        _exam(id: 'old', dateTime: DateTime(2000)),
        _exam(id: 'other', courseId: 'c2', dateTime: DateTime(2099, 1, 15)),
      ];
    final service = TimetableExamService(port);

    expect(
      service.getExamsForCourse('c1').map((e) => e.id),
      ['old', 'earlier', 'later'],
    );
    expect(
      service.getUpcomingExams().map((e) => e.id),
      ['earlier', 'other', 'later'],
    );
    expect(service.getUpcomingExams(limit: 1).single.id, 'earlier');
    expect(service.getNextExam()?.id, 'earlier');
    expect(service.hasExamOnDate(DateTime(2099, 1, 20)), isTrue);
    expect(service.hasExamOnDate(DateTime(2099, 1, 21)), isFalse);
  });

  test('addExam 找不到关联课程时拒绝写入', () async {
    final port = _FakeExamPort()..hasCourse = false;
    final service = TimetableExamService(port);

    await expectLater(
      service.addExam(_exam()),
      throwsA(isA<ArgumentError>()),
    );
    expect(port.exams, isEmpty);
    expect(port.persistCount, 0);
  });

  test('addExam 成功后追加、落盘并重推提醒/小组件', () async {
    final port = _FakeExamPort();
    final service = TimetableExamService(port);

    await service.addExam(_exam());

    expect(port.exams.single.id, 'e1');
    expect(port.persistCount, 1);
    expect(port.notifyCount, 1);
    expect(port.reminderCount, 1);
    expect(port.invalidateCount, 1);
    expect(port.widgetSyncCount, 1);
    expect(port.events, ['exam_created']);
  });

  test('updateExam 落盘失败时考试与档案一起回滚', () async {
    final port = _FakeExamPort()
      ..exams = [_exam()]
      ..profiles = [_profile()]
      ..failPersist = true;
    final service = TimetableExamService(port);

    await expectLater(
      service.updateExam(_exam(dateTime: DateTime(2099, 2))),
      throwsA(isA<StateError>()),
    );

    expect(port.exams.single.dateTime, DateTime(2099, 1, 10));
    expect(port.profiles, hasLength(1));
    expect(port.notifyCount, 0);
    expect(port.reminderCount, 0);
    expect(port.events, isEmpty);
  });

  test('deleteExam 落盘失败时考试与档案一起回滚', () async {
    final port = _FakeExamPort()
      ..exams = [_exam()]
      ..profiles = [_profile()]
      ..failPersist = true;
    final service = TimetableExamService(port);

    await expectLater(
      service.deleteExam('e1'),
      throwsA(isA<StateError>()),
    );

    expect(port.exams.single.id, 'e1');
    expect(port.profiles, hasLength(1));
    expect(port.notifyCount, 0);
    expect(port.events, isEmpty);
  });

  test('deleteExam 成功时移除并触发副作用', () async {
    final port = _FakeExamPort()..exams = [_exam()];
    final service = TimetableExamService(port);

    await service.deleteExam('e1');

    expect(port.exams, isEmpty);
    expect(port.persistCount, 1);
    expect(port.notifyCount, 1);
    expect(port.reminderCount, 1);
    expect(port.events, ['exam_deleted']);
  });
}
