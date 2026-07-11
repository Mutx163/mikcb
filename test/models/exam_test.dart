import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/exam.dart';

void main() {
  test('fromJson normalizes malformed exam times', () {
    final exam = Exam.fromJson({
      'id': 'exam-1',
      'courseId': 'course-1',
      'name': '期末',
      'dateTime': '2026-06-01T00:00:00.000',
      'startTime': 'bad',
      'endTime': '25:99',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    });

    expect(exam.startTime, '08:30');
    expect(exam.endTime, '10:30');
    // Must not throw on malformed original times.
    expect(exam.isExpired, isA<bool>());
  });

  test('isExpired tolerates empty endTime via safe parse', () {
    final exam = Exam(
      id: 'exam-2',
      courseId: 'course-1',
      name: '期中',
      dateTime: DateTime(2020, 1, 1),
      startTime: '08:00',
      endTime: '',
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

    expect(exam.isExpired, isTrue);
  });
}
