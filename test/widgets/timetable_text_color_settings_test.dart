import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/timetable_text_color_settings.dart';

Future<void> _pump(WidgetTester tester, {required TextColorScope scope}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TimetableTextColorSettings(
          settings: TimetableSettings.defaults(),
          scope: scope,
          onChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

AppLocalizations _l10nOf(WidgetTester tester) {
  return AppLocalizations.of(
    tester.element(find.byType(TimetableTextColorSettings)),
  )!;
}

void main() {
  // 浅色/深色两张模式卡各渲染一份行，所以可见行都是 2 处。
  testWidgets('课程卡片页只渲染课卡标题/详情颜色与独立详情开关', (tester) async {
    await _pump(tester, scope: TextColorScope.courseCard);
    final l10n = _l10nOf(tester);
    expect(find.text(l10n.textColorCourseCardTitle), findsNWidgets(2));
    expect(find.text(l10n.textColorCourseCardDetail), findsNWidgets(2));
    expect(find.text(l10n.textColorIndependentDetail), findsOneWidget);
    expect(find.text(l10n.textColorWeekdayBar), findsNothing);
    expect(find.text(l10n.textColorWeekdayBarAccent), findsNothing);
    expect(find.text(l10n.textColorTimeAxis), findsNothing);
  });

  testWidgets('课表页面页只渲染星期栏/强调/时间轴颜色', (tester) async {
    await _pump(tester, scope: TextColorScope.page);
    final l10n = _l10nOf(tester);
    expect(find.text(l10n.textColorWeekdayBar), findsNWidgets(2));
    expect(find.text(l10n.textColorWeekdayBarAccent), findsNWidgets(2));
    expect(find.text(l10n.textColorTimeAxis), findsNWidgets(2));
    expect(find.text(l10n.textColorCourseCardTitle), findsNothing);
    expect(find.text(l10n.textColorCourseCardDetail), findsNothing);
    expect(find.text(l10n.textColorIndependentDetail), findsNothing);
  });
}
