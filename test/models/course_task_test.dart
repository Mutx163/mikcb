import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course_task.dart';

void main() {
  test('task round-trips dates, source, and completion state', () {
    final task = CourseTask(
      id: 'task-1',
      title: '完成实验报告',
      courseId: 'course-1',
      sourceWeek: 4,
      dueDate: DateTime(2026, 4, 7, 18),
      note: '上传到教学平台',
      isCompleted: true,
      source: CourseTaskSource.homeworkMark,
      createdAt: DateTime(2026, 4, 1, 9),
      updatedAt: DateTime(2026, 4, 6, 10),
    );

    final restored = CourseTask.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.courseId, task.courseId);
    expect(restored.sourceWeek, 4);
    expect(restored.dueDate, DateTime(2026, 4, 7));
    expect(restored.note, task.note);
    expect(restored.isCompleted, isTrue);
    expect(restored.source, CourseTaskSource.homeworkMark);
  });

  test('a task without a due date is never overdue', () {
    final task = CourseTask(
      id: 'task-2',
      title: '整理资料',
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );

    expect(task.isDueOn(DateTime(2026, 4)), isFalse);
    expect(
      task.isDueBetween(DateTime(2026, 4), DateTime(2026, 4, 7)),
      isFalse,
    );
    expect(task.isOverdue(now: DateTime(2026, 4, 30)), isFalse);
  });

  test('overdue status ignores time-of-day and completed tasks', () {
    final task = CourseTask(
      id: 'task-3',
      title: '复习',
      dueDate: DateTime(2026, 4, 7, 23),
      createdAt: DateTime(2026, 4),
      updatedAt: DateTime(2026, 4),
    );

    expect(task.isOverdue(now: DateTime(2026, 4, 8, 0, 1)), isTrue);
    expect(
      task.copyWith(isCompleted: true).isOverdue(now: DateTime(2026, 4, 8)),
      isFalse,
    );
  });
}
