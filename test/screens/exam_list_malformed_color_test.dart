import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/screens/exam_list_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

/// 回归：考试列表页曾用私有 `_parseColor` 手写 `int.parse(hex, radix: 16)`
/// 解析**课程**颜色（exam_list_screen.dart）。课程颜色来自导入数据或用户数据，
/// 一旦是畸形值就会抛 FormatException，导致整页渲染失败。
///
/// 现已改用 `lib/utils/hex_color.dart` 的 `parseHexColorOrFallback`，
/// 畸形颜色一律回退到兜底色。本测试直接渲染考试列表页证明不再崩。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  /// 建一门颜色畸形的课程，并挂一门指向它的考试。
  Future<void> pumpExamListWithCourseColor(
    WidgetTester tester,
    String courseColor,
  ) async {
    final provider = await createInitializedTestProvider(tester);
    final now = DateTime.now();

    await runRealAsync(tester, () async {
      await provider.addCourse(
        Course(
          id: 'c-malformed',
          name: '畸形颜色课程',
          teacher: '张老师',
          location: '第一教学楼 101',
          dayOfWeek: DateTime.now().weekday,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
          color: courseColor,
        ),
      );
      await provider.addExam(
        Exam(
          id: 'e-malformed',
          courseId: 'c-malformed',
          name: '畸形颜色考试',
          dateTime: DateTime(now.year, now.month, now.day).add(
            const Duration(days: 1),
          ),
          startTime: '08:00',
          endTime: '09:40',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: ExamListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 这些值都曾让 `int.parse(cleaned, radix: 16)` 抛异常。
  for (final badColor in <String>['', '#', '#FFF', '#GGGGGG', 'rgb(1,2,3)']) {
    testWidgets('考试列表页遇到畸形课程颜色 "$badColor" 不崩溃', (tester) async {
      await pumpExamListWithCourseColor(tester, badColor);
      expect(tester.takeException(), isNull);
      // 兜底色生效，考试条目仍应渲染出来。
      expect(find.text('畸形颜色考试'), findsWidgets);
    });
  }

  testWidgets('合法课程颜色照常解析，不影响原有渲染', (tester) async {
    await pumpExamListWithCourseColor(tester, '#2196F3');
    expect(tester.takeException(), isNull);
    expect(find.text('畸形颜色考试'), findsWidgets);
  });
}
