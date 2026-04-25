import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 4, 13),
        semesterWeekCount: 20,
      ),
    );
    return provider;
  }

  Future<Course> addTestCourse(TimetableProvider provider) async {
    final course = Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
    await provider.addCourse(course);
    return course;
  }

  Exam buildExam({
    String id = 'exam-1',
    String courseId = 'course-1',
    String name = '高等数学期末考试',
    DateTime? dateTime,
  }) {
    return Exam(
      id: id,
      courseId: courseId,
      name: name,
      dateTime: dateTime ?? DateTime.now().add(const Duration(days: 10)),
      startTime: '08:30',
      endTime: '10:30',
      location: 'A-301',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('TimetableProvider exam CRUD', () {
    test('addExam adds exam to list', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final exam = buildExam();

      await provider.addExam(exam);

      expect(provider.exams, hasLength(1));
      expect(provider.exams.first.name, '高等数学期末考试');
    });

    test('addExam throws for non-existent course', () async {
      final provider = await createProvider();
      final exam = buildExam(courseId: 'non-existent');

      expect(
        () => provider.addExam(exam),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('updateExam modifies existing exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final exam = buildExam();
      await provider.addExam(exam);

      final updated = exam.copyWith(name: '期中考试', location: 'B-201');
      await provider.updateExam(updated);

      expect(provider.exams.first.name, '期中考试');
      expect(provider.exams.first.location, 'B-201');
    });

    test('deleteExam removes exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam());

      await provider.deleteExam('exam-1');

      expect(provider.exams, isEmpty);
    });

    test('getExamById returns correct exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam(id: 'e1', name: '考试A'));
      await provider.addExam(buildExam(id: 'e2', name: '考试B'));

      expect(provider.getExamById('e1')?.name, '考试A');
      expect(provider.getExamById('e2')?.name, '考试B');
      expect(provider.getExamById('e3'), isNull);
    });
  });

  group('TimetableProvider exam queries', () {
    test('getCourseForExam returns linked course', () async {
      final provider = await createProvider();
      final course = await addTestCourse(provider);
      await provider.addExam(buildExam());

      final linked = provider.getCourseForExam(provider.exams.first);
      expect(linked?.id, course.id);
      expect(linked?.name, '高等数学');
    });

    test('getExamsForCourse filters by courseId', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addCourse(Course(
        id: 'course-2',
        name: '大学英语',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 3,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      ));
      await provider.addExam(buildExam(id: 'e1', courseId: 'course-1'));
      await provider.addExam(buildExam(id: 'e2', courseId: 'course-2'));
      await provider.addExam(buildExam(id: 'e3', courseId: 'course-1'));

      expect(provider.getExamsForCourse('course-1'), hasLength(2));
      expect(provider.getExamsForCourse('course-2'), hasLength(1));
    });

    test('getUpcomingExams returns only non-expired exams sorted by date', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam(
        id: 'past',
        dateTime: DateTime.now().subtract(const Duration(days: 5)),
      ));
      await provider.addExam(buildExam(
        id: 'future1',
        dateTime: DateTime.now().add(const Duration(days: 10)),
      ));
      await provider.addExam(buildExam(
        id: 'future2',
        dateTime: DateTime.now().add(const Duration(days: 3)),
      ));

      final upcoming = provider.getUpcomingExams();
      expect(upcoming, hasLength(2));
      expect(upcoming.first.id, 'future2');
      expect(upcoming.last.id, 'future1');
    });

    test('getUpcomingExams respects limit', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam(id: 'e1', dateTime: DateTime.now().add(const Duration(days: 1))));
      await provider.addExam(buildExam(id: 'e2', dateTime: DateTime.now().add(const Duration(days: 2))));
      await provider.addExam(buildExam(id: 'e3', dateTime: DateTime.now().add(const Duration(days: 3))));

      expect(provider.getUpcomingExams(limit: 2), hasLength(2));
    });

    test('getNextExam returns nearest future exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam(
        id: 'far',
        dateTime: DateTime.now().add(const Duration(days: 20)),
      ));
      await provider.addExam(buildExam(
        id: 'near',
        dateTime: DateTime.now().add(const Duration(days: 5)),
      ));

      expect(provider.getNextExam()?.id, 'near');
    });

    test('getNextExam returns null when no exams', () async {
      final provider = await createProvider();
      expect(provider.getNextExam(), isNull);
    });

    test('hasExamOnDate returns true for matching date', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final targetDate = DateTime(2026, 6, 15);
      await provider.addExam(buildExam(dateTime: targetDate));

      expect(provider.hasExamOnDate(targetDate), isTrue);
      expect(provider.hasExamOnDate(DateTime(2026, 6, 16)), isFalse);
    });
  });
}
