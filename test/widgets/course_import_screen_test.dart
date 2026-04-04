import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/course_import_screen.dart';

void main() {
  testWidgets('ai import screen keeps keyboard-aware resizing enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AiImageCourseImportScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
  });
}
