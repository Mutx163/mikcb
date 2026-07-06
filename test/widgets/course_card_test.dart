import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/widgets/course_card.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invalid course color does not crash course card', (
    tester,
  ) async {
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
      color: 'broken',
    );

    await tester.pumpWidget(TestApp(home: CourseCard(course: course)));

    expect(find.text('高等数学'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
