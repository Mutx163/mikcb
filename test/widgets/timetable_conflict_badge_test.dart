import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel =
      MethodChannel('com.example.university_timetable/home_widget');
  const analyticsChannel =
      MethodChannel('com.example.university_timetable/umeng_analytics');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
  });

  testWidgets('home timetable shows conflict badge when enabled',
      (tester) async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.addCourse(
      Course(
        id: 'course-a',
        name: '软件工程',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    await provider.addCourse(
      Course(
        id: 'course-b',
        name: '计算机网络',
        teacher: '李老师',
        location: 'B202',
        dayOfWeek: 1,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:35',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: TimetableScreen(enableUpdateCheck: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('冲突'), findsWidgets);

    await provider.updateTimetableSettings(
      provider.settings.copyWith(showConflictBadgeOnTimetable: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('冲突'), findsNothing);
  });
}
