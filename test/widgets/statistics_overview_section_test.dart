import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/statistics/overview_section.dart';

import '../helpers_test_app.dart';

const _testStats = SemesterStats(
  totalCourses: 8,
  totalSections: 148,
  totalWeeks: 20,
  longestStreak: 7,
  dailyAverages: [],
  natureStats: CourseNatureStats(
    requiredCount: 5,
    electiveCount: 3,
    requiredSections: 100,
    electiveSections: 48,
  ),
  courseRanking: [],
);

void main() {
  testWidgets('renders four metrics in one compact row', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        home: Scaffold(body: Center(child: OverviewSection(stats: _testStats))),
      ),
    );

    expect(find.text('8'), findsOneWidget);
    expect(find.text('148'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('门课程'), findsOneWidget);
    expect(find.text('节课'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('天连续'), findsOneWidget);

    // 紧凑回归：总览卡应保持单行高度（旧 2×2 宫格约 230px）。
    final cardHeight = tester
        .getSize(find.byType(HyperosControlCard))
        .height;
    expect(cardHeight, lessThan(120), reason: 'overview card must stay compact');
  });

  testWidgets('hides entirely when there are no courses', (tester) async {
    const emptyStats = SemesterStats(
      totalCourses: 0,
      totalSections: 0,
      totalWeeks: 20,
      longestStreak: 0,
      dailyAverages: [],
      natureStats: CourseNatureStats(
        requiredCount: 0,
        electiveCount: 0,
        requiredSections: 0,
        electiveSections: 0,
      ),
      courseRanking: [],
    );

    await tester.pumpWidget(
      const TestApp(
        home: Scaffold(body: Center(child: OverviewSection(stats: emptyStats))),
      ),
    );

    expect(find.byType(HyperosControlCard), findsNothing);
  });

  testWidgets('long english labels ellipsize without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: OverviewSection(stats: _testStats)),
        ),
      ),
    );

    expect(find.text('day streak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
