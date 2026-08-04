import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    return provider;
  }

  CourseTask buildTask({String id = 'task-1'}) {
    return CourseTask(
      id: id,
      title: '完成作业',
      dueDate: DateTime(2026, 4, 7),
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
    );
  }

  test(
    'tasks support create, update, completion, delete, and persistence',
    () async {
      final provider = await createProvider();
      await provider.addTask(buildTask());

      await provider.updateTask(
        buildTask().copyWith(title: '完成实验报告', note: '上传到平台'),
      );
      expect(provider.tasks.single.title, '完成实验报告');
      expect(provider.tasks.single.note, '上传到平台');

      await provider.toggleTaskCompleted('task-1');
      expect(provider.tasks.single.isCompleted, isTrue);

      final reloaded = await createProvider();
      expect(reloaded.tasks.single.title, '完成实验报告');
      expect(reloaded.tasks.single.isCompleted, isTrue);

      await reloaded.deleteTask('task-1');
      expect(reloaded.tasks, isEmpty);
    },
  );

  test(
    'homework marks migrate to tasks and deleting the task clears the mark',
    () async {
      final provider = await createProvider();
      await provider.updateSettings(
        provider.settings.copyWith(semesterStartDate: DateTime(2026, 3, 2)),
      );
      final course = Course(
        id: 'course-1',
        name: '高数',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        sessionNotes: const {
          2: CourseSessionNote(text: '完成第二章', hasHomework: true),
        },
      );
      await provider.addCourse(course);

      expect(provider.tasks, hasLength(1));
      final migrated = provider.tasks.single;
      expect(migrated.source, CourseTaskSource.homeworkMark);
      expect(migrated.title, '完成第二章');
      expect(migrated.sourceWeek, 2);
      expect(migrated.dueDate, DateTime(2026, 3, 9));

      await provider.deleteTask(migrated.id);

      expect(provider.tasks, isEmpty);
      expect(
        provider.getCourseById('course-1')!.sessionNoteForWeek(2)!.hasHomework,
        isFalse,
      );
    },
  );
}
