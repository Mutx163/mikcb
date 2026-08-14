import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/widgets/statistics/achievement_badge.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping an achievement badge opens its detail sheet', (
    tester,
  ) async {
    final achievements = [
      const Achievement(
        id: 'scholar',
        icon: Icons.auto_stories_rounded,
        isUnlocked: false,
        progressCurrent: 30,
        progressTarget: 100,
      ),
    ];

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(body: AchievementGrid(achievements: achievements)),
      ),
    );

    expect(find.byType(AchievementBadge), findsOneWidget);
    await tester.tap(find.byType(AchievementBadge));
    await tester.pumpAndSettle();

    // 详情弹窗内容：状态、进度、专属解锁条件、确认按钮
    expect(find.text('未达成'), findsWidgets);
    expect(find.text('30/100'), findsWidgets);
    expect(find.textContaining('解锁条件'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });

  testWidgets('unlocked badge sheet shows done state and full progress', (
    tester,
  ) async {
    final achievements = [
      const Achievement(
        id: 'early_bird',
        icon: Icons.wb_sunny_rounded,
        isUnlocked: true,
        progressCurrent: 2,
        progressTarget: 1,
      ),
    ];

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(body: AchievementGrid(achievements: achievements)),
      ),
    );

    await tester.tap(find.byType(AchievementBadge));
    await tester.pumpAndSettle();

    expect(find.text('已达成'), findsWidgets); // 徽章进度标签 + 弹窗状态
    expect(find.textContaining('08:00'), findsOneWidget);
  });
}
